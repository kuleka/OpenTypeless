//
//  ContextSessionCoordinator.swift
//  OpenTypeless
//
//  Manages live context session lifecycle: start, stop, suspend, polling,
//  app focus observation, workspace root detection, and context snapshot management.
//

import AppKit
import Foundation

@MainActor
final class ContextSessionCoordinator {

    // MARK: - Captured State (readable by recording/processing flow)

    private(set) var capturedContext: CapturedContext?
    private(set) var capturedSnapshot: ContextSnapshot?
    private(set) var capturedAdapterCapabilities: AppAdapterCapabilities?
    private(set) var capturedRoutingSignal: PromptRoutingSignal?

    // MARK: - Session State

    private var contextSessionState: ContextSessionState?
    private var contextSessionPollTimer: Timer?
    private var contextSessionAppActivationObserver: NSObjectProtocol?
    private var lastFocusOrWindowUpdateAt: Date?

    private let contextSessionPollInterval: TimeInterval = 1.25
    private let contextSessionFocusUpdateThrottle: TimeInterval = 0.75

    let appContextAdapterRegistry = AppContextAdapterRegistry()
    let promptRoutingResolver: any PromptRoutingResolver = NoOpPromptRoutingResolver()

    // MARK: - Dependencies

    private let settingsStore: SettingsStore
    private let contextEngineService: ContextEngineService
    private let contextCaptureService: ContextCaptureService
    private let mentionRewriteService: MentionRewriteService
    private let permissionManager: PermissionManager

    // MARK: - State Providers

    var isRecordingProvider: () -> Bool = { false }
    var recordingStartTimeProvider: () -> Date? = { nil }

    // MARK: - Init

    init(
        settingsStore: SettingsStore,
        contextEngineService: ContextEngineService,
        contextCaptureService: ContextCaptureService,
        mentionRewriteService: MentionRewriteService,
        permissionManager: PermissionManager
    ) {
        self.settingsStore = settingsStore
        self.contextEngineService = contextEngineService
        self.contextCaptureService = contextCaptureService
        self.mentionRewriteService = mentionRewriteService
        self.permissionManager = permissionManager
    }

    // MARK: - Live Session Queries

    func shouldRunLiveContextSession() -> Bool {
        settingsStore.aiEnhancementEnabled &&
            settingsStore.enableUIContext &&
            settingsStore.vibeLiveSessionEnabled
    }

    func currentLiveSessionContext() -> LiveSessionContext? {
        guard let contextSessionState else { return nil }

        let enrichment = contextSessionState.latestAdapterEnrichment
        let latestTransition = contextSessionState.transitions.last

        let fileTagCandidates = mergeUniqueContextSignals(
            enrichment?.fileTagCandidates ?? [],
            contextSessionState.transitions.compactMap { $0.activeFilePath },
            contextSessionState.transitions.flatMap { $0.contextTags }
        )

        return LiveSessionContext(
            runtimeState: contextSessionState.runtimeState,
            latestAppName: contextSessionState.latestSnapshot.appContext?.appName,
            latestWindowTitle: contextSessionState.latestSnapshot.appContext?.windowTitle,
            activeFilePath: latestTransition?.activeFilePath ?? enrichment?.activeFilePath ?? contextSessionState.latestSnapshot.appContext?.documentPath,
            activeFileConfidence: latestTransition?.activeFileConfidence ?? enrichment?.activeFileConfidence ?? 0,
            workspacePath: latestTransition?.workspacePath ?? contextSessionState.latestRoutingSignal.workspacePath ?? enrichment?.workspacePath,
            workspaceConfidence: latestTransition?.workspaceConfidence ?? enrichment?.workspaceConfidence ?? 0,
            fileTagCandidates: fileTagCandidates,
            styleSignals: enrichment?.styleSignals ?? [],
            codingSignals: enrichment?.codingSignals ?? [],
            transitions: contextSessionState.transitions
        ).bounded()
    }

    // MARK: - Vibe Runtime State

