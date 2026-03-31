//
//  EventTapManager.swift
//  OpenTypeless
//
//  Extracted from AppCoordinator — manages CGEventTap lifecycle for
//  escape-key cancellation and modifier-key forwarding.
//

import Foundation
import AppKit
import os.log

@MainActor
final class EventTapManager {

    // MARK: - Callbacks

    /// Invoked when double-escape triggers a cancel.  AppCoordinator wires
    /// this to its own `cancelCurrentOperation` implementation.
    var onCancelCurrentOperation: (() -> Void)?

    /// Invoked when the manager needs the coordinator to reset processing
    /// state.  Currently unused by event-tap paths but exposed for symmetry.
    var onResetProcessingState: (() -> Void)?

    /// Called from handleKeyEvent for non-escape key presses so the
    /// coordinator can refresh focus/window context.
    var onNonEscapeKeyDown: (() -> Void)?

    /// Called from handleModifierKeyEvent to forward modifier changes
    /// to the hotkey manager.
    var onModifierFlagsChanged: ((_ event: CGEvent) -> Void)?

    /// Read-only state providers — the coordinator supplies these closures
    /// so the manager can query recording/processing state without owning it.
    var isRecordingProvider: (() -> Bool) = { false }
    var isProcessingProvider: (() -> Bool) = { false }
    var isFloatingIndicatorEnabledProvider: (() -> Bool) = { false }

    /// Floating-indicator escape-primed helpers.
    var showEscapePrimed: (() -> Void)?
    var clearEscapePrimed: (() -> Void)?

    // MARK: - Event Tap State

    private var escapeEventTap: CFMachPort?
    private var escapeRunLoopSource: CFRunLoopSource?
    private var escapeGlobalMonitor: Any?
    private var modifierEventTap: CFMachPort?
    private var modifierRunLoopSource: CFRunLoopSource?
    private var modifierGlobalMonitor: Any?
    private let eventTapRunLoopThread = EventTapRunLoopThread(name: "com.yisu.opentypeless.event-tap-runloop")
    private var escapeEventTapDisableState = EventTapDisableState()
    private var modifierEventTapDisableState = EventTapDisableState()
    private var escapeEventTapRecoveryTask: Task<Void, Never>?
    private var modifierEventTapRecoveryTask: Task<Void, Never>?
    private var lastEscapeTime: Date?
    private var lastEscapeSignalTime: Date?

    // MARK: - Constants

    private let doubleEscapeThreshold: TimeInterval = 0.4
    private let duplicateEscapeSignalThreshold: TimeInterval = 0.08
    private let eventTapRecoveryDelay: Duration = .milliseconds(250)
    private let eventTapDisableLoopWindow: TimeInterval = 1.0
    private let maxEventTapReenableAttemptsBeforeRecreate = 3

    // MARK: - Init

    private let enableSystemHooks: Bool

    init(enableSystemHooks: Bool) {
        self.enableSystemHooks = enableSystemHooks
    }

    // MARK: - Setup / Teardown (public surface)

    func setupEscapeKeyMonitor() {
        if escapeEventTap != nil, escapeRunLoopSource != nil {
            installEscapeGlobalMonitorFallbackIfNeeded()
            return
        }

        if escapeEventTap != nil, escapeRunLoopSource == nil {
            Log.app.warning("Escape event tap missing run loop source; recreating monitor")
            teardownEscapeKeyMonitor()
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            Log.app.error("Failed to create CGEventTap - Accessibility or Input Monitoring permission may be required")
            resetEventTapRecoveryState(for: .escape)
            installEscapeGlobalMonitorFallbackIfNeeded()
            return
        }

        installEscapeGlobalMonitorFallbackIfNeeded()

        escapeEventTap = eventTap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            Log.app.error("Failed to create run loop source for escape CGEventTap")
            escapeEventTap = nil
            resetEventTapRecoveryState(for: .escape)
            return
        }

