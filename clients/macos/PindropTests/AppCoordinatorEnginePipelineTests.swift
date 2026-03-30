//
//  AppCoordinatorEnginePipelineTests.swift
//  PindropTests
//
//  Created on 2026-03-29.
//

import AppKit
import AVFoundation
import Foundation
import SwiftData
import Testing

@testable import Pindrop

@MainActor
private final class RecordingToastPresenter: ToastPresenting {
    private(set) var shownPayloads: [ToastPayload] = []

    func show(
        payload: ToastPayload,
        onAction: @escaping (UUID) -> Void,
        onHoverChange: @escaping (Bool) -> Void
    ) {
        shownPayloads.append(payload)
    }

    func hide() {}
}

@MainActor
private final class MockEngineStartupClient {
    var healthError: Error?
    var fetchConfigError: Error?
    var pushConfigError: Error?
    var fetchConfigResponse = ConfigResponse(
        configured: false,
        stt: nil,
        llm: nil,
        defaultLanguage: "auto"
    )

    private(set) var healthCallCount = 0
    private(set) var fetchConfigCallCount = 0
    private(set) var pushConfigCallCount = 0
    private(set) var lastPushedConfig: ConfigRequest?

    func handlers() -> AppCoordinator.EngineStartupHandlers {
        AppCoordinator.EngineStartupHandlers(
            health: { [weak self] in
                guard let self else {
                    throw EngineClientError.connectionFailed
                }
                self.healthCallCount += 1
                if let healthError = self.healthError {
                    throw healthError
                }
                return HealthResponse(status: "ok", version: "1.4.0-draft")
            },
            fetchConfig: { [weak self] in
                guard let self else {
                    throw EngineClientError.connectionFailed
                }
                self.fetchConfigCallCount += 1
                if let fetchConfigError = self.fetchConfigError {
                    throw fetchConfigError
                }
                return self.fetchConfigResponse
            },
            pushConfig: { [weak self] requestBody in
                guard let self else {
                    throw EngineClientError.connectionFailed
                }
                self.pushConfigCallCount += 1
                self.lastPushedConfig = requestBody
                if let pushConfigError = self.pushConfigError {
                    throw pushConfigError
                }
                return ConfigStatusResponse(status: "configured")
            }
        )
    }
}

private final class PipelineClipboard: ClipboardProtocol {
    private(set) var copiedHistory: [String] = []
    private(set) var restoreCount = 0
    var clipboardContent: String?
    var changeCount = 0

    func copyToClipboard(_ text: String) -> Bool {
        copiedHistory.append(text)
        clipboardContent = text
        changeCount += 1
        return true
    }

    func captureSnapshot() -> ClipboardSnapshot {
        guard let clipboardContent else {
            return ClipboardSnapshot(items: [], changeCount: changeCount)
        }

        let data = Data(clipboardContent.utf8)
        return ClipboardSnapshot(
            items: [[NSPasteboard.PasteboardType.string.rawValue: data]],
            changeCount: changeCount
        )
    }

    func currentChangeCount() -> Int {
        changeCount
    }

    func currentStringContent() -> String? {
        clipboardContent
    }

    func restoreSnapshot(_ snapshot: ClipboardSnapshot) -> Bool {
        restoreCount += 1
        changeCount += 1

        guard let firstItem = snapshot.items.first,
              let data = firstItem[NSPasteboard.PasteboardType.string.rawValue] else {
            clipboardContent = nil
            return true
        }

        clipboardContent = String(data: data, encoding: .utf8)
        return true
    }
}

private final class PipelineKeySimulation: KeySimulationProtocol {
    private(set) var pasteSimulated = false
    private(set) var simulatePasteCallCount = 0

    func postKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags, keyDown: Bool) throws {}

    func simulatePaste() async throws {
        pasteSimulated = true
        simulatePasteCallCount += 1
    }
}

