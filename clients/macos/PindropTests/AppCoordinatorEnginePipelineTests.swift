//
//  AppCoordinatorEnginePipelineTests.swift
//  PindropTests
//
//  Created on 2026-03-29.
//

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

@MainActor
@Suite(.serialized)
struct AppCoordinatorEnginePipelineTests {
    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            TranscriptionRecord.self,
            WordReplacement.self,
            VocabularyWord.self,
            Note.self,
            PromptPreset.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeCoordinator(
        engineStartupHandlers: AppCoordinator.EngineStartupHandlers? = nil,
        polishHandlers: AppCoordinator.PolishHandlers? = nil,
        toastPresenter: RecordingToastPresenter? = nil
    ) throws -> AppCoordinator {
        let modelContainer = try makeModelContainer()
        let coordinator = AppCoordinator(
            modelContext: modelContainer.mainContext,
            modelContainer: modelContainer,
            enableSystemHooks: false,
            engineStartupHandlers: engineStartupHandlers,
            polishHandlers: polishHandlers,
            toastPresenter: toastPresenter
        )
        coordinator.settingsStore.resetAllSettings()
        return coordinator
    }

    @Test func startupSyncPushesLLMConfigAndPreservesExistingSTTConfig() async throws {
        let mockEngineClient = MockEngineStartupClient()
        mockEngineClient.fetchConfigResponse = ConfigResponse(
            configured: true,
            stt: ProviderConfiguration(
                apiBase: "https://api.groq.com/openai/v1",
                apiKey: "gsk_****1234",
                model: "whisper-large-v3"
            ),
            llm: nil,
            defaultLanguage: "auto"
        )

        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )

        try coordinator.settingsStore.saveAPIEndpoint("https://openrouter.ai/api/v1")
        try coordinator.settingsStore.saveAPIKey("sk-or-test", for: .openrouter)
        coordinator.settingsStore.aiModel = "openai/gpt-4o-mini"
        coordinator.settingsStore.selectedAppLanguage = .english

        await coordinator.syncEngineConfigurationOnStartup()

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.fetchConfigCallCount == 1)
        #expect(mockEngineClient.pushConfigCallCount == 1)
        #expect(mockEngineClient.lastPushedConfig?.stt?.model == "whisper-large-v3")
        #expect(mockEngineClient.lastPushedConfig?.llm?.apiBase == "https://openrouter.ai/api/v1")
        #expect(mockEngineClient.lastPushedConfig?.llm?.apiKey == "sk-or-test")
        #expect(mockEngineClient.lastPushedConfig?.llm?.model == "openai/gpt-4o-mini")
        #expect(mockEngineClient.lastPushedConfig?.defaultLanguage == "en")

        coordinator.cleanup()
    }

    @Test func startupSyncStopsAfterHealthFailure() async throws {
        let mockEngineClient = MockEngineStartupClient()
        mockEngineClient.healthError = EngineClientError.connectionFailed

        let coordinator = try makeCoordinator(
            engineStartupHandlers: mockEngineClient.handlers()
        )

        await coordinator.syncEngineConfigurationOnStartup()

        #expect(mockEngineClient.healthCallCount == 1)
        #expect(mockEngineClient.fetchConfigCallCount == 0)
        #expect(mockEngineClient.pushConfigCallCount == 0)

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
        #expect(presenter.shownPayloads.first?.message == "Engine is offline. Transcription inserted without polishing.")
        #expect(presenter.shownPayloads.first?.style == .error)

        coordinator.cleanup()
    }
}