        escapeRunLoopSource = source
        eventTapRunLoopThread.performAndWait { runLoop in
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        resetEventTapRecoveryState(for: .escape)
        Log.app.info("Escape key monitor installed")
    }

    func setupModifierKeyMonitor() {
        if modifierEventTap != nil, modifierRunLoopSource != nil {
            removeModifierGlobalMonitorFallbackIfNeeded()
            return
        }

        if modifierEventTap != nil, modifierRunLoopSource == nil {
            Log.hotkey.warning("Modifier event tap missing run loop source; recreating monitor")
            teardownModifierKeyMonitor()
        }

        let eventMask = (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleModifierKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            Log.hotkey.error("Failed to create modifier CGEventTap - Accessibility or Input Monitoring permission may be required")
            resetEventTapRecoveryState(for: .modifier)
            installModifierGlobalMonitorFallbackIfNeeded()
            return
        }

        removeModifierGlobalMonitorFallbackIfNeeded()

        modifierEventTap = eventTap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            Log.hotkey.error("Failed to create run loop source for modifier CGEventTap")
            modifierEventTap = nil
            resetEventTapRecoveryState(for: .modifier)
            return
        }

        modifierRunLoopSource = source
        eventTapRunLoopThread.performAndWait { runLoop in
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        resetEventTapRecoveryState(for: .modifier)
        Log.hotkey.info("Modifier key monitor installed")
    }