@MainActor
private final class MockPipelineTranscriptionEngine: TranscriptionEngine {
    private(set) var state: TranscriptionEngineState = .unloaded
    private(set) var transcribeCallCount = 0
    var nextTranscript = ""
    var nextError: Error?

    func loadModel(path: String) async throws {
        state = .ready
    }

    func loadModel(name: String, downloadBase: URL?) async throws {
        state = .ready
    }

    func transcribe(audioData: Data, options: TranscriptionOptions) async throws -> String {
        transcribeCallCount += 1
        if let nextError {
            throw nextError
        }
        return nextTranscript
    }

    func unloadModel() async {
        state = .unloaded
    }
}

@MainActor
private final class NoOpSpeakerDiarizer: SpeakerDiarizer {
    private(set) var state: SpeakerDiarizerState = .unloaded
    let mode: DiarizationMode = .offline

    func loadModels() async throws {
        state = .ready
    }

    func unloadModels() async {
        state = .unloaded
    }

    func diarize(samples: [Float], sampleRate: Int) async throws -> DiarizationResult {
        DiarizationResult(segments: [], speakers: [], audioDuration: 0)
    }

    func compareSpeakers(audio1: [Float], audio2: [Float]) async throws -> Float {
        0.0
    }

    func registerKnownSpeaker(_ speaker: Speaker) async throws {}

    func clearKnownSpeakers() async {}
}

@MainActor
private final class NoOpStreamingTranscriptionEngine: StreamingTranscriptionEngine {
    private(set) var state: StreamingTranscriptionState = .unloaded

    func loadModel(name: String) async throws {
        state = .ready
    }

    func unloadModel() async {
        state = .unloaded
    }

    func startStreaming() async throws {
        state = .streaming
    }

    func stopStreaming() async throws -> String {
        state = .ready
        return ""
    }

    func pauseStreaming() async {
        state = .paused
    }

    func resumeStreaming() async throws {
        state = .streaming
    }

    func processAudioChunk(_ samples: [Float]) async throws {}

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async throws {}

    func setTranscriptionCallback(_ callback: @escaping StreamingTranscriptionCallback) {}

    func setEndOfUtteranceCallback(_ callback: @escaping EndOfUtteranceCallback) {}

    func reset() async {
        state = .ready
    }
}

@MainActor
@Suite(.serialized)
struct AppCoordinatorEnginePipelineTests {
    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            TranscriptionRecord.self,
            WordReplacement.self,
            VocabularyWord.self,
            PromptPreset.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeCoordinator(
        transcriptionService: TranscriptionService? = nil,
        outputManager: OutputManager? = nil,
        engineStartupHandlers: AppCoordinator.EngineStartupHandlers? = nil,
        polishHandlers: AppCoordinator.PolishHandlers? = nil,
        toastPresenter: RecordingToastPresenter? = nil
    ) throws -> AppCoordinator {
        let modelContainer = try makeModelContainer()
        let coordinator = AppCoordinator(
            modelContext: modelContainer.mainContext,
            modelContainer: modelContainer,
            enableSystemHooks: false,
            transcriptionService: transcriptionService,
            outputManager: outputManager,
            engineStartupHandlers: engineStartupHandlers,
            polishHandlers: polishHandlers,
            toastPresenter: toastPresenter
        )
        coordinator.settingsStore.resetAllSettings()
        return coordinator
    }

    private func makeTranscriptionService(
        mode: STTMode,
        localEngine: MockPipelineTranscriptionEngine? = nil,
        remoteEngine: MockPipelineTranscriptionEngine? = nil
    ) -> TranscriptionService {
        let localEngine = localEngine ?? MockPipelineTranscriptionEngine()
        let remoteEngine = remoteEngine ?? MockPipelineTranscriptionEngine()
        return TranscriptionService(
            engineFactory: { _ in localEngine },
            diarizerFactory: { NoOpSpeakerDiarizer() },
            streamingEngineFactory: { NoOpStreamingTranscriptionEngine() },
            sttModeProvider: { mode },
            remoteEngineFactory: { remoteEngine }
        )
    }

