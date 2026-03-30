//
//  PolishServiceTests.swift
//  PindropTests
//
//  Created on 2026-03-29.
//

import Foundation
import Testing
@testable import Pindrop

@MainActor
@Suite
struct PolishServiceTests {
    private func makeSUT() -> (service: PolishService, mockSession: MockURLSession) {
        let mockSession = MockURLSession()
        let client = EngineClient(session: mockSession)
        let service = PolishService(client: client)
        return (service, mockSession)
    }

    @Test func polishSendsTranscriptAndAppContextToEngine() async throws {
        let (service, mockSession) = makeSUT()
        mockSession.mockData = """
        {
            "text": "Hi Tom, thanks for the report.",
            "raw_transcript": "hi tom thanks for the report",
            "task": "polish",
            "context_detected": "email",
            "model_used": "gpt-4.1-mini",
            "stt_ms": 0,
            "llm_ms": 180,
            "total_ms": 180
        }
        """.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:19823/polish")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let context = AppContextInfo(
            bundleIdentifier: "com.apple.mail",
            appName: "Mail",
            windowTitle: "Compose New Message",
            focusedElementRole: nil,
            focusedElementValue: nil,
            selectedText: nil,
            documentPath: nil,
            browserURL: nil
        )

        let result = try await service.polish(
            text: "hi tom thanks for the report",
            appContext: context
        )

        #expect(result.text == "Hi Tom, thanks for the report.")
        #expect(result.rawTranscript == "hi tom thanks for the report")
        #expect(result.task == .polish)
        #expect(result.contextDetected == "email")
        #expect(result.modelUsed == "gpt-4.1-mini")
        #expect(!result.usedFallback)

        let request = try #require(mockSession.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "http://127.0.0.1:19823/polish")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(payload["text"] as? String == "hi tom thanks for the report")

        let contextPayload = try #require(payload["context"] as? [String: Any])
        #expect(contextPayload["app_id"] as? String == "com.apple.mail")
        #expect(contextPayload["window_title"] as? String == "Compose New Message")
    }

    @Test func translateModeIncludesOutputLanguage() async throws {
        let (service, mockSession) = makeSUT()
        mockSession.mockData = """
        {
            "text": "Hello Tom, the meeting starts at three this afternoon.",
            "raw_transcript": "汤姆你好今天下午三点开会",
            "task": "translate",
            "context_detected": "email",
            "model_used": "gpt-4.1-mini",
            "stt_ms": 0,
            "llm_ms": 210,
            "total_ms": 210
        }
        """.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:19823/polish")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let result = try await service.polish(
            text: "汤姆你好今天下午三点开会",
            task: .translate,
            outputLanguage: "en"
        )

        #expect(result.task == .translate)
        #expect(result.text == "Hello Tom, the meeting starts at three this afternoon.")

        let request = try #require(mockSession.lastRequest)
        let body = try #require(request.httpBody)
        let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let options = try #require(payload["options"] as? [String: Any])
        #expect(options["task"] as? String == "translate")
        #expect(options["output_language"] as? String == "en")
    }

    @Test func translateModeRequiresOutputLanguage() async throws {
        let (service, mockSession) = makeSUT()

        do {
            _ = try await service.polish(
                text: "bonjour",
                task: .translate
            )
            Issue.record("Expected output language validation error")
        } catch let error as PolishService.PolishError {
            #expect(error == .outputLanguageRequired)
        }

        #expect(mockSession.lastRequest == nil)
    }

    @Test func llmFailureFallsBackToRawTranscript() async throws {
        let (service, mockSession) = makeSUT()
        mockSession.mockData = """
        {
            "error": {
                "code": "LLM_FAILURE",
                "message": "Text polishing failed."
            }
        }
        """.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:19823/polish")!,
            statusCode: 502,
            httpVersion: nil,
            headerFields: nil
        )

        let result = try await service.polish(text: "raw transcript")

        #expect(result.text == "raw transcript")
        #expect(result.rawTranscript == "raw transcript")
        #expect(result.usedFallback)
        #expect(result.warningMessage == "Text polishing failed.")
    }

    @Test func nonFallbackErrorsStillBubbleUp() async throws {
        let (service, mockSession) = makeSUT()
        mockSession.mockData = """
        {
            "error": {
                "code": "NOT_CONFIGURED",
                "message": "Engine is not configured."
            }
        }
        """.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "http://127.0.0.1:19823/polish")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        )

        do {
            _ = try await service.polish(text: "test")
            Issue.record("Expected NOT_CONFIGURED error")
        } catch let error as EngineClientError {
            #expect(error == .notConfigured("Engine is not configured."))
        }
    }
}
