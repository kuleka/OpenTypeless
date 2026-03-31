//
//  CoordinatorTypes.swift
//  OpenTypeless
//
//  Shared types used across AppCoordinator and extracted sub-coordinators.
//

import Foundation
import AppKit

// MARK: - Event Tap Run Loop Thread

final class EventTapRunLoopThread: Thread {

    private let readinessSemaphore = DispatchSemaphore(value: 0)
    private let stateLock = NSLock()
    private var runLoop: CFRunLoop?
    private let keepAlivePort = Port()

    init(name: String) {
        super.init()
        self.name = name
        self.qualityOfService = .userInteractive
    }

    override func main() {
        let currentRunLoop = CFRunLoopGetCurrent()

        stateLock.lock()
        runLoop = currentRunLoop
        stateLock.unlock()

        RunLoop.current.add(keepAlivePort, forMode: .default)
        readinessSemaphore.signal()

        while !isCancelled {
            autoreleasepool {
                _ = RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }

        stateLock.lock()
        runLoop = nil
        stateLock.unlock()
    }

    func performAndWait(_ block: @escaping (CFRunLoop) -> Void) {
        startIfNeeded()

        guard let runLoop = currentRunLoop else { return }
        guard let defaultMode = CFRunLoopMode.defaultMode else { return }

        let completionSemaphore = DispatchSemaphore(value: 0)
        CFRunLoopPerformBlock(runLoop, defaultMode.rawValue as CFTypeRef) {
            block(runLoop)
            completionSemaphore.signal()
        }
        CFRunLoopWakeUp(runLoop)
        completionSemaphore.wait()
    }

    func stopIfNeeded() {
        guard let runLoop = currentRunLoop else { return }
        guard let defaultMode = CFRunLoopMode.defaultMode else { return }

        let completionSemaphore = DispatchSemaphore(value: 0)
        CFRunLoopPerformBlock(runLoop, defaultMode.rawValue as CFTypeRef) {
            CFRunLoopStop(runLoop)
            completionSemaphore.signal()
        }
        CFRunLoopWakeUp(runLoop)
        completionSemaphore.wait()
        cancel()
    }

    private func startIfNeeded() {
        guard !isExecuting && !isFinished else { return }
        start()
        readinessSemaphore.wait()
    }

    private var currentRunLoop: CFRunLoop? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return runLoop
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let switchModel = Notification.Name("com.yisu.opentypeless.switchModel")
    static let modelActiveChanged = Notification.Name("com.yisu.opentypeless.modelActiveChanged")
    static let requestActiveModel = Notification.Name("com.yisu.opentypeless.requestActiveModel")
    static let rerunOnboarding = Notification.Name("com.yisu.opentypeless.rerunOnboarding")
}

// MARK: - Hotkey Types

struct HotkeyConflict: Equatable {
    let existingIdentifier: String
    let incomingIdentifier: String
    let combination: HotkeyRegistrationState.Combination

    var conflictKey: String {
        [existingIdentifier, incomingIdentifier]
            .sorted()
            .joined(separator: "|") + "|\(combination.keyCode)|\(combination.modifiers)"
    }
}

struct HotkeyRegistrationState {
    struct Combination: Hashable {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    private(set) var registeredIdentifiersByCombination: [Combination: String] = [:]

    static func shouldRegisterHotkeys(hasCompletedOnboarding: Bool) -> Bool {
        hasCompletedOnboarding
    }