    func teardownEscapeKeyMonitor() {
        escapeEventTapRecoveryTask?.cancel()
        escapeEventTapRecoveryTask = nil

        if let source = escapeRunLoopSource {
            let eventTap = escapeEventTap
            eventTapRunLoopThread.performAndWait { runLoop in
                if let eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: false)
                }
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
            }
        } else if let eventTap = escapeEventTap {
            eventTapRunLoopThread.performAndWait { _ in
                CGEvent.tapEnable(tap: eventTap, enable: false)
            }
        }

        escapeEventTap = nil
        escapeRunLoopSource = nil
        resetEventTapRecoveryState(for: .escape)
    }

    func teardownModifierKeyMonitor() {
        modifierEventTapRecoveryTask?.cancel()
        modifierEventTapRecoveryTask = nil

        if let source = modifierRunLoopSource {
            let eventTap = modifierEventTap
            eventTapRunLoopThread.performAndWait { runLoop in
                if let eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: false)
                }
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
            }
        } else if let eventTap = modifierEventTap {
            eventTapRunLoopThread.performAndWait { _ in
                CGEvent.tapEnable(tap: eventTap, enable: false)
            }
        }

        modifierEventTap = nil
        modifierRunLoopSource = nil
        resetEventTapRecoveryState(for: .modifier)
    }

    func ensureGlobalKeyMonitorsIfPossible() {
        setupEscapeKeyMonitor()
        setupModifierKeyMonitor()
    }

    func removeEscapeGlobalMonitorFallbackIfNeeded() {
        guard let monitor = escapeGlobalMonitor else { return }
        NSEvent.removeMonitor(monitor)
        escapeGlobalMonitor = nil
        Log.app.debug("Removed NSEvent global monitor fallback for escape key")
    }

    func removeModifierGlobalMonitorFallbackIfNeeded() {
        guard let monitor = modifierGlobalMonitor else { return }
        NSEvent.removeMonitor(monitor)
        modifierGlobalMonitor = nil
        Log.hotkey.debug("Removed NSEvent global monitor fallback for modifier changes")
    }

    func cleanup() {
        teardownEscapeKeyMonitor()
        teardownModifierKeyMonitor()
        removeEscapeGlobalMonitorFallbackIfNeeded()
        removeModifierGlobalMonitorFallbackIfNeeded()
        eventTapRunLoopThread.stopIfNeeded()
    }

    // MARK: - Static Helpers

    static func shouldSuppressEscapeEvent(isRecording: Bool, isProcessing: Bool) -> Bool {
        isRecording || isProcessing
    }

    static func isDoubleEscapePress(
        now: Date,
        lastEscapeTime: Date?,
        threshold: TimeInterval
    ) -> Bool {
        guard let lastEscapeTime else { return false }
        return now.timeIntervalSince(lastEscapeTime) <= threshold
    }

    // MARK: - Event Tap Recovery

    private func scheduleEventTapRecovery(for kind: EventTapKind, disabledType: CGEventType) {
        let now = Date()

        switch kind {
        case .escape:
            let decision = determineEventTapRecovery(
                now: now,
                lastDisableAt: escapeEventTapDisableState.lastDisableAt,
                consecutiveDisableCount: escapeEventTapDisableState.consecutiveDisableCount,
                disableLoopWindow: eventTapDisableLoopWindow,
                maxReenableAttemptsBeforeRecreate: maxEventTapReenableAttemptsBeforeRecreate
            )
            escapeEventTapDisableState.lastDisableAt = now
            escapeEventTapDisableState.consecutiveDisableCount = decision.consecutiveDisableCount
            escapeEventTapDisableState.lastDisabledTypeRawValue = disabledType.rawValue

            guard escapeEventTapRecoveryTask == nil else { return }
            let recoveryDelay = eventTapRecoveryDelay
            escapeEventTapRecoveryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: recoveryDelay)
                guard let self, !Task.isCancelled else { return }
                self.escapeEventTapRecoveryTask = nil
                self.performEventTapRecovery(for: .escape)
            }
        case .modifier:
            let decision = determineEventTapRecovery(
                now: now,
                lastDisableAt: modifierEventTapDisableState.lastDisableAt,
                consecutiveDisableCount: modifierEventTapDisableState.consecutiveDisableCount,
                disableLoopWindow: eventTapDisableLoopWindow,
                maxReenableAttemptsBeforeRecreate: maxEventTapReenableAttemptsBeforeRecreate
            )
            modifierEventTapDisableState.lastDisableAt = now
            modifierEventTapDisableState.consecutiveDisableCount = decision.consecutiveDisableCount
            modifierEventTapDisableState.lastDisabledTypeRawValue = disabledType.rawValue

            guard modifierEventTapRecoveryTask == nil else { return }
            let recoveryDelay = eventTapRecoveryDelay
            modifierEventTapRecoveryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: recoveryDelay)
                guard let self, !Task.isCancelled else { return }
                self.modifierEventTapRecoveryTask = nil
                self.performEventTapRecovery(for: .modifier)
            }
        }
    }

    private func performEventTapRecovery(for kind: EventTapKind) {
        switch kind {
        case .escape:
            let state = escapeEventTapDisableState
            resetEventTapRecoveryState(for: .escape)

            guard state.consecutiveDisableCount > 0 else { return }

            if state.consecutiveDisableCount >= maxEventTapReenableAttemptsBeforeRecreate {
                Log.app.error(
                    "Escape key monitor kept disabling (count=\(state.consecutiveDisableCount), lastType=\(state.lastDisabledTypeRawValue ?? 0)); recreating monitor"
                )
                teardownEscapeKeyMonitor()
                setupEscapeKeyMonitor()
                return
            }

            guard let tap = escapeEventTap else { return }

            eventTapRunLoopThread.performAndWait { _ in
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            Log.app.warning("Escape key monitor was disabled (type=\(state.lastDisabledTypeRawValue ?? 0)); re-enabled after backoff")
        case .modifier:
            let state = modifierEventTapDisableState
            resetEventTapRecoveryState(for: .modifier)

            guard state.consecutiveDisableCount > 0 else { return }

            if state.consecutiveDisableCount >= maxEventTapReenableAttemptsBeforeRecreate {
                Log.hotkey.error(
                    "Modifier key monitor kept disabling (count=\(state.consecutiveDisableCount), lastType=\(state.lastDisabledTypeRawValue ?? 0)); recreating monitor"
                )
                teardownModifierKeyMonitor()
                setupModifierKeyMonitor()
                return
            }

            guard let tap = modifierEventTap else { return }

            eventTapRunLoopThread.performAndWait { _ in
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            Log.hotkey.warning("Modifier key monitor was disabled (type=\(state.lastDisabledTypeRawValue ?? 0)); re-enabled after backoff")
        }
    }

    private func resetEventTapRecoveryState(for kind: EventTapKind) {
        switch kind {
        case .escape:
            escapeEventTapDisableState = EventTapDisableState()
        case .modifier:
            modifierEventTapDisableState = EventTapDisableState()
        }
    }

    // MARK: - Global Monitor Fallbacks

    private func installEscapeGlobalMonitorFallbackIfNeeded() {
        guard escapeGlobalMonitor == nil else { return }

        escapeGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                self?.handleEscapeSignal(source: "nsevent-global")
            }
        }

        if escapeGlobalMonitor != nil {
            Log.app.warning("Using NSEvent global monitor fallback for escape key (observation only; suppression unavailable)")
        }
    }

    private func installModifierGlobalMonitorFallbackIfNeeded() {
        guard modifierGlobalMonitor == nil else { return }

        modifierGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let cgEvent = event.cgEvent else { return }
            Task { @MainActor in
                self?.onModifierFlagsChanged?(cgEvent)
            }
        }

        if modifierGlobalMonitor != nil {
            Log.hotkey.warning("Using NSEvent global monitor fallback for modifier changes")
        }
    }

    // MARK: - Key Event Handlers

    private nonisolated func handleKeyEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor in
                self.scheduleEventTapRecovery(for: .escape, disabledType: type)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 53 else {
            Task { @MainActor in
                self.onNonEscapeKeyDown?()
            }
            return Unmanaged.passUnretained(event)
        }

        let shouldSuppress: Bool
        if Thread.isMainThread {
            shouldSuppress = MainActor.assumeIsolated {
                let suppress = Self.shouldSuppressEscapeEvent(
                    isRecording: self.isRecordingProvider(),
                    isProcessing: self.isProcessingProvider()
                )
                self.handleEscapeSignal(source: "cg-event-tap")

                if suppress {
                    Log.app.info("Escape intercepted+suppressing (recordingOrProcessing=true)")
                } else {
                    Log.app.debug("Escape observed+forwarding (recordingOrProcessing=false)")
                }

                return suppress
            }
        } else {
            shouldSuppress = DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    let suppress = Self.shouldSuppressEscapeEvent(
                        isRecording: self.isRecordingProvider(),
                        isProcessing: self.isProcessingProvider()
                    )
                    self.handleEscapeSignal(source: "cg-event-tap")

                    if suppress {
                        Log.app.info("Escape intercepted+suppressing (recordingOrProcessing=true)")
                    } else {
                        Log.app.debug("Escape observed+forwarding (recordingOrProcessing=false)")
                    }

                    return suppress
                }
            }
        }

        return shouldSuppress ? nil : Unmanaged.passUnretained(event)
    }

    private func handleEscapeSignal(source: String) {
        let now = Date()
        if let lastSignal = lastEscapeSignalTime,
           now.timeIntervalSince(lastSignal) <= duplicateEscapeSignalThreshold {
            Log.app.debug("Ignoring duplicate escape signal from \(source)")
            return
        }

        lastEscapeSignalTime = now
        Log.app.info("Escape signal received (source=\(source))")
        handleEscapeKeyPress()
    }

    private nonisolated func handleModifierKeyEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor in
                self.scheduleEventTapRecovery(for: .modifier, disabledType: type)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }

        Task { @MainActor in
            self.onModifierFlagsChanged?(event)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleEscapeKeyPress() {
        guard isRecordingProvider() || isProcessingProvider() else { return }

        let now = Date()

        if Self.isDoubleEscapePress(
            now: now,
            lastEscapeTime: lastEscapeTime,
            threshold: doubleEscapeThreshold
        ) {
            lastEscapeTime = nil
            clearEscapePrimed?()
            onCancelCurrentOperation?()
        } else {
            lastEscapeTime = now
            if isFloatingIndicatorEnabledProvider() {
                showEscapePrimed?()
            }
        }
    }
}