    func updateVibeRuntimeStateFromSettings() {
        guard settingsStore.aiEnhancementEnabled else {
            settingsStore.updateVibeRuntimeState(.degraded, detail: "AI enhancement is disabled.")
            return
        }

        guard settingsStore.enableUIContext else {
            settingsStore.updateVibeRuntimeState(.degraded, detail: "Vibe mode is disabled.")
            return
        }

        guard settingsStore.vibeLiveSessionEnabled else {
            settingsStore.updateVibeRuntimeState(.limited, detail: "Live session updates are disabled.")
            return
        }

        if let contextSessionState {
            let detail = contextEngineService.deriveRuntimeDetail(
                for: contextSessionState.latestSnapshot,
                runtimeState: contextSessionState.runtimeState
            )
            settingsStore.updateVibeRuntimeState(contextSessionState.runtimeState, detail: detail)
            return
        }

        if permissionManager.checkAccessibilityPermission() {
            settingsStore.updateVibeRuntimeState(.ready, detail: "Ready for live session context.")
        } else {
            settingsStore.updateVibeRuntimeState(.limited, detail: "Accessibility permission not granted. Using limited context.")
        }
    }

    // MARK: - Initial Context Capture (at recording start)

    func captureInitialContext() {
        capturedAdapterCapabilities = nil
        capturedRoutingSignal = nil
        contextSessionState = nil
        lastFocusOrWindowUpdateAt = nil

        guard settingsStore.enableClipboardContext || settingsStore.enableUIContext else {
            capturedContext = nil
            capturedSnapshot = nil
            return
        }

        let clipboardText = settingsStore.enableClipboardContext ? contextCaptureService.captureClipboardText() : nil
        capturedContext = CapturedContext(clipboardText: clipboardText)

        var appContext: AppContextInfo? = nil
        var captureWarnings: [ContextCaptureWarning] = []
        if settingsStore.enableUIContext {
            let result = contextEngineService.captureAppContext()
            appContext = result.appContext
            captureWarnings = result.warnings
            if !captureWarnings.isEmpty {
                Log.app.debug("UI context capture warnings: \(captureWarnings.map(\.localizedDescription).joined(separator: ", "))")
            }
            if let ctx = appContext {
                Log.app.info("Captured UI context: hasAppName=\(!ctx.appName.isEmpty), hasWindowTitle=\(ctx.windowTitle != nil)")
            }
        }

        capturedSnapshot = ContextSnapshot(
            timestamp: Date(),
            appContext: appContext,
            clipboardText: clipboardText,
            warnings: captureWarnings
        )

        if let snapshot = capturedSnapshot {
            let routingSignal = PromptRoutingSignal.from(
                snapshot: snapshot,
                adapterRegistry: appContextAdapterRegistry
            )
            capturedRoutingSignal = routingSignal
            _ = promptRoutingResolver.resolve(signal: routingSignal)

            if let bundleIdentifier = snapshot.appContext?.bundleIdentifier {
                let adapter = appContextAdapterRegistry.adapter(for: bundleIdentifier)
                capturedAdapterCapabilities = adapter.capabilities
                let caps = adapter.capabilities
                Log.context.info("Adapter context: app=\(caps.displayName) prefix=\(caps.mentionPrefix) fileMentions=\(caps.supportsFileMentions) codeContext=\(caps.supportsCodeContext) docsMentions=\(caps.supportsDocsMentions) diffContext=\(caps.supportsDiffContext) webContext=\(caps.supportsWebContext) chatHistory=\(caps.supportsChatHistory)")
            }
        }
    }

    // MARK: - Session Lifecycle

    func startLiveContextSessionIfNeeded(initialSnapshot: ContextSnapshot?) {
        guard isRecordingProvider() else { return }
        guard shouldRunLiveContextSession() else {
            stopLiveContextSession()
            updateVibeRuntimeStateFromSettings()
            return
        }

        installContextSessionObserversIfNeeded()

        if contextSessionPollTimer == nil {
            let timer = Timer.scheduledTimer(withTimeInterval: contextSessionPollInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.isRecordingProvider(), self.shouldRunLiveContextSession() else { return }
                    await self.updateContextSession(trigger: .poll)
                }
            }
            timer.tolerance = 0.2
            RunLoop.main.add(timer, forMode: .common)
            contextSessionPollTimer = timer
        }