    private func makePastingOutputManager() -> (
        outputManager: OutputManager,
        clipboard: PipelineClipboard,
        keySimulation: PipelineKeySimulation
    ) {
        let clipboard = PipelineClipboard()
        clipboard.clipboardContent = "previous clipboard"
        let keySimulation = PipelineKeySimulation()
        let outputManager = OutputManager(
            outputMode: .clipboard,
            clipboard: clipboard,
            keySimulation: keySimulation,
            accessibilityPermissionChecker: { true },
            frontmostApplicationProvider: { nil }
        )
        return (outputManager, clipboard, keySimulation)
    }

    private func makeFloatAudioData(seconds: TimeInterval, sampleRate: Int = 16_000) -> Data {
        let frameCount = max(1, Int(seconds * TimeInterval(sampleRate)))
        let samples = Array(repeating: Float(0.1), count: frameCount)
        return samples.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }
    }

    @Test func startupSyncPushesCurrentEngineProviderConfiguration() async throws {
        let mockEngineClient = MockEngineStartupClient()

        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )

        coordinator.settingsStore.selectedEngineSTTProvider = .groq
        coordinator.settingsStore.engineSTTAPIBase = "https://api.groq.com/openai/v1"
        coordinator.settingsStore.engineSTTModel = "whisper-large-v3"
        try coordinator.settingsStore.saveEngineSTTAPIKey("gsk-test-stt")
        coordinator.settingsStore.selectedEngineLLMProvider = .openRouter
        coordinator.settingsStore.engineLLMAPIBase = "https://openrouter.ai/api/v1"
        coordinator.settingsStore.engineLLMModel = "openai/gpt-4o-mini"
        try coordinator.settingsStore.saveEngineLLMAPIKey("sk-or-test")
        coordinator.settingsStore.selectedAppLanguage = .english

        await coordinator.syncEngineConfigurationOnStartup()

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.fetchConfigCallCount == 0)
        #expect(mockEngineClient.pushConfigCallCount == 1)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .ready)
        #expect(coordinator.settingsStore.engineRuntimeState.version == "1.4.0-draft")
        #expect(mockEngineClient.lastPushedConfig?.stt == nil)
        #expect(mockEngineClient.lastPushedConfig?.llm?.apiBase == "https://openrouter.ai/api/v1")
        #expect(mockEngineClient.lastPushedConfig?.llm?.apiKey == "sk-or-test")
        #expect(mockEngineClient.lastPushedConfig?.llm?.model == "openai/gpt-4o-mini")
        #expect(mockEngineClient.lastPushedConfig?.defaultLanguage == "en")

        coordinator.cleanup()
    }

    @Test func settingsChangePushesUpdatedEngineConfig() async throws {
        let mockEngineClient = MockEngineStartupClient()
        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )

        coordinator.settingsStore.engineLLMAPIBase = "https://openrouter.ai/api/v1"
        coordinator.settingsStore.engineLLMModel = "openai/gpt-4o-mini"
        try coordinator.settingsStore.saveEngineLLMAPIKey("sk-or-live")
        coordinator.settingsStore.engineSTTAPIBase = "https://api.groq.com/openai/v1"
        coordinator.settingsStore.engineSTTModel = "whisper-large-v3"
        try coordinator.settingsStore.saveEngineSTTAPIKey("gsk-live")

        try await Task.sleep(for: .milliseconds(700))

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.pushConfigCallCount == 1)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .ready)
        #expect(mockEngineClient.lastPushedConfig?.llm?.apiKey == "sk-or-live")
        #expect(mockEngineClient.lastPushedConfig?.stt == nil)

        coordinator.cleanup()
    }

    @Test func settingsChangeSkipsConfigPushWhenEngineIsOffline() async throws {
        let mockEngineClient = MockEngineStartupClient()
        mockEngineClient.healthError = EngineClientError.connectionFailed
        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )

        coordinator.settingsStore.engineLLMAPIBase = "https://openrouter.ai/api/v1"
        coordinator.settingsStore.engineLLMModel = "openai/gpt-4o-mini"
        try coordinator.settingsStore.saveEngineLLMAPIKey("sk-or-offline")
        coordinator.settingsStore.engineSTTAPIBase = "https://api.groq.com/openai/v1"
        coordinator.settingsStore.engineSTTModel = "whisper-large-v3"
        try coordinator.settingsStore.saveEngineSTTAPIKey("gsk-offline")

        try await Task.sleep(for: .milliseconds(700))

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.pushConfigCallCount == 0)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .offline)

        coordinator.cleanup()
    }

    @Test func startupSyncStopsAfterHealthFailure() async throws {
        let mockEngineClient = MockEngineStartupClient()
        mockEngineClient.healthError = EngineClientError.connectionFailed

        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )
        coordinator.settingsStore.engineLLMAPIBase = "https://openrouter.ai/api/v1"
        coordinator.settingsStore.engineLLMModel = "openai/gpt-4o-mini"
        try coordinator.settingsStore.saveEngineLLMAPIKey("sk-or-test")

        await coordinator.syncEngineConfigurationOnStartup()

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.fetchConfigCallCount == 0)
        #expect(mockEngineClient.pushConfigCallCount == 0)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .offline)

        coordinator.cleanup()
    }

    @Test func startupSyncMarksRemoteModeAsSetupNeededWhenSTTConfigIsMissing() async throws {
        let mockEngineClient = MockEngineStartupClient()
        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )
        coordinator.settingsStore.sttMode = .remote
        coordinator.settingsStore.engineLLMAPIBase = "https://openrouter.ai/api/v1"
        coordinator.settingsStore.engineLLMModel = "openai/gpt-4o-mini"
        try coordinator.settingsStore.saveEngineLLMAPIKey("sk-or-test")

        await coordinator.syncEngineConfigurationOnStartup()

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.pushConfigCallCount == 0)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .needsConfiguration)
        #expect(coordinator.settingsStore.engineRuntimeState.missingConfiguration == .stt)

        coordinator.cleanup()
    }

    @Test func manualEngineRuntimeRecheckUsesCurrentSettings() async throws {
        let mockEngineClient = MockEngineStartupClient()
        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )
        coordinator.settingsStore.engineLLMAPIBase = "https://openrouter.ai/api/v1"
        coordinator.settingsStore.engineLLMModel = "openai/gpt-4o-mini"
        try coordinator.settingsStore.saveEngineLLMAPIKey("sk-or-test")

        coordinator.settingsStore.requestEngineRuntimeRecheck()
        try await Task.sleep(for: .milliseconds(150))

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.pushConfigCallCount == 1)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .ready)

        coordinator.cleanup()
    }

    @Test func polishUsesProvidedAppContextAndEngineResult() async throws {
        let presenter = RecordingToastPresenter()
        var receivedText: String?
        var receivedAppContext: AppContextInfo?
        let expectedContext = AppContextInfo(
            bundleIdentifier: "com.apple.mail",
            appName: "Mail",
            windowTitle: "Draft",
            focusedElementRole: nil,
            focusedElementValue: nil,
            selectedText: nil,
            documentPath: nil,
            browserURL: nil
        )

        let coordinator = try makeCoordinator(
            polishHandlers: AppCoordinator.PolishHandlers(
                polish: { text, appContext, _, _ in
                    receivedText = text
                    receivedAppContext = appContext
                    return PolishService.PolishResult(
                        text: "Polished email copy",
                        rawTranscript: text,
                        task: .polish,
                        contextDetected: "email",
                        modelUsed: "openai/gpt-4o-mini",
                        usedFallback: false,
                        warningMessage: nil
                    )
                }
            ),
            toastPresenter: presenter
        )
        coordinator.settingsStore.aiEnhancementEnabled = true
        coordinator.settingsStore.updateEngineRuntimeState(
            .ready(version: "1.4.0-draft", detail: "Engine is ready for local dictation with text polishing.")
        )

        let result = await coordinator.polishTranscribedTextIfNeeded(
            "draft this follow-up",
            appContext: expectedContext
        )

        #expect(receivedText == "draft this follow-up")
        #expect(receivedAppContext?.bundleIdentifier == "com.apple.mail")
        #expect(receivedAppContext?.windowTitle == "Draft")
        #expect(result.finalText == "Polished email copy")
        #expect(result.originalText == "draft this follow-up")
        #expect(result.enhancedWithModel == "openai/gpt-4o-mini")
        #expect(result.didAttemptPolish)
        #expect(result.usedFallback == false)
        #expect(presenter.shownPayloads.isEmpty)

        coordinator.cleanup()
    }

    @Test func polishFallsBackAndShowsToastWhenEngineIsOffline() async throws {
        let presenter = RecordingToastPresenter()
        let coordinator = try makeCoordinator(
            polishHandlers: AppCoordinator.PolishHandlers(
                polish: { _, _, _, _ in
                    throw EngineClientError.connectionFailed
                }
            ),
            toastPresenter: presenter
        )
        coordinator.settingsStore.aiEnhancementEnabled = true
        coordinator.settingsStore.updateEngineRuntimeState(
            .ready(version: "1.4.0-draft", detail: "Engine is ready for local dictation with text polishing.")
        )

        let result = await coordinator.polishTranscribedTextIfNeeded(
            "leave this raw",
            appContext: nil
        )

        #expect(result.finalText == "leave this raw")
        #expect(result.originalText == "leave this raw")
        #expect(result.enhancedWithModel == nil)
        #expect(result.didAttemptPolish)
        #expect(result.usedFallback)
        #expect(presenter.shownPayloads.count == 1)
        #expect(presenter.shownPayloads.first?.message == "Engine is offline. Local transcription was inserted without polishing. Start Engine, then press Recheck in Settings.")
        #expect(presenter.shownPayloads.first?.style == .error)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .offline)

        coordinator.cleanup()
    }

    @Test func localSTTPipelineOutputsPolishedTextAndPersistsHistory() async throws {
        let presenter = RecordingToastPresenter()
        let localEngine = MockPipelineTranscriptionEngine()
        localEngine.nextTranscript = "doctor smith follow up"
        let transcriptionService = makeTranscriptionService(
            mode: .local,
            localEngine: localEngine
        )
        try await transcriptionService.loadModel(modelName: "tiny", provider: .whisperKit)

        let outputFixture = makePastingOutputManager()
        let coordinator = try makeCoordinator(
            transcriptionService: transcriptionService,
            outputManager: outputFixture.outputManager,
            polishHandlers: AppCoordinator.PolishHandlers(
                polish: { text, _, _, _ in
                    return PolishService.PolishResult(
                        text: "Dr. Smith, please follow up.",
                        rawTranscript: text,
                        task: .polish,
                        contextDetected: "email",
                        modelUsed: "openai/gpt-4o-mini",
                        usedFallback: false,
                        warningMessage: nil
                    )
                }
            ),
            toastPresenter: presenter
        )

        coordinator.settingsStore.aiEnhancementEnabled = true
        coordinator.settingsStore.updateEngineRuntimeState(
            .ready(version: "1.4.0-draft", detail: "Engine is ready for local dictation with text polishing.")
        )
        try coordinator.dictionaryStore.add(
            WordReplacement(originals: ["doctor"], replacement: "Dr.", sortOrder: 0)
        )

        try await coordinator.processRecordedAudioData(
            makeFloatAudioData(seconds: 1.0),
            duration: 1.25
        )

        #expect(localEngine.transcribeCallCount == 1)
        #expect(outputFixture.keySimulation.pasteSimulated)
        #expect(outputFixture.keySimulation.simulatePasteCallCount == 1)
        #expect(outputFixture.clipboard.copiedHistory.last == "Dr. Smith, please follow up. ")
        #expect(outputFixture.clipboard.restoreCount == 1)
        #expect(presenter.shownPayloads.isEmpty)

        let records = try coordinator.historyStore.fetch(limit: 1)
        #expect(records.count == 1)
        #expect(records.first?.text == "Dr. Smith, please follow up.")
        #expect(records.first?.originalText == "Dr. smith follow up")
        #expect(records.first?.enhancedWith == "openai/gpt-4o-mini")

        coordinator.cleanup()
    }

    @Test func remoteSTTPipelineOutputsPolishedTextAndPersistsHistory() async throws {
        let presenter = RecordingToastPresenter()
        let remoteEngine = MockPipelineTranscriptionEngine()
        remoteEngine.nextTranscript = "send the contract draft today"
        let transcriptionService = makeTranscriptionService(
            mode: .remote,
            remoteEngine: remoteEngine
        )
        try await transcriptionService.loadModel(modelName: "tiny", provider: .whisperKit)

        let outputFixture = makePastingOutputManager()
        let coordinator = try makeCoordinator(
            transcriptionService: transcriptionService,
            outputManager: outputFixture.outputManager,
            polishHandlers: AppCoordinator.PolishHandlers(
                polish: { text, _, _, _ in
                    return PolishService.PolishResult(
                        text: "Please send the contract draft today.",
                        rawTranscript: text,
                        task: .polish,
                        contextDetected: "default",
                        modelUsed: "openai/gpt-4o-mini",
                        usedFallback: false,
                        warningMessage: nil
                    )
                }
            ),
            toastPresenter: presenter
        )

        coordinator.settingsStore.aiEnhancementEnabled = true
        coordinator.settingsStore.updateEngineRuntimeState(
            .ready(version: "1.4.0-draft", detail: "Engine is ready for remote transcription and text polishing.")
        )

        try await coordinator.processRecordedAudioData(
            makeFloatAudioData(seconds: 1.0),
            duration: 2.0
        )

        #expect(remoteEngine.transcribeCallCount == 1)
        #expect(outputFixture.keySimulation.pasteSimulated)
        #expect(outputFixture.keySimulation.simulatePasteCallCount == 1)
        #expect(outputFixture.clipboard.copiedHistory.last == "Please send the contract draft today. ")
        #expect(outputFixture.clipboard.restoreCount == 1)
        #expect(presenter.shownPayloads.isEmpty)

        let records = try coordinator.historyStore.fetch(limit: 1)
        #expect(records.count == 1)
        #expect(records.first?.text == "Please send the contract draft today.")
        #expect(records.first?.originalText == "send the contract draft today")
        #expect(records.first?.enhancedWith == "openai/gpt-4o-mini")

        coordinator.cleanup()
    }

    @Test func offlinePolishFallsBackToRawTranscriptAndStillOutputs() async throws {
        let presenter = RecordingToastPresenter()
        let localEngine = MockPipelineTranscriptionEngine()
        localEngine.nextTranscript = "send update tomorrow"
        let transcriptionService = makeTranscriptionService(
            mode: .local,
            localEngine: localEngine
        )
        try await transcriptionService.loadModel(modelName: "tiny", provider: .whisperKit)

        let outputFixture = makePastingOutputManager()
        let coordinator = try makeCoordinator(
            transcriptionService: transcriptionService,
            outputManager: outputFixture.outputManager,
            polishHandlers: AppCoordinator.PolishHandlers(
                polish: { _, _, _, _ in
                    throw EngineClientError.connectionFailed
                }
            ),
            toastPresenter: presenter
        )

        coordinator.settingsStore.aiEnhancementEnabled = true
        coordinator.settingsStore.updateEngineRuntimeState(
            .ready(version: "1.4.0-draft", detail: "Engine is ready for local dictation with text polishing.")
        )

        try await coordinator.processRecordedAudioData(
            makeFloatAudioData(seconds: 1.0),
            duration: 1.5
        )

        #expect(localEngine.transcribeCallCount == 1)
        #expect(outputFixture.keySimulation.pasteSimulated)
        #expect(outputFixture.clipboard.copiedHistory.last == "send update tomorrow ")
        #expect(outputFixture.clipboard.restoreCount == 1)
        #expect(presenter.shownPayloads.count == 1)
        #expect(presenter.shownPayloads.first?.message == "Engine is offline. Local transcription was inserted without polishing. Start Engine, then press Recheck in Settings.")
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .offline)

        let records = try coordinator.historyStore.fetch(limit: 1)
        #expect(records.count == 1)
        #expect(records.first?.text == "send update tomorrow")
        #expect(records.first?.originalText == "send update tomorrow")
        #expect(records.first?.enhancedWith == nil)

        coordinator.cleanup()
    }

    @Test func remoteSTTPipelineStopsEarlyWhenRuntimeIsNotReady() async throws {
        let presenter = RecordingToastPresenter()
        let remoteEngine = MockPipelineTranscriptionEngine()
        let transcriptionService = makeTranscriptionService(
            mode: .remote,
            remoteEngine: remoteEngine
        )
        try await transcriptionService.loadModel(modelName: "tiny", provider: .whisperKit)
        let outputFixture = makePastingOutputManager()
        let coordinator = try makeCoordinator(
            transcriptionService: transcriptionService,
            outputManager: outputFixture.outputManager,
            toastPresenter: presenter
        )
        coordinator.settingsStore.sttMode = .remote
        coordinator.settingsStore.updateEngineRuntimeState(
            .offline(detail: "Engine is not reachable at 127.0.0.1:19823.")
        )

        try await coordinator.processRecordedAudioData(
            makeFloatAudioData(seconds: 1.0),
            duration: 1.0
        )

        #expect(remoteEngine.transcribeCallCount == 0)
        #expect(outputFixture.keySimulation.pasteSimulated == false)
        #expect(outputFixture.clipboard.copiedHistory.isEmpty)
        #expect(presenter.shownPayloads.first?.message == "Engine is offline. Start Engine or switch Transcription Mode back to Local in Settings.")

        coordinator.cleanup()
    }

    @Test func remoteSTTEngineFailureTransitionsRuntimeStateBackToOffline() async throws {
        let presenter = RecordingToastPresenter()
        let remoteEngine = MockPipelineTranscriptionEngine()
        remoteEngine.nextError = EngineClientError.connectionFailed
        let transcriptionService = makeTranscriptionService(
            mode: .remote,
            remoteEngine: remoteEngine
        )
        try await transcriptionService.loadModel(modelName: "tiny", provider: .whisperKit)
        let coordinator = try makeCoordinator(
            transcriptionService: transcriptionService,
            toastPresenter: presenter
        )
        coordinator.settingsStore.sttMode = .remote
        coordinator.settingsStore.updateEngineRuntimeState(
            .ready(version: "1.4.0-draft", detail: "Engine is ready for remote transcription and text polishing.")
        )

        await #expect(throws: TranscriptionService.TranscriptionError.self) {
            try await coordinator.processRecordedAudioData(
                makeFloatAudioData(seconds: 1.0),
                duration: 1.0
            )
        }

        #expect(remoteEngine.transcribeCallCount == 1)
        #expect(coordinator.settingsStore.engineRuntimeState.phase == .offline)

        coordinator.cleanup()
    }
}
