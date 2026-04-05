//
//  RecordingCoordinator.swift
//  OpenTypeless
//
//  Manages the entire recording lifecycle: start, stop, push-to-talk, streaming
//  transcription, audio processing, text normalization, polish orchestration,
//  and output delivery.
//

import AVFoundation
import Foundation

@MainActor
@Observable
final class RecordingCoordinator {

    // MARK: - Observable State

    var isRecording = false
    var isProcessing = false
    var error: Error?

    // MARK: - Recording State

    var recordingStartTime: Date?
    var pendingTranslateTask = false

    private(set) var isStreamingTranscriptionSessionActive = false
    private var streamingAudioProcessingTask: Task<Void, Never>?
    private var streamingInsertionUpdateTask: Task<Void, Never>?
    private var recordingStartAttemptCounter: UInt64 = 0

    // MARK: - Dependencies

    private let audioRecorder: AudioRecorder
    private let transcriptionService: TranscriptionService
    private let outputManager: OutputManager
    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore
    private let polishHandlers: PolishHandlers
    private let toastService: ToastService
    private let mediaPauseService: MediaPauseService
    private let contextEngineService: ContextEngineService
    private let mentionRewriteService: MentionRewriteService
    private let permissionManager: PermissionManager
    private let floatingIndicatorCoordinator: FloatingIndicatorCoordinator
    private let contextSessionCoordinator: ContextSessionCoordinator
    private let engineRuntimeCoordinator: EngineRuntimeCoordinator

    // MARK: - Callbacks

    var onStatusBarRecording: () -> Void = {}
    var onStatusBarProcessing: () -> Void = {}
    var onStatusBarIdle: () -> Void = {}
    var onUpdateMenuState: () -> Void = {}
    var onUpdateRecentTranscriptsMenu: () -> Void = {}
    var onEnsureAccessibilityForDirectInsert: (_ trigger: String, _ showFallbackAlert: Bool) -> Void = { _, _ in }
    var onEnsureGlobalKeyMonitors: () -> Void = {}

    // MARK: - Init

    init(
        audioRecorder: AudioRecorder,
        transcriptionService: TranscriptionService,
        outputManager: OutputManager,
        settingsStore: SettingsStore,
        historyStore: HistoryStore,
        polishHandlers: PolishHandlers,
        toastService: ToastService,
        mediaPauseService: MediaPauseService,
        contextEngineService: ContextEngineService,
        mentionRewriteService: MentionRewriteService,
        permissionManager: PermissionManager,
        floatingIndicatorCoordinator: FloatingIndicatorCoordinator,
        contextSessionCoordinator: ContextSessionCoordinator,
        engineRuntimeCoordinator: EngineRuntimeCoordinator
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.outputManager = outputManager
        self.settingsStore = settingsStore
        self.historyStore = historyStore
        self.polishHandlers = polishHandlers
        self.toastService = toastService
        self.mediaPauseService = mediaPauseService
        self.contextEngineService = contextEngineService
        self.mentionRewriteService = mentionRewriteService
        self.permissionManager = permissionManager
        self.floatingIndicatorCoordinator = floatingIndicatorCoordinator
        self.contextSessionCoordinator = contextSessionCoordinator
        self.engineRuntimeCoordinator = engineRuntimeCoordinator
    }

    // MARK: - Entry Points

    func handlePushToTalkStart() async {
        guard !isRecording && !isProcessing else { return }

        do {
            try await startRecording(source: .hotkeyPushToTalk)
        } catch {
            self.error = error
            audioRecorder.resetAudioEngine()
            Log.app.error("Failed to start recording: \(error)")
            handleRecordingStartFailure(error, source: .hotkeyPushToTalk)
        }
    }

    func handlePushToTalkEnd() async {
        guard isRecording else { return }

        do {
            try await stopRecordingAndTranscribe()
        } catch {
            self.error = error
            audioRecorder.resetAudioEngine()
            Log.app.error("Failed to stop recording: \(error)")
        }
    }