        if contextSessionState == nil {
            Task { @MainActor in
                await self.updateContextSession(trigger: .recordingStart, snapshotOverride: initialSnapshot)
            }
        }
    }

    func stopLiveContextSession() {
        contextSessionPollTimer?.invalidate()
        contextSessionPollTimer = nil
        removeContextSessionObserversIfNeeded()
        contextSessionState = nil
        lastFocusOrWindowUpdateAt = nil
    }

    func suspendLiveContextSessionUpdates() {
        contextSessionPollTimer?.invalidate()
        contextSessionPollTimer = nil
        removeContextSessionObserversIfNeeded()
    }

    func clearCapturedState() {
        capturedContext = nil
        capturedSnapshot = nil
        capturedAdapterCapabilities = nil
        capturedRoutingSignal = nil
        stopLiveContextSession()
    }

    // MARK: - Observers

    private func installContextSessionObserversIfNeeded() {
        guard contextSessionAppActivationObserver == nil else { return }

        contextSessionAppActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.isRecordingProvider(), self.shouldRunLiveContextSession() else { return }
                await self.updateContextSession(trigger: .frontmostAppChange)
            }
        }
    }

    private func removeContextSessionObserversIfNeeded() {
        if let contextSessionAppActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(contextSessionAppActivationObserver)
            self.contextSessionAppActivationObserver = nil
        }
    }

    func scheduleFocusOrWindowContextRefreshIfNeeded() {
        guard isRecordingProvider(), shouldRunLiveContextSession() else { return }

        let now = Date()
        if let lastFocusOrWindowUpdateAt,
           now.timeIntervalSince(lastFocusOrWindowUpdateAt) < contextSessionFocusUpdateThrottle {
            return
        }

        lastFocusOrWindowUpdateAt = now
        Task { @MainActor in
            await self.updateContextSession(trigger: .focusOrWindowChange)
        }
    }

    // MARK: - Context Session Update

    private func updateContextSession(
        trigger: ContextSessionUpdateTrigger,
        snapshotOverride: ContextSnapshot? = nil
    ) async {
        guard isRecordingProvider() else { return }
        guard settingsStore.enableUIContext else { return }

        let clipboardText = settingsStore.enableClipboardContext ? capturedContext?.clipboardText : nil
        let snapshot = snapshotOverride ?? contextEngineService.captureSnapshot(clipboardText: clipboardText)
        capturedSnapshot = snapshot

        let routingSignal = PromptRoutingSignal.from(
            snapshot: snapshot,
            adapterRegistry: appContextAdapterRegistry
        )
        capturedRoutingSignal = routingSignal
        _ = promptRoutingResolver.resolve(signal: routingSignal)

        var adapterCapabilities: AppAdapterCapabilities?
        var adapterEnrichment: AppRuntimeEnrichment?

        if let bundleIdentifier = snapshot.appContext?.bundleIdentifier {
            let adapter = appContextAdapterRegistry.adapter(for: bundleIdentifier)
            adapterCapabilities = adapter.capabilities
            adapterEnrichment = appContextAdapterRegistry.enrichment(for: snapshot, routingSignal: routingSignal)
        }

        capturedAdapterCapabilities = adapterCapabilities

        let workspaceRoots = deriveWorkspaceRoots(routingSignal: routingSignal, snapshot: snapshot)
        let workspaceInsights = await mentionRewriteService.deriveWorkspaceInsights(
            workspaceRoots: workspaceRoots,
            activeDocumentPath: snapshot.appContext?.documentPath
        )

        let activeFilePath = workspaceInsights.activeDocumentRelativePath
            ?? adapterEnrichment?.activeFilePath
            ?? snapshot.appContext?.documentPath

        let activeFileConfidence = max(
            workspaceInsights.activeDocumentConfidence,
            adapterEnrichment?.activeFileConfidence ?? 0
        )

        let workspacePath = routingSignal.workspacePath
            ?? workspaceInsights.normalizedWorkspaceRoots.first
            ?? adapterEnrichment?.workspacePath

        let workspaceConfidence = max(
            workspaceInsights.workspaceConfidence,
            adapterEnrichment?.workspaceConfidence ?? 0
        )

        let contextTags = mergeUniqueContextSignals(
            workspaceInsights.fileTagCandidates,
            adapterEnrichment?.fileTagCandidates ?? [],
            adapterEnrichment?.styleSignals ?? [],
            adapterEnrichment?.codingSignals ?? []
        )

        let transitionSignature = buildSessionTransitionSignature(
            snapshot: snapshot,
            activeFilePath: activeFilePath,
            workspacePath: workspacePath
        )

        let runtimeState = contextEngineService.deriveRuntimeState(
            for: snapshot,
            adapterCapabilities: adapterCapabilities
        )

        let transition = ContextSessionTransition(
            timestamp: snapshot.timestamp,
            trigger: trigger,
            snapshot: snapshot,
            activeFilePath: activeFilePath,
            activeFileConfidence: activeFileConfidence,
            workspacePath: workspacePath,
            workspaceConfidence: workspaceConfidence,
            outputMode: settingsStore.outputMode,
            contextTags: contextTags,
            transitionSignature: transitionSignature
        )

        if var contextSessionState {
            contextSessionState.latestSnapshot = snapshot
            contextSessionState.latestRoutingSignal = routingSignal
            contextSessionState.latestAdapterCapabilities = adapterCapabilities
            contextSessionState.latestAdapterEnrichment = adapterEnrichment
            contextSessionState.runtimeState = runtimeState

            if shouldAppendTransition(
                signature: transitionSignature,
                trigger: trigger,
                in: contextSessionState
            ) {
                contextSessionState.appendTransition(transition)
            }

            self.contextSessionState = contextSessionState
        } else {
            self.contextSessionState = ContextSessionState(
                startedAt: recordingStartTimeProvider() ?? Date(),
                latestSnapshot: snapshot,
                latestRoutingSignal: routingSignal,
                latestAdapterCapabilities: adapterCapabilities,
                latestAdapterEnrichment: adapterEnrichment,
                runtimeState: runtimeState,
                transitions: [transition]
            )
        }

        let runtimeDetail = contextEngineService.deriveRuntimeDetail(
            for: snapshot,
            runtimeState: runtimeState
        )
        settingsStore.updateVibeRuntimeState(runtimeState, detail: runtimeDetail)
    }

    // MARK: - Helpers

    func deriveWorkspaceRoots(
        routingSignal: PromptRoutingSignal?,
        snapshot: ContextSnapshot?
    ) -> [String] {
        var roots: [String] = []

        if let workspacePath = routingSignal?.workspacePath,
           !workspacePath.isEmpty {
            roots.append(workspacePath)
        } else if let documentPath = snapshot?.appContext?.documentPath,
                  !documentPath.isEmpty {
            let parent = (documentPath as NSString).deletingLastPathComponent
            if !parent.isEmpty {
                roots.append(parent)
            }
        }

        return mergeUniqueContextSignals(roots)
    }

    func mergeUniqueContextSignals(_ groups: [String]..., limit: Int = 8) -> [String] {
        var seen = Set<String>()
        var merged: [String] = []

        for group in groups {
            for value in group {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else { continue }
                if seen.insert(normalized).inserted {
                    merged.append(normalized)
                }
                if merged.count >= limit {
                    return merged
                }
            }
        }

        return merged
    }

    func mentionRewriteWorkspaceDebugSummary(
        adapterName: String,
        routingSignal: PromptRoutingSignal?,
        snapshot: ContextSnapshot?,
        derivedWorkspaceRoots: [String]
    ) -> String {
        let appContext = snapshot?.appContext
        return """
        adapter=\(adapterName) bundle=\(routingSignal?.appBundleIdentifier ?? "nil") app=\(appContext?.appName ?? "nil") signalWorkspacePresent=\(hasUsableContextValue(routingSignal?.workspacePath)) documentPathPresent=\(hasUsableContextValue(appContext?.documentPath)) windowTitlePresent=\(hasUsableContextValue(appContext?.windowTitle)) focusedValuePresent=\(hasUsableContextValue(appContext?.focusedElementValue)) terminalProvider=\(routingSignal?.terminalProviderIdentifier ?? "nil") isCodeEditorContext=\(routingSignal?.isCodeEditorContext ?? false) derivedWorkspaceRootCount=\(derivedWorkspaceRoots.count)
        """
    }

    private func hasUsableContextValue(_ value: String?) -> Bool {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !value.isEmpty
    }

    private func buildSessionTransitionSignature(
        snapshot: ContextSnapshot,
        activeFilePath: String?,
        workspacePath: String?
    ) -> String {
        let signature = snapshot.transitionSignature
        return [
            signature.bundleIdentifier,
            signature.windowTitle,
            signature.focusedElementRole,
            signature.documentPath,
            signature.selectedText,
            activeFilePath,
            workspacePath
        ]
        .map { $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        .joined(separator: "|")
    }

    private func shouldAppendTransition(
        signature: String,
        trigger: ContextSessionUpdateTrigger,
        in session: ContextSessionState
    ) -> Bool {
        guard trigger != .recordingStart else { return true }
        guard let lastSignature = session.transitions.last?.transitionSignature else { return true }
        return lastSignature != signature
    }
}
