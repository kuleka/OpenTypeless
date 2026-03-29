//
//  EngineClientTests.swift
//  EngineCoreTests
//
//  Created on 2026-03-29.
//

import Foundation
import Testing
@testable import EngineCore

@Suite
struct EngineClientTests {
    private func makeSUT(
        host: String = EngineClient.defaultHost,
        port: Int = EngineClient.defaultPort
    ) -> (client: EngineClient, session: EngineClientMockURLSession) {
        let session = EngineClientMockURLSession()
        let client = EngineClient(host: host, port: port, session: session)
        return (client, session)
    }

    @Test func healthUsesConfiguredEndpoint() async throws {
        let (client, session) = makeSUT()
        session.mockData = """
        {
            "status": "ok",
            "version": "0.1.0"
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/health", statusCode: 200)

        let response = try await client.health()

        #expect(response == HealthResponse(status: "ok", version: "0.1.0"))
        #expect(session.lastRequest?.httpMethod == "GET")
        #expect(session.lastRequest?.url?.absoluteString == "http://127.0.0.1:19823/health")
    }

    @Test func pushConfigEncodesRequestBody() async throws {
        let (client, session) = makeSUT(host: "localhost", port: 19824)
        session.mockData = """
        {
            "status": "configured"
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(
            url: URL(string: "http://localhost:19824/config")!,
            statusCode: 200
        )

        let requestBody = ConfigRequest(
            stt: ProviderConfiguration(
                apiBase: "https://api.groq.com/openai/v1",
                apiKey: "gsk_test",
                model: "whisper-large-v3"
            ),
            llm: ProviderConfiguration(
                apiBase: "https://openrouter.ai/api/v1",
                apiKey: "sk-or-test",
                model: "openai/gpt-4o-mini"
            ),
            defaultLanguage: "auto"
        )

        let response = try await client.pushConfig(requestBody)

        #expect(response.status == "configured")
        #expect(session.lastRequest?.httpMethod == "POST")
        #expect(session.lastRequest?.url?.absoluteString == "http://localhost:19824/config")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let parsedJSON = try jsonObject(from: session.lastRequest?.httpBody)
        let jsonBody = try #require(parsedJSON)
        let stt = try #require(jsonBody["stt"] as? [String: Any])
        let llm = try #require(jsonBody["llm"] as? [String: Any])
        #expect(stt["api_base"] as? String == "https://api.groq.com/openai/v1")
        #expect(stt["api_key"] as? String == "gsk_test")
        #expect(stt["model"] as? String == "whisper-large-v3")
        #expect(llm["api_base"] as? String == "https://openrouter.ai/api/v1")
        #expect(llm["api_key"] as? String == "sk-or-test")
        #expect(llm["model"] as? String == "openai/gpt-4o-mini")
        #expect(jsonBody["default_language"] as? String == "auto")
    }

    @Test func fetchConfigDecodesMaskedConfiguration() async throws {
        let (client, session) = makeSUT()
        session.mockData = """
        {
            "configured": true,
            "stt": {
                "api_base": "https://api.groq.com/openai/v1",
                "api_key": "gsk_****1234",
                "model": "whisper-large-v3"
            },
            "llm": {
                "api_base": "https://openrouter.ai/api/v1",
                "api_key": "sk-or-****5678",
                "model": "openai/gpt-4o-mini"
            },
            "default_language": "auto"
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/config", statusCode: 200)

        let response = try await client.fetchConfig()

        #expect(response.configured)
        #expect(response.stt?.apiKey == "gsk_****1234")
        #expect(response.llm?.apiKey == "sk-or-****5678")
        #expect(response.defaultLanguage == "auto")
    }

    @Test func transcribeBuildsMultipartRequest() async throws {
        let (client, session) = makeSUT()
        session.mockData = """
        {
            "text": "hello world",
            "language_detected": "en",
            "duration_ms": 5200,
            "stt_ms": 250
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/transcribe", statusCode: 200)

        let response = try await client.transcribe(
            audioData: Data("test-audio".utf8),
            fileName: "recording.wav",
            mimeType: "audio/wav",
            language: "en"
        )

        #expect(response.text == "hello world")
        #expect(session.lastRequest?.httpMethod == "POST")
        #expect(session.lastRequest?.url?.absoluteString == "http://127.0.0.1:19823/transcribe")

        let contentType = try #require(session.lastRequest?.value(forHTTPHeaderField: "Content-Type"))
        #expect(contentType.contains("multipart/form-data"))
        #expect(contentType.contains("boundary="))

        let requestBody = try #require(session.lastRequest?.httpBody)
        let bodyString = try #require(String(data: requestBody, encoding: .utf8))
        #expect(bodyString.contains("name=\"language\""))
        #expect(bodyString.contains("en"))
        #expect(bodyString.contains("name=\"file\"; filename=\"recording.wav\""))
        #expect(bodyString.contains("Content-Type: audio/wav"))
        #expect(bodyString.contains("test-audio"))
    }

    @Test func polishEncodesTextContextAndOptions() async throws {
        let (client, session) = makeSUT()
        session.mockData = """
        {
            "text": "Hello Tom, thanks for the update.",
            "raw_transcript": "hello tom thanks for the update",
            "task": "translate",
            "context_detected": "email",
            "model_used": "openai/gpt-4o-mini",
            "stt_ms": 0,
            "llm_ms": 180,
            "total_ms": 180
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/polish", statusCode: 200)

        let requestBody = PolishRequest(
            text: "hello tom thanks for the update",
            context: PolishContext(appId: "com.apple.mail", windowTitle: "Compose New Message"),
            options: PolishOptions(task: .translate, language: nil, model: nil, outputLanguage: "en")
        )

        let response = try await client.polish(requestBody)

        #expect(response.rawTranscript == "hello tom thanks for the update")
        #expect(response.contextDetected == "email")
        #expect(session.lastRequest?.httpMethod == "POST")
        #expect(session.lastRequest?.url?.absoluteString == "http://127.0.0.1:19823/polish")

        let parsedJSON = try jsonObject(from: session.lastRequest?.httpBody)
        let jsonBody = try #require(parsedJSON)
        let context = try #require(jsonBody["context"] as? [String: Any])
        let options = try #require(jsonBody["options"] as? [String: Any])
        #expect(jsonBody["text"] as? String == "hello tom thanks for the update")
        #expect(context["app_id"] as? String == "com.apple.mail")
        #expect(context["window_title"] as? String == "Compose New Message")
        #expect(options["task"] as? String == "translate")
        #expect(options["output_language"] as? String == "en")
    }

    @Test func mapsConfiguredEngineErrors() async throws {
        let (client, session) = makeSUT()

        session.mockData = """
        {
            "error": {
                "code": "NOT_CONFIGURED",
                "message": "Engine is not configured."
            }
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/polish", statusCode: 503)

        do {
            _ = try await client.polish(PolishRequest(text: "hello", context: nil, options: nil))
            Issue.record("Expected NOT_CONFIGURED to throw")
        } catch let error as EngineClientError {
            #expect(error == .notConfigured("Engine is not configured."))
        }

        session.mockData = """
        {
            "error": {
                "code": "LLM_FAILURE",
                "message": "LLM request failed."
            }
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/polish", statusCode: 502)

        do {
            _ = try await client.polish(PolishRequest(text: "hello", context: nil, options: nil))
            Issue.record("Expected LLM_FAILURE to throw")
        } catch let error as EngineClientError {
            #expect(error == .llmFailure("LLM request failed."))
        }

        session.mockData = """
        {
            "error": {
                "code": "STT_NOT_CONFIGURED",
                "message": "STT is not configured."
            }
        }
        """.data(using: .utf8)
        session.mockResponse = makeHTTPResponse(path: "/transcribe", statusCode: 503)

        do {
            _ = try await client.transcribe(audioData: Data("test".utf8))
            Issue.record("Expected STT_NOT_CONFIGURED to throw")
        } catch let error as EngineClientError {
            #expect(error == .sttNotConfigured("STT is not configured."))
        }
    }

    @Test func mapsConnectionFailures() async throws {
        let (client, session) = makeSUT()
        session.mockError = URLError(.notConnectedToInternet)

        do {
            _ = try await client.health()
            Issue.record("Expected connection failure")
        } catch let error as EngineClientError {
            #expect(error == .connectionFailed)
        }
    }

    private func makeHTTPResponse(path: String, statusCode: Int) -> HTTPURLResponse {
        makeHTTPResponse(
            url: URL(string: "http://127.0.0.1:19823\(path)")!,
            statusCode: statusCode
        )
    }

    private func makeHTTPResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private func jsonObject(from data: Data?) throws -> [String: Any]? {
        guard let data else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

final class EngineClientMockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request

        if let mockError {
            throw mockError
        }

        guard let mockData, let mockResponse else {
            throw URLError(.unknown)
        }

        return (mockData, mockResponse)
    }
}