    func handleToggleRecording(source: RecordingTriggerSource) async {
        if isRecording {
            do {
                try await stopRecordingAndTranscribe()
            } catch {
                self.error = error
                audioRecorder.resetAudioEngine()
                Log.app.error("Failed to stop recording: \(error)")
            }
        } else if !isProcessing {
            do {
                try await startRecording(source: source)
            } catch {
                self.error = error
                audioRecorder.resetAudioEngine()
                Log.app.error("Failed to start recording: \(error)")
                handleRecordingStartFailure(error, source: source)
            }
        }
    }

    func handleTranslateToggle() async {
        if isRecording {
            do {
                try await stopRecordingAndTranscribe()
            } catch {
                self.error = error
                audioRecorder.resetAudioEngine()
                Log.app.error("Failed to stop translate recording: \(error)")
            }
        } else if !isProcessing {
            pendingTranslateTask = true
            do {
                try await startRecording(source: .hotkeyToggle)
            } catch {
                pendingTranslateTask = false
                self.error = error
                audioRecorder.resetAudioEngine()
                Log.app.error("Failed to start translate recording: \(error)")
                handleRecordingStartFailure(error, source: .hotkeyToggle)
            }
        }
    }

    // MARK: - Recording Lifecycle

    func startRecording(source: RecordingTriggerSource) async throws {
        logRecordingStartAttempt(source: source)

        onEnsureGlobalKeyMonitors()

        await beginStreamingSessionIfAvailable()

        let didStartRecording: Bool
        do {
            didStartRecording = try await audioRecorder.startRecording()
        } catch {
            if isStreamingTranscriptionSessionActive {
                await cancelStreamingSession(preserveInsertedText: true)
            }
            Log.app.error("Audio engine failed to start: \(error)")
            throw error
        }

        guard didStartRecording else {
            if isStreamingTranscriptionSessionActive {
                await cancelStreamingSession(preserveInsertedText: true)
            }
            Log.app.debug("Recording start already in progress; ignoring duplicate start request")
            return
        }

        if settingsStore.pauseMediaOnRecording || settingsStore.muteAudioDuringRecording {
            mediaPauseService.beginRecordingSession(
                pauseMedia: settingsStore.pauseMediaOnRecording,
                muteSystemAudio: settingsStore.muteAudioDuringRecording
            )
        }

        isRecording = true
        recordingStartTime = Date()
        contextSessionCoordinator.captureInitialContext()

        if contextSessionCoordinator.shouldRunLiveContextSession() {
            contextSessionCoordinator.startLiveContextSessionIfNeeded(initialSnapshot: contextSessionCoordinator.capturedSnapshot)
        } else {
            contextSessionCoordinator.updateVibeRuntimeStateFromSettings()
        }

        onStatusBarRecording()

        floatingIndicatorCoordinator.startRecordingIndicatorSession()
    }

    func stopRecordingAndTranscribe() async throws {
        guard let startTime = recordingStartTime else {
            Log.app.warning("stopRecordingAndTranscribe called but recordingStartTime is nil")
            return
        }

        if isStreamingTranscriptionSessionActive {
            try await stopRecordingAndFinalizeStreaming()
            return
        }

        isRecording = false
        mediaPauseService.endRecordingSession()
        contextSessionCoordinator.suspendLiveContextSessionUpdates()
        isProcessing = true
        var didResetProcessingState = false

        onStatusBarProcessing()

        floatingIndicatorCoordinator.transitionRecordingIndicatorToProcessing()

        defer {
            if !didResetProcessingState {
                resetProcessingState()
            }
        }

        let audioData: Data
        do {
            audioData = try await audioRecorder.stopRecording()
        } catch {
            Log.app.error("Failed to stop recording: \(error)")
            throw error
        }

        let duration = Date().timeIntervalSince(startTime)
        do {
            try await processRecordedAudioData(audioData, duration: duration)
        } catch let error as TranscriptionService.TranscriptionError {
            Log.app.error("Transcription failed: \(error)")
            resetProcessingState()
            didResetProcessingState = true
            let message: String
            switch error {
            case .modelNotLoaded:
                message = "No model loaded. Please download a model in Settings."
            case .engineRuntimeFailure:
                message = engineRuntimeCoordinator.remoteEngineBlockedMessage(for: settingsStore.engineRuntimeState)
            default:
                message = "Transcription failed: \(error.localizedDescription)"
            }
            toastService.show(
                ToastPayload(message: message, style: .error)
            )
            throw error
        } catch {
            Log.app.error("Transcription failed: \(error)")
            resetProcessingState()
            didResetProcessingState = true
            toastService.show(
                ToastPayload(message: "Transcription failed: \(error.localizedDescription)", style: .error)
            )
            throw error
        }
    }

