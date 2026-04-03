//
//  EngineRuntimeCoordinator.swift
//  OpenTypeless
//
//  Extracted from AppCoordinator — manages Engine runtime evaluation,
//  configuration sync, and user-facing runtime messages.
//

import Foundation

@MainActor
final class EngineRuntimeCoordinator {

    // MARK: - Dependencies

    private let settingsStore: SettingsStore
    let engineStartupHandlers: EngineStartupHandlers
    private let toastService: ToastService

    // MARK: - State

    private var engineRuntimeEvaluationTask: Task<Void, Never>?

    // MARK: - Init

    init(
        settingsStore: SettingsStore,
        engineStartupHandlers: EngineStartupHandlers,
        toastService: ToastService
    ) {
        self.settingsStore = settingsStore
        self.engineStartupHandlers = engineStartupHandlers
        self.toastService = toastService
    }

    // MARK: - Public / Internal API

    func syncEngineConfigurationOnStartup() async {
        await evaluateEngineRuntime(trigger: .startup)
    }

    func scheduleEngineConfigurationSync() {
        settingsStore.updateEngineRuntimeState(
            .checking(detail: "Rechecking Engine after settings changes...")
        )

        engineRuntimeEvaluationTask?.cancel()
        engineRuntimeEvaluationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            await self.evaluateEngineRuntime(trigger: .settingsChange)
        }
    }

    func requestManualEngineRuntimeRecheck() {
        engineRuntimeEvaluationTask?.cancel()
        engineRuntimeEvaluationTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self.evaluateEngineRuntime(trigger: .manualRecheck)
        }
    }

    func evaluateEngineRuntime(trigger: EngineRuntimeEvaluationTrigger) async {
        let checkingDetail: String
        switch trigger {
        case .startup:
            checkingDetail = "Checking Engine runtime..."
        case .settingsChange:
            checkingDetail = "Rechecking Engine after settings changes..."
        case .manualRecheck:
            checkingDetail = "Rechecking Engine runtime..."
        }

        settingsStore.updateEngineRuntimeState(.checking(detail: checkingDetail))

        let healthResponse: HealthResponse
        do {
            healthResponse = try await engineStartupHandlers.health()
        } catch let error as EngineClientError {
            updateEngineRuntimeState(for: error, context: "health check")
            if error == .connectionFailed {
                Log.boot.info("Engine unavailable during \(String(describing: trigger)) health check; continuing with degraded runtime")
            } else {
                Log.boot.warning("Engine health check failed during \(String(describing: trigger)): \(error.localizedDescription)")
            }
            return
        } catch {
            let detail = "Engine health check failed: \(error.localizedDescription)"
            settingsStore.updateEngineRuntimeState(.error(detail: detail))
            Log.boot.warning(detail)
            return
        }

        switch currentEngineConfigurationReadiness() {
        case .incomplete(let missingConfiguration):
            settingsStore.updateEngineRuntimeState(
                .needsConfiguration(
                    missingConfiguration,
                    detail: missingConfigurationDetail(for: missingConfiguration)
                )
            )
            return
        case .ready(let requestBody):
            settingsStore.updateEngineRuntimeState(.syncing(version: healthResponse.version))
            do {
                _ = try await engineStartupHandlers.pushConfig(requestBody)
                settingsStore.updateEngineRuntimeState(
                    .ready(
                        version: healthResponse.version,
                        detail: readyRuntimeDetail(for: settingsStore.sttMode),
                        uptimeSeconds: healthResponse.uptimeSeconds,
                        requestsTotal: healthResponse.stats?.requestsTotal,
                        requestsFailed: healthResponse.stats?.requestsFailed
                    )
                )

                switch trigger {
                case .startup:
                    Log.boot.info("Engine config synchronized on startup")
                case .settingsChange:
                    Log.boot.info("Engine config synchronized after local settings change")
                case .manualRecheck:
                    Log.boot.info("Engine runtime recheck succeeded")
                }
            } catch let error as EngineClientError {
                updateEngineRuntimeState(
                    for: error,
                    context: "configuration sync"
                )
                Log.boot.warning("Engine config synchronization failed during \(String(describing: trigger)): \(error.localizedDescription)")
            } catch {
                let detail = "Engine configuration sync failed: \(error.localizedDescription)"
                settingsStore.updateEngineRuntimeState(.error(detail: detail))
                Log.boot.warning(detail)
            }
        }
    }

    func updateEngineRuntimeState(
        for error: EngineClientError,
        context: String
    ) {
        switch error {
        case .connectionFailed:
            settingsStore.updateEngineRuntimeState(
                .offline(
                    detail: "Engine is not reachable at \(settingsStore.engineHost):\(settingsStore.enginePort)."
                )
            )
        case .sttNotConfigured:
            settingsStore.updateEngineRuntimeState(
                .needsConfiguration(
                    .stt,
                    detail: missingConfigurationDetail(for: .stt)
                )
            )
        case .notConfigured:
            settingsStore.updateEngineRuntimeState(
                .needsConfiguration(
                    .llm,
                    detail: missingConfigurationDetail(for: .llm)
                )
            )
        case .validationError(let message),
             .llmFailure(let message),
             .sttFailure(let message):
            settingsStore.updateEngineRuntimeState(
                .error(detail: "Engine \(context) failed: \(message)")
            )
        case .apiError(_, _, let message):
            settingsStore.updateEngineRuntimeState(
                .error(detail: "Engine \(context) failed: \(message)")
            )
        case .invalidBaseURL:
            settingsStore.updateEngineRuntimeState(
                .error(detail: "Engine host or port is invalid.")
            )
        case .invalidResponse:
            settingsStore.updateEngineRuntimeState(
                .error(detail: "Engine returned an invalid response during \(context).")
            )
        }
    }

    func localEngineUnavailableMessage(for runtimeState: EngineRuntimeState) -> String {
        switch runtimeState.phase {
        case .offline:
            return "Engine is offline. Local transcription was inserted without polishing. Start Engine, then press Recheck in Settings."
        case .needsConfiguration:
            return "Engine polish is not ready. Local transcription was inserted without polishing. Finish the missing Engine setup, then press Recheck in Settings."
        case .checking, .syncing:
            return "Engine is still checking configuration. Local transcription was inserted without polishing."
        case .error:
            return "Engine needs attention. Local transcription was inserted without polishing. Fix the Engine setup, then press Recheck in Settings."
        case .ready:
            return "Text polishing failed. Transcription inserted without polishing."
        }
    }

    func remoteEngineBlockedMessage(for runtimeState: EngineRuntimeState) -> String {
        switch runtimeState.phase {
        case .offline:
            return "Engine is offline. Start Engine or switch Transcription Mode back to Local in Settings."
        case .needsConfiguration:
            return "Remote Engine transcription is not ready. Finish the missing Engine setup or switch Transcription Mode back to Local."
        case .checking, .syncing:
            return "Engine is still checking configuration. Try again in a moment or switch Transcription Mode back to Local."
        case .error:
            return "Engine needs attention before remote transcription can continue. Fix the Engine setup or switch Transcription Mode back to Local."
        case .ready:
            return "Engine transcription is not ready yet."
        }
    }

    func polishFallbackMessage(for warningMessage: String?) -> String {
        let normalizedWarning = warningMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedWarning, !normalizedWarning.isEmpty {
            return "Text polishing failed (\(normalizedWarning)). Transcription inserted without polishing."
        }

        return "Text polishing failed. Transcription inserted without polishing."
    }

    func polishFallbackMessage(for error: EngineClientError) -> String {
        switch error {
        case .connectionFailed:
            return "Engine is offline. Transcription inserted without polishing."
        case .notConfigured:
            return "Engine is not configured for polishing. Transcription inserted without polishing."
        case .llmFailure(let message):
            return polishFallbackMessage(for: message)
        default:
            return "Text polishing failed. Transcription inserted without polishing."
        }
    }

    func handleTranscriptionRuntimeFailure(_ error: TranscriptionService.TranscriptionError) {
        guard case .engineRuntimeFailure(let engineError) = error else { return }
        updateEngineRuntimeState(for: engineError, context: "transcription")
    }

    func cancelPendingEvaluation() {
        engineRuntimeEvaluationTask?.cancel()
        engineRuntimeEvaluationTask = nil
    }

    // MARK: - Private Helpers

    private func currentEngineConfigurationReadiness() -> EngineConfigurationReadiness {
        let llmConfiguration = settingsStore.currentEngineLLMProviderConfiguration()
        let sttConfiguration = settingsStore.currentEngineSTTProviderConfiguration()

        switch settingsStore.sttMode {
        case .local:
            guard let llmConfiguration else {
                return .incomplete(.llm)
            }

            return .ready(
                ConfigRequest(
                    stt: nil,
                    llm: llmConfiguration,
                    defaultLanguage: nil
                )
            )
        case .remote:
            switch (sttConfiguration, llmConfiguration) {
            case let (.some(sttConfiguration), .some(llmConfiguration)):
                return .ready(
                    ConfigRequest(
                        stt: sttConfiguration,
                        llm: llmConfiguration,
                        defaultLanguage: nil
                    )
                )
            case (.none, .none):
                return .incomplete(.sttAndLLM)
            case (.none, .some):
                return .incomplete(.stt)
            case (.some, .none):
                return .incomplete(.llm)
            }
        }
    }

    private func readyRuntimeDetail(for mode: STTMode) -> String {
        switch mode {
        case .local:
            return "Engine is ready for local dictation with text polishing."
        case .remote:
            return "Engine is ready for remote transcription and text polishing."
        }
    }

    private func missingConfigurationDetail(
        for missingConfiguration: EngineRuntimeState.MissingConfiguration
    ) -> String {
        switch (settingsStore.sttMode, missingConfiguration) {
        case (.local, _):
            return "Add an LLM provider base URL, model, and API key to enable Engine polish."
        case (.remote, .llm):
            return "Add an LLM provider base URL, model, and API key before using remote Engine transcription."
        case (.remote, .stt):
            return "Add a Remote STT provider base URL, model, and API key before using Engine transcription."
        case (.remote, .sttAndLLM):
            return "Add both Remote STT and LLM provider settings before using Engine transcription."
        }
    }
}