    mutating func register(
        identifier: String,
        keyCode: UInt32,
        modifiers: UInt32
    ) -> HotkeyConflict? {
        let combination = Combination(keyCode: keyCode, modifiers: modifiers)

        if let existingIdentifier = registeredIdentifiersByCombination[combination] {
            return HotkeyConflict(
                existingIdentifier: existingIdentifier,
                incomingIdentifier: identifier,
                combination: combination
            )
        }

        registeredIdentifiersByCombination[combination] = identifier
        return nil
    }
}

struct HotkeyBindingSnapshot: Equatable {
    let hotkey: String
    let keyCode: Int
    let modifiers: Int
}

struct HotkeySettingsSnapshot: Equatable {
    let hasCompletedOnboarding: Bool
    let pushToTalk: HotkeyBindingSnapshot
    let toggle: HotkeyBindingSnapshot
    let translate: HotkeyBindingSnapshot
}

// MARK: - Engine / Settings Snapshots

struct EngineProviderSettingsSnapshot: Equatable {
    let provider: String
    let apiBase: String
    let model: String
    let apiKey: String?
}

struct EngineSettingsSnapshot: Equatable {
    let host: String
    let port: Int
    let sttMode: STTMode
    let stt: EngineProviderSettingsSnapshot
    let llm: EngineProviderSettingsSnapshot
}

struct SettingsObservationSnapshot: Equatable {
    let outputMode: String
    let automaticDictionaryLearningEnabled: Bool
    let selectedInputDeviceUID: String
    let selectedAppLanguage: AppLanguage
    let floatingIndicatorEnabled: Bool
    let floatingIndicatorType: FloatingIndicatorType
    let aiEnhancementEnabled: Bool
    let enableUIContext: Bool
    let vibeLiveSessionEnabled: Bool
    let hotkeys: HotkeySettingsSnapshot
    let engine: EngineSettingsSnapshot
    let engineRuntimeRecheckSequence: Int
}

// MARK: - AppCoordinator Handler Types

struct EngineStartupHandlers {
    let health: @MainActor () async throws -> HealthResponse
    let fetchConfig: @MainActor () async throws -> ConfigResponse
    let pushConfig: @MainActor (ConfigRequest) async throws -> ConfigStatusResponse
}

struct PolishHandlers {
    let polish: @MainActor (
        _ text: String,
        _ appContext: AppContextInfo?,
        _ task: PolishTask,
        _ outputLanguage: String?
    ) async throws -> PolishService.PolishResult
}

struct RecordingPolishOutcome: Equatable {
    let finalText: String
    let originalText: String?
    let enhancedWithModel: String?
    let didAttemptPolish: Bool
    let usedFallback: Bool
}

// MARK: - Recording Types

enum RecordingTriggerSource: String {
    case statusBarMenu = "status-bar-menu"
    case hotkeyToggle = "hotkey-toggle"
    case hotkeyPushToTalk = "hotkey-push-to-talk"
    case floatingIndicatorStart = "floating-indicator-start"
    case floatingIndicatorStop = "floating-indicator-stop"
    case pillIndicatorStop = "pill-indicator-stop"
    case pillIndicatorStart = "pill-indicator-start"
    case bubbleIndicatorStart = "bubble-indicator-start"
    case bubbleIndicatorStop = "bubble-indicator-stop"
}

// MARK: - Engine Runtime Types

enum EngineRuntimeEvaluationTrigger {
    case startup
    case settingsChange
    case manualRecheck
}

enum EngineConfigurationReadiness {
    case ready(ConfigRequest)
    case incomplete(EngineRuntimeState.MissingConfiguration)
}

// MARK: - Event Tap Types

enum EventTapRecoveryAction: Equatable {
    case reenable
    case recreate
}

struct EventTapRecoveryDecision: Equatable {
    let consecutiveDisableCount: Int
    let action: EventTapRecoveryAction
}

enum EventTapKind {
    case escape
    case modifier
}

struct EventTapDisableState {
    var lastDisableAt: Date?
    var consecutiveDisableCount = 0
    var lastDisabledTypeRawValue: UInt32?
}

func determineEventTapRecovery(
    now: Date,
    lastDisableAt: Date?,
    consecutiveDisableCount: Int,
    disableLoopWindow: TimeInterval,
    maxReenableAttemptsBeforeRecreate: Int
) -> EventTapRecoveryDecision {
    let nextCount: Int
    if let lastDisableAt,
       now.timeIntervalSince(lastDisableAt) <= disableLoopWindow {
        nextCount = consecutiveDisableCount + 1
    } else {
        nextCount = 1
    }

    let recreateThreshold = max(1, maxReenableAttemptsBeforeRecreate)
    let action: EventTapRecoveryAction = nextCount >= recreateThreshold ? .recreate : .reenable

    return EventTapRecoveryDecision(
        consecutiveDisableCount: nextCount,
        action: action
    )
}
