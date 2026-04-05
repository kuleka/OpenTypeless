//
//  PolishService.swift
//  OpenTypeless
//
//  Created on 2026-03-29.
//

import Foundation

@MainActor
final class PolishService {
    struct PolishResult: Equatable {
        let text: String
        let rawTranscript: String
        let task: PolishTask
        let contextDetected: String?
        let modelUsed: String?
        let usedFallback: Bool
        let warningMessage: String?
        var llmMs: Int? = nil
        var totalMs: Int? = nil
    }

    enum PolishError: Error, LocalizedError, Equatable {
        case outputLanguageRequired

        var errorDescription: String? {
            switch self {
            case .outputLanguageRequired:
                return "output_language is required when task is translate"
            }
        }
    }

    private let client: EngineClient

    init(client: EngineClient = EngineClient()) {
        self.client = client
    }

    func polish(
        text: String,
        appContext: AppContextInfo? = nil,
        task: PolishTask = .polish,
        outputLanguage: String? = nil
    ) async throws -> PolishResult {
        guard !text.isEmpty else {
            return PolishResult(
                text: text,
                rawTranscript: text,
                task: task,
                contextDetected: nil,
                modelUsed: nil,
                usedFallback: false,
                warningMessage: nil,
                llmMs: nil,
                totalMs: nil
            )
        }

        let normalizedOutputLanguage = trimmedValue(outputLanguage)
        if task == .translate && normalizedOutputLanguage == nil {
            throw PolishError.outputLanguageRequired
        }

        let request = PolishRequest(
            text: text,
            context: makeContext(from: appContext),
            options: makeOptions(task: task, outputLanguage: normalizedOutputLanguage)
        )

        do {
            let response = try await client.polish(request)
            return PolishResult(
                text: response.text,
                rawTranscript: response.rawTranscript,
                task: PolishTask(rawValue: response.task) ?? task,
                contextDetected: trimmedValue(response.contextDetected),
                modelUsed: trimmedValue(response.modelUsed),
                usedFallback: false,
                warningMessage: nil,
                llmMs: response.llmMs,
                totalMs: response.totalMs
            )
        } catch let error as EngineClientError {
            switch error {
            case .llmFailure(let message):
                return PolishResult(
                    text: text,
                    rawTranscript: text,
                    task: task,
                    contextDetected: nil,
                    modelUsed: nil,
                    usedFallback: true,
                    warningMessage: message,
                    llmMs: nil,
                    totalMs: nil
                )
            default:
                throw error
            }
        }
    }

    private func makeContext(from appContext: AppContextInfo?) -> PolishContext? {
        guard let appContext else {
            return nil
        }

        let appId = trimmedValue(appContext.bundleIdentifier)
        let windowTitle = trimmedValue(appContext.windowTitle)

        guard appId != nil || windowTitle != nil else {
            return nil
        }

        return PolishContext(appId: appId, windowTitle: windowTitle)
    }

    private func makeOptions(
        task: PolishTask,
        outputLanguage: String?
    ) -> PolishOptions? {
        guard task != .polish || outputLanguage != nil else {
            return nil
        }

        return PolishOptions(
            task: task,
            language: nil,
            model: nil,
            outputLanguage: outputLanguage
        )
    }

    private func trimmedValue(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }
}