    // MARK: - Cancel / Reset

    func cancelCurrentOperation() {
        guard isRecording || isProcessing else {
            Log.app.debug("Double-escape pressed but no operation in progress")
            return
        }

        Log.app.info("Cancelling current operation via double-escape")
        let hadStreamingSession = isStreamingTranscriptionSessionActive
        clearStreamingSessionBindings(cancelPendingWork: true)
        isStreamingTranscriptionSessionActive = false
        if hadStreamingSession {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.transcriptionService.cancelStreaming()
                await self.outputManager.cancelStreamingInsertion(removeInsertedText: false)
            }
        }

        audioRecorder.resetAudioEngine()
        mediaPauseService.endRecordingSession()
        isRecording = false
        isProcessing = false
        recordingStartTime = nil
        contextSessionCoordinator.clearCapturedState()
        contextSessionCoordinator.updateVibeRuntimeStateFromSettings()
        error = nil

        onStatusBarIdle()
        onUpdateMenuState()

        floatingIndicatorCoordinator.finishIndicatorSession()
    }

    func resetProcessingState() {
        mediaPauseService.endRecordingSession()
        isProcessing = false
        recordingStartTime = nil
        contextSessionCoordinator.clearCapturedState()
        contextSessionCoordinator.updateVibeRuntimeStateFromSettings()
        onStatusBarIdle()
        onUpdateMenuState()

        floatingIndicatorCoordinator.finishIndicatorSession()
    }

    // MARK: - Audio Processing

    func processRecordedAudioData(_ audioData: Data, duration: TimeInterval) async throws {
        guard !audioData.isEmpty else {
            Log.app.warning("No audio data recorded")
            handleNoSpeechDetected(context: "recording")
            return
        }

        if settingsStore.sttMode == .remote, !settingsStore.engineRuntimeState.isReady {
            toastService.show(
                ToastPayload(
                    message: engineRuntimeCoordinator.remoteEngineBlockedMessage(for: settingsStore.engineRuntimeState),
                    style: .error
                )
            )
            return
        }

        let diarizationEnabled = Self.shouldUseSpeakerDiarization(
            diarizationFeatureEnabled: settingsStore.diarizationFeatureEnabled,
            isStreamingSessionActive: false
        )
        Log.app.info("Speaker diarization \(diarizationEnabled ? "enabled" : "disabled") for batch transcription")

        let transcriptionOutput: TranscriptionOutput
        do {
            transcriptionOutput = try await transcriptionService.transcribe(
                audioData: audioData,
                diarizationEnabled: diarizationEnabled,
                options: TranscriptionOptions(language: .automatic)
            )
        } catch let error as TranscriptionService.TranscriptionError {
            engineRuntimeCoordinator.handleTranscriptionRuntimeFailure(error)
            throw error
        } catch {
            throw error
        }

        if diarizationEnabled {
            let segmentCount = transcriptionOutput.diarizedSegments?.count ?? 0
            if segmentCount > 0 {
                Log.app.info("Batch diarization produced \(segmentCount) segments")
            } else {
                Log.app.info("Batch diarization produced no attributed segments")
            }
        }

        let diarizationSegmentsJSON = encodeDiarizationSegmentsJSON(transcriptionOutput.diarizedSegments)
        let transcribedText = transcriptionOutput.text

        let normalizedText = normalizedTranscriptionText(transcribedText)

        guard !isTranscriptionEffectivelyEmpty(normalizedText) else {
            handleNoSpeechDetected(context: "recording")
            return
        }

        // Mention rewrite: resolve spoken file mentions to app-specific syntax
        var textAfterMentions = normalizedText
        var mentionFormattingCapabilities = contextSessionCoordinator.capturedAdapterCapabilities
        let derivedWorkspaceRoots = contextSessionCoordinator.deriveWorkspaceRoots(
            routingSignal: contextSessionCoordinator.capturedRoutingSignal,
            snapshot: contextSessionCoordinator.capturedSnapshot
        )
        let shouldUsePlaceholderMentions = settingsStore.aiEnhancementEnabled &&
            settingsStore.apiEndpoint != nil &&
            settingsStore.currentAIProviderHasRequiredAPIKey()
        if let capabilities = contextSessionCoordinator.capturedAdapterCapabilities,
           capabilities.supportsFileMentions {
            let resolvedMentionFormatting = settingsStore.resolveMentionFormatting(
                editorBundleIdentifier: contextSessionCoordinator.capturedRoutingSignal?.appBundleIdentifier,
                terminalProviderIdentifier: contextSessionCoordinator.capturedRoutingSignal?.terminalProviderIdentifier,
                adapterDefaultTemplate: capabilities.mentionTemplate,
                adapterDefaultPrefix: capabilities.mentionPrefix
            )
            let effectiveCapabilities = capabilities.withMentionFormatting(
                prefix: resolvedMentionFormatting.mentionPrefix,
                template: resolvedMentionFormatting.mentionTemplate
            )
            mentionFormattingCapabilities = effectiveCapabilities
            if !derivedWorkspaceRoots.isEmpty {
                let rewriteResult: MentionRewriteResult
                if shouldUsePlaceholderMentions {
                    rewriteResult = await mentionRewriteService.rewriteToCanonicalPlaceholders(
                        text: normalizedText,
                        capabilities: effectiveCapabilities,
                        workspaceRoots: derivedWorkspaceRoots,
                        activeDocumentPath: contextSessionCoordinator.capturedSnapshot?.appContext?.documentPath
                    )
                } else {
                    rewriteResult = await mentionRewriteService.rewrite(
                        text: normalizedText,
                        capabilities: effectiveCapabilities,
                        workspaceRoots: derivedWorkspaceRoots,
                        activeDocumentPath: contextSessionCoordinator.capturedSnapshot?.appContext?.documentPath
                    )
                }
                textAfterMentions = rewriteResult.text
                if rewriteResult.didRewrite {
                    Log.app.info("Mention rewrite: \(rewriteResult.rewrittenCount) mention(s) rewritten, \(rewriteResult.preservedCount) preserved")
                }
            } else {
                let adapterName = contextSessionCoordinator.capturedAdapterCapabilities?.displayName ?? "unknown"
                let hasDocPath = contextSessionCoordinator.capturedSnapshot?.appContext?.documentPath != nil
                let debugSummary = contextSessionCoordinator.mentionRewriteWorkspaceDebugSummary(
                    adapterName: adapterName,
                    routingSignal: contextSessionCoordinator.capturedRoutingSignal,
                    snapshot: contextSessionCoordinator.capturedSnapshot,
                    derivedWorkspaceRoots: derivedWorkspaceRoots
                )
                Log.app.warning("Adapter '\(adapterName)' supports file mentions but no workspace roots derived (documentPath available: \(hasDocPath)); skipping mention rewrite. \(debugSummary)")
            }
        }

        let isTranslate = pendingTranslateTask
        pendingTranslateTask = false
        let polishOutcome = await polishTranscribedTextIfNeeded(
            textAfterMentions,
            appContext: contextSessionCoordinator.capturedSnapshot?.appContext,
            task: isTranslate ? .translate : .polish,
            outputLanguage: isTranslate ? settingsStore.translateOutputLanguage : nil
        )
        var finalText = normalizedTranscriptionText(polishOutcome.finalText)
        let originalText = polishOutcome.originalText
        let enhancedWithModel = polishOutcome.enhancedWithModel

        if polishOutcome.didAttemptPolish,
           let capabilities = mentionFormattingCapabilities,
           capabilities.supportsFileMentions,
           !derivedWorkspaceRoots.isEmpty {
            let renderedPlaceholders = mentionRewriteService.renderCanonicalPlaceholders(
                in: finalText,
                capabilities: capabilities
            )
            finalText = renderedPlaceholders.text

            if renderedPlaceholders.didRewrite {
                Log.app.info("Post-polish placeholder render: \(renderedPlaceholders.rewrittenCount) placeholder(s) rendered, \(renderedPlaceholders.preservedCount) preserved")
            } else {
                let postPolishRewriteResult = await mentionRewriteService.rewrite(
                    text: finalText,
                    capabilities: capabilities,
                    workspaceRoots: derivedWorkspaceRoots,
                    activeDocumentPath: contextSessionCoordinator.capturedSnapshot?.appContext?.documentPath
                )
                finalText = postPolishRewriteResult.text
                if postPolishRewriteResult.didRewrite {
                    Log.app.info("Post-polish mention rewrite: \(postPolishRewriteResult.rewrittenCount) mention(s) rewritten, \(postPolishRewriteResult.preservedCount) preserved")
                }
            }
        }

        finalText = normalizedTranscriptionText(finalText)
        guard !isTranscriptionEffectivelyEmpty(finalText) else {
            handleNoSpeechDetected(context: "recording")
            return
        }

        var outputSucceeded = false
        do {
            if outputManager.outputMode == .directInsert {
                onEnsureAccessibilityForDirectInsert("output", true)
            }
            let outputText = settingsStore.addTrailingSpace ? finalText + " " : finalText
            try await outputManager.output(outputText)
            outputSucceeded = true
        } catch {
            Log.app.error("Output failed: \(error)")
        }

        guard Self.shouldPersistHistory(outputSucceeded: outputSucceeded, text: finalText) else { return }

        do {
            try historyStore.save(
                text: finalText,
                originalText: originalText,
                duration: duration,
                modelUsed: settingsStore.selectedModel,
                enhancedWith: enhancedWithModel,
                diarizationSegmentsJSON: diarizationSegmentsJSON,
                polishMs: polishOutcome.polishMs,
                contextDetected: polishOutcome.contextDetected
            )
            onUpdateRecentTranscriptsMenu()
        } catch {
            Log.app.error("Failed to save to history: \(error)")
        }
    }

    // MARK: - Polish Orchestration

    func polishTranscribedTextIfNeeded(
        _ text: String,
        appContext: AppContextInfo? = nil,
        task: PolishTask = .polish,
        outputLanguage: String? = nil
    ) async -> RecordingPolishOutcome {
        guard settingsStore.aiEnhancementEnabled else {
            return RecordingPolishOutcome(
                finalText: text,
                originalText: nil,
                enhancedWithModel: nil,
                didAttemptPolish: false,
                usedFallback: false,
                polishMs: nil,
                contextDetected: nil
            )
        }

        let runtimeState = settingsStore.engineRuntimeState
        guard runtimeState.isReady else {
            toastService.show(
                ToastPayload(
                    message: engineRuntimeCoordinator.localEngineUnavailableMessage(for: runtimeState),
                    style: .error
                )
            )
            return RecordingPolishOutcome(
                finalText: text,
                originalText: text,
                enhancedWithModel: nil,
                didAttemptPolish: false,
                usedFallback: true,
                polishMs: nil,
                contextDetected: nil
            )
        }

        do {
            let result = try await polishHandlers.polish(text, appContext, task, outputLanguage)
            if result.usedFallback {
                toastService.show(
                    ToastPayload(
                        message: engineRuntimeCoordinator.polishFallbackMessage(for: result.warningMessage),
                        style: .error
                    )
                )
            }

            return RecordingPolishOutcome(
                finalText: result.text,
                originalText: result.rawTranscript,
                enhancedWithModel: result.usedFallback ? nil : (result.modelUsed ?? settingsStore.engineLLMModel),
                didAttemptPolish: true,
                usedFallback: result.usedFallback,
                polishMs: result.totalMs,
                contextDetected: result.contextDetected
            )
        } catch let error as EngineClientError {
            Log.app.error("Engine polish failed: \(error)")
            engineRuntimeCoordinator.updateEngineRuntimeState(for: error, context: "polish")
            toastService.show(
                ToastPayload(
                    message: engineRuntimeCoordinator.localEngineUnavailableMessage(for: settingsStore.engineRuntimeState),
                    style: .error
                )
            )
            return RecordingPolishOutcome(
                finalText: text,
                originalText: text,
                enhancedWithModel: nil,
                didAttemptPolish: true,
                usedFallback: true,
                polishMs: nil,
                contextDetected: nil
            )
        } catch {
            Log.app.error("Engine polish failed: \(error)")
            settingsStore.updateEngineRuntimeState(
                .error(detail: "Engine polish failed: \(error.localizedDescription)")
            )
            toastService.show(
                ToastPayload(
                    message: engineRuntimeCoordinator.localEngineUnavailableMessage(for: settingsStore.engineRuntimeState),
                    style: .error
                )
            )
            return RecordingPolishOutcome(
                finalText: text,
                originalText: text,
                enhancedWithModel: nil,
                didAttemptPolish: true,
                usedFallback: true,
                polishMs: nil,
                contextDetected: nil
            )
        }
    }

    // MARK: - Streaming Transcription

    private func beginStreamingSessionIfAvailable() async {
        let shouldUseStreaming = shouldUseStreamingTranscriptionForCurrentSession()
        guard shouldUseStreaming else {
            let reasons = [
                settingsStore.streamingFeatureEnabled ? nil : "feature-disabled",
                outputManager.outputMode == .directInsert ? nil : "output-mode-not-directInsert"
            ].compactMap { $0 }
            Log.transcription.info("Streaming transcription disabled for session: \(reasons.joined(separator: ","))")
            isStreamingTranscriptionSessionActive = false
            clearStreamingSessionBindings(cancelPendingWork: true)
            return
        }

        do {
            setStreamingTranscriptionCallbacks()
            try await transcriptionService.prepareStreamingEngine()
            try await transcriptionService.startStreaming()
            outputManager.beginStreamingInsertion()
            attachStreamingAudioForwarding()
            isStreamingTranscriptionSessionActive = true
            Log.transcription.info("Streaming transcription enabled for current session")
        } catch {
            Log.transcription.error("Streaming transcription unavailable, falling back to batch: \(error)")
            await cancelStreamingSession(preserveInsertedText: true)
        }
    }

    private func setStreamingTranscriptionCallbacks() {
        transcriptionService.setStreamingCallbacks(
            onPartial: { [weak self] text in
                Task { @MainActor in
                    self?.enqueueStreamingInsertionUpdate(text, source: "partial")
                }
            },
            onFinalUtterance: { [weak self] text in
                Task { @MainActor in
                    self?.enqueueStreamingInsertionUpdate(text, source: "final-utterance")
                }
            }
        )
    }

    private func attachStreamingAudioForwarding() {
        audioRecorder.onAudioBuffer = { [weak self] buffer in
            self?.enqueueStreamingAudioBuffer(buffer)
        }
    }

    private func enqueueStreamingAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isStreamingTranscriptionSessionActive else { return }

        let previousTask = streamingAudioProcessingTask
        streamingAudioProcessingTask = Task { @MainActor [weak self] in
            _ = await previousTask?.result
            guard let self, self.isStreamingTranscriptionSessionActive else { return }
            do {
                try await self.transcriptionService.processStreamingAudioBuffer(buffer)
            } catch {
                Log.transcription.error("Streaming audio buffer processing failed: \(error)")
            }
        }
    }

    private func enqueueStreamingInsertionUpdate(_ text: String, source: String) {
        guard isStreamingTranscriptionSessionActive else { return }

        let previousTask = streamingInsertionUpdateTask
        streamingInsertionUpdateTask = Task { @MainActor [weak self] in
            _ = await previousTask?.result
            guard let self, self.isStreamingTranscriptionSessionActive else { return }
            do {
                try await self.outputManager.updateStreamingInsertion(with: text)
                Log.transcription.debug("Applied streaming \(source) update (chars=\(text.count))")
            } catch {
                Log.output.error("Failed applying streaming \(source) update: \(error)")
            }
        }
    }

    private func flushStreamingSessionWork() async {
        if let task = streamingAudioProcessingTask {
            _ = await task.result
        }
        streamingAudioProcessingTask = nil

        if let task = streamingInsertionUpdateTask {
            _ = await task.result
        }
        streamingInsertionUpdateTask = nil
    }

    func clearStreamingSessionBindings(cancelPendingWork: Bool) {
        audioRecorder.onAudioBuffer = nil
        transcriptionService.setStreamingCallbacks(onPartial: nil, onFinalUtterance: nil)
        if cancelPendingWork {
            streamingAudioProcessingTask?.cancel()
            streamingInsertionUpdateTask?.cancel()
            streamingAudioProcessingTask = nil
            streamingInsertionUpdateTask = nil
        }
    }

    func cancelStreamingSession(preserveInsertedText: Bool) async {
        clearStreamingSessionBindings(cancelPendingWork: true)
        await transcriptionService.cancelStreaming()
        await outputManager.cancelStreamingInsertion(removeInsertedText: !preserveInsertedText)
        isStreamingTranscriptionSessionActive = false
    }

    private func stopRecordingAndFinalizeStreaming() async throws {
        guard let startTime = recordingStartTime else {
            Log.app.warning("stopRecordingAndFinalizeStreaming called but recordingStartTime is nil")
            return
        }

        isRecording = false
        mediaPauseService.endRecordingSession()
        contextSessionCoordinator.suspendLiveContextSessionUpdates()
        isProcessing = true

        onStatusBarProcessing()

        floatingIndicatorCoordinator.transitionRecordingIndicatorToProcessing()

        defer {
            resetProcessingState()
        }

        do {
            _ = try await audioRecorder.stopRecording()
        } catch {
            Log.app.error("Failed to stop recording for streaming session: \(error)")
            await cancelStreamingSession(preserveInsertedText: true)
            throw error
        }

        await flushStreamingSessionWork()
        transcriptionService.setStreamingCallbacks(onPartial: nil, onFinalUtterance: nil)

        let finalStreamedText: String
        do {
            finalStreamedText = try await transcriptionService.stopStreaming()
            Log.transcription.info("Streaming transcription finalized")
        } catch {
            Log.transcription.error("Failed to stop streaming transcription: \(error)")
            await cancelStreamingSession(preserveInsertedText: true)
            throw error
        }

        clearStreamingSessionBindings(cancelPendingWork: false)
        isStreamingTranscriptionSessionActive = false

        let normalizedText = normalizedTranscriptionText(finalStreamedText)

        guard !isTranscriptionEffectivelyEmpty(normalizedText) else {
            handleNoSpeechDetected(context: "streaming recording")
            try? await outputManager.finishStreamingInsertion(finalText: "", appendTrailingSpace: false)
            return
        }

        var outputSucceeded = false
        do {
            try await outputManager.finishStreamingInsertion(
                finalText: normalizedText,
                appendTrailingSpace: settingsStore.addTrailingSpace
            )
            outputSucceeded = true
            Log.transcription.debug("Applied final streaming transcription output")
        } catch {
            Log.output.error("Final streaming insertion failed: \(error)")
            await outputManager.cancelStreamingInsertion(removeInsertedText: false)
        }

        guard Self.shouldPersistHistory(outputSucceeded: outputSucceeded, text: normalizedText) else {
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        do {
            try historyStore.save(
                text: normalizedText,
                originalText: nil,
                duration: duration,
                modelUsed: settingsStore.selectedModel,
                enhancedWith: nil,
                diarizationSegmentsJSON: nil
            )
            onUpdateRecentTranscriptsMenu()
        } catch {
            Log.app.error("Failed to save streamed transcription to history: \(error)")
        }
    }

    // MARK: - Helpers

    private func logRecordingStartAttempt(source: RecordingTriggerSource) {
        recordingStartAttemptCounter += 1
        let snapshot = permissionManager.microphoneAuthorizationSnapshot()
        let shortVersion = Bundle.main.appShortVersionString
        let buildVersion = Bundle.main.appBuildVersionString
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
        let bundlePath = Bundle.main.bundleURL.path
        let executablePath = Bundle.main.executableURL?.path ?? "unknown"
        let cachedDecision = snapshot.cachedDecision.map { $0 ? "granted" : "denied" } ?? "none"

        Log.app.info(
            "recording_start_attempt id=\(self.recordingStartAttemptCounter) source=\(source.rawValue) resolved=\(String(describing: snapshot.resolvedStatus)) avaudio=\(snapshot.audioApplicationStatus) avcapture=\(snapshot.captureDeviceStatus) requestedThisLaunch=\(snapshot.hasRequestedThisLaunch) cachedDecision=\(cachedDecision) bundleId=\(bundleIdentifier) shortVersion=\(shortVersion) buildVersion=\(buildVersion) pid=\(ProcessInfo.processInfo.processIdentifier) onboardingCompleted=\(self.settingsStore.hasCompletedOnboarding) bundlePath=\(bundlePath) executablePath=\(executablePath)"
        )
    }

    func normalizedTranscriptionText(_ text: String) -> String {
        Self.normalizedTranscriptionText(text)
    }

    static func normalizedTranscriptionText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isTranscriptionEffectivelyEmpty(_ text: String) -> Bool {
        Self.isTranscriptionEffectivelyEmpty(text)
    }

    static func isTranscriptionEffectivelyEmpty(_ text: String) -> Bool {
        let normalizedText = normalizedTranscriptionText(text)
        if normalizedText.isEmpty {
            return true
        }
        return normalizedText.caseInsensitiveCompare("[BLANK AUDIO]") == .orderedSame
    }

    static func shouldPersistHistory(outputSucceeded: Bool, text: String) -> Bool {
        outputSucceeded && !isTranscriptionEffectivelyEmpty(text)
    }

    static func shouldUseSpeakerDiarization(
        diarizationFeatureEnabled: Bool,
        isStreamingSessionActive: Bool
    ) -> Bool {
        diarizationFeatureEnabled && !isStreamingSessionActive
    }

    static func shouldUseStreamingTranscription(
        streamingFeatureEnabled: Bool,
        outputMode: OutputMode
    ) -> Bool {
        streamingFeatureEnabled &&
            outputMode == .directInsert
    }

    func encodeDiarizationSegmentsJSON(_ segments: [DiarizedTranscriptSegment]?) -> String? {
        guard let segments, !segments.isEmpty else {
            return nil
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let encodedData = try encoder.encode(segments)
            return String(data: encodedData, encoding: .utf8)
        } catch {
            Log.app.warning("Failed to encode diarization segments for history: \(error.localizedDescription)")
            return nil
        }
    }

    private func shouldUseStreamingTranscriptionForCurrentSession() -> Bool {
        Self.shouldUseStreamingTranscription(
            streamingFeatureEnabled: settingsStore.streamingFeatureEnabled,
            outputMode: outputManager.outputMode
        )
    }

    private func handleNoSpeechDetected(context: String) {
        Log.app.info("No speech detected for \(context); skipping output")
        toastService.show(
            ToastPayload(
                message: "No speech detected. Try speaking closer to your microphone."
            )
        )
    }

    private func handleRecordingStartFailure(_ error: Error, source: RecordingTriggerSource) {
        let isHotkeySource: Bool
        switch source {
        case .hotkeyToggle, .hotkeyPushToTalk:
            isHotkeySource = true
        default:
            isHotkeySource = false
        }

        guard isHotkeySource,
              let audioError = error as? AudioRecorderError,
              case .permissionDenied = audioError else {
            return
        }

        AlertManager.shared.showMicrophonePermissionAlert()
    }
}
