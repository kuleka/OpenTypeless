//
//  TranscriptionEngineTests.swift
//  PindropTests
//
//  Created on 2026-01-30.
//

import Foundation
import Testing
@testable import Pindrop

@MainActor
@Suite
struct TranscriptionEngineTests {
    @Test func transcriptionEngineStateEquatable() {
        #expect(TranscriptionEngineState.unloaded == .unloaded)
        #expect(TranscriptionEngineState.loading == .loading)
        #expect(TranscriptionEngineState.ready == .ready)
        #expect(TranscriptionEngineState.transcribing == .transcribing)
        #expect(TranscriptionEngineState.error == .error)

        #expect(TranscriptionEngineState.unloaded != .loading)
        #expect(TranscriptionEngineState.ready != .transcribing)
    }

    @Test func transcriptionEngineStateCases() {
        let states: [TranscriptionEngineState] = [.unloaded, .loading, .ready, .transcribing, .error]
        #expect(states.count == 5)
    }

    @Test func mockEngineConformsToProtocol() {
        let engine = MockTranscriptionEngine()
        #expect(engine is TranscriptionEngine)
    }

    @Test func mockEngineInitialState() {
        let engine = MockTranscriptionEngine()
        #expect(engine.state == .unloaded)
    }

    @Test func mockEngineStateTransitions() async throws {
        let engine = MockTranscriptionEngine()

        #expect(engine.state == .unloaded)

        try await engine.loadModel(name: "tiny", downloadBase: nil)
        #expect(engine.state == .ready)

        let audioData = Data([0x00, 0x01, 0x02, 0x03])
        _ = try await engine.transcribe(audioData: audioData)
        #expect(engine.state == .ready)

        await engine.unloadModel()
        #expect(engine.state == .unloaded)
    }

    @Test func mockEngineLoadByPath() async throws {
        let engine = MockTranscriptionEngine()
        try await engine.loadModel(path: "/path/to/model")
        #expect(engine.state == .ready)
    }

    @Test func mockEngineTranscription() async throws {
        let engine = MockTranscriptionEngine()
        try await engine.loadModel(name: "tiny", downloadBase: nil)

        let audioData = Data([0x00, 0x01, 0x02, 0x03])
        let result = try await engine.transcribe(audioData: audioData)

        #expect(result == "Mock transcription result")
    }

    @Test func mockEngineErrorState() async {
        let engine = MockTranscriptionEngine()
        engine.shouldFailLoad = true

        do {
            try await engine.loadModel(name: "tiny", downloadBase: nil)
            Issue.record("Expected load failure")
        } catch {
            #expect(engine.state == .error)
        }
    }

    @Test func engineTranscriptionEngineBridgesEngineClientResponse() async throws {
        let session = EngineTranscriptionMockURLSession()
        session.mockData = """
        {
            "text": "bonjour tout le monde",
            "language_detected": "fr",
            "duration_ms": 1500,
            "stt_ms": 180
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/transcribe", statusCode: 200)

        let client = EngineClient(session: session)
        let engine = EngineTranscriptionEngine(client: client)
        try await engine.loadModel(name: "remote", downloadBase: nil)

        let text = try await engine.transcribe(
            audioData: Data("audio".utf8),
            options: TranscriptionOptions(language: .french)
        )

        #expect(text == "bonjour tout le monde")
        #expect(engine.state == .ready)
        #expect(session.lastRequest?.httpMethod == "POST")
        #expect(session.lastRequest?.url?.absoluteString == "http://127.0.0.1:19823/transcribe")

        let body = try #require(session.lastRequest?.httpBody)
        let bodyString = try #require(String(data: body, encoding: .utf8))
        #expect(bodyString.contains("name=\"language\""))
        #expect(bodyString.contains("fr"))
    }

    @Test func engineTranscriptionEngineRequiresLoadBeforeTranscribe() async throws {
        let engine = EngineTranscriptionEngine(client: EngineClient(session: EngineTranscriptionMockURLSession()))

        do {
            _ = try await engine.transcribe(
                audioData: Data("audio".utf8),
                options: TranscriptionOptions(language: .automatic)
            )
            Issue.record("Expected modelNotLoaded")
        } catch let error as EngineTranscriptionEngine.EngineError {
            #expect(error == .modelNotLoaded)
        }
    }

    @Test func engineTranscriptionEnginePreservesMappedClientErrors() async throws {
        let session = EngineTranscriptionMockURLSession()
        session.mockData = """
        {
            "error": {
                "code": "STT_NOT_CONFIGURED",
                "message": "STT is not configured."
            }
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/transcribe", statusCode: 503)

        let engine = EngineTranscriptionEngine(client: EngineClient(session: session))
        try await engine.loadModel(name: "remote", downloadBase: nil)

        do {
            _ = try await engine.transcribe(
                audioData: Data("audio".utf8),
                options: TranscriptionOptions(language: .automatic)
            )
            Issue.record("Expected STT_NOT_CONFIGURED error")
        } catch let error as EngineClientError {
            #expect(error == .sttNotConfigured("STT is not configured."))
        }

        #expect(engine.state == .ready)
    }

    private func makeHTTPResponse(path: String, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:19823\(path)")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

@MainActor
final class MockTranscriptionEngine: TranscriptionEngine {
    private(set) var state: TranscriptionEngineState = .unloaded
    var shouldFailLoad = false
    var mockTranscriptionResult = "Mock transcription result"
    private(set) var lastOptions: TranscriptionOptions?

    func loadModel(path: String) async throws {
        if shouldFailLoad {
            state = .error
            throw MockError.loadFailed
        }
        state = .ready
    }

    func loadModel(name: String, downloadBase: URL?) async throws {
        if shouldFailLoad {
            state = .error
            throw MockError.loadFailed
        }
        state = .ready
    }

    func transcribe(audioData: Data, options: TranscriptionOptions) async throws -> String {
        guard state == .ready else {
            throw MockError.modelNotLoaded
        }

        lastOptions = options
        state = .transcribing
        try await Task.sleep(nanoseconds: 10_000_000)
        state = .ready
        return mockTranscriptionResult
    }

    func unloadModel() async {
        state = .unloaded
    }
}

enum MockError: Error {
    case loadFailed
    case modelNotLoaded
}

private final class EngineTranscriptionMockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let mockError {
            throw mockError
        }

        guard let mockData, let mockResponse else {
            throw URLError(.badServerResponse)
        }

        return (mockData, mockResponse)
    }
}
