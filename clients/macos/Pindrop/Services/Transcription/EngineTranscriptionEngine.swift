//
//  EngineTranscriptionEngine.swift
//  Pindrop
//
//  Created on 2026-03-29.
//

import Foundation

@MainActor
final class EngineTranscriptionEngine: TranscriptionEngine {
    enum EngineError: Error, LocalizedError, Equatable {
        case modelNotLoaded
        case invalidAudioData

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "Engine transcription is not ready"
            case .invalidAudioData:
                return "Invalid audio data"
            }
        }
    }

    private let client: EngineClient

    private(set) var state: TranscriptionEngineState = .unloaded
    private(set) var error: Error?

    init(client: EngineClient = EngineClient()) {
        self.client = client
    }

    func loadModel(path: String) async throws {
        state = .loading
        error = nil
        state = .ready
    }

    func loadModel(name: String, downloadBase: URL?) async throws {
        state = .loading
        error = nil
        state = .ready
    }

    func transcribe(audioData: Data, options: TranscriptionOptions) async throws -> String {
        guard state == .ready else {
            throw EngineError.modelNotLoaded
        }

        guard !audioData.isEmpty else {
            throw EngineError.invalidAudioData
        }

        state = .transcribing

        do {
            let response = try await client.transcribe(
                audioData: audioData,
                language: options.language.whisperLanguageCode
            )
            state = .ready
            return response.text
        } catch {
            self.error = error
            state = .ready
            throw error
        }
    }

    func unloadModel() async {
        error = nil
        state = .unloaded
    }
}
