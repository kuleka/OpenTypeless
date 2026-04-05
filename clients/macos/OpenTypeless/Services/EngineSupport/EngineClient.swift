//
//  EngineClient.swift
//  OpenTypeless
//
//  Created on 2026-03-29.
//

import Foundation

struct ProviderConfiguration: Codable, Equatable {
    let apiBase: String
    let apiKey: String
    let model: String

    enum CodingKeys: String, CodingKey {
        case apiBase = "api_base"
        case apiKey = "api_key"
        case model
    }
}

struct HealthStatsResponse: Codable, Equatable {
    let requestsTotal: Int
    let requestsFailed: Int
    let lastRequestAt: String?

    enum CodingKeys: String, CodingKey {
        case requestsTotal = "requests_total"
        case requestsFailed = "requests_failed"
        case lastRequestAt = "last_request_at"
    }
}

struct HealthResponse: Codable, Equatable {
    let status: String
    let version: String
    var configured: Bool? = nil
    var sttConfigured: Bool? = nil
    var uptimeSeconds: Int? = nil
    var stats: HealthStatsResponse? = nil

    enum CodingKeys: String, CodingKey {
        case status, version, configured, stats
        case sttConfigured = "stt_configured"
        case uptimeSeconds = "uptime_seconds"
    }
}

struct ConfigRequest: Codable, Equatable {
    let stt: ProviderConfiguration?
    let llm: ProviderConfiguration?
    let defaultLanguage: String?

    enum CodingKeys: String, CodingKey {
        case stt
        case llm
        case defaultLanguage = "default_language"
    }
}

struct ConfigStatusResponse: Codable, Equatable {
    let status: String
}

struct ConfigResponse: Codable, Equatable {
    let configured: Bool
    let stt: ProviderConfiguration?
    let llm: ProviderConfiguration?
    let defaultLanguage: String?

    enum CodingKeys: String, CodingKey {
        case configured
        case stt
        case llm
        case defaultLanguage = "default_language"
    }
}

struct TranscribeResponse: Codable, Equatable {
    let text: String
    let languageDetected: String
    let durationMs: Int
    let sttMs: Int

    enum CodingKeys: String, CodingKey {
        case text
        case languageDetected = "language_detected"
        case durationMs = "duration_ms"
        case sttMs = "stt_ms"
    }
}

enum PolishTask: String, Codable, Equatable {
    case polish
    case translate
}

struct PolishContext: Codable, Equatable {
    let appId: String?
    let windowTitle: String?

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case windowTitle = "window_title"
    }
}

struct PolishOptions: Codable, Equatable {
    let task: PolishTask?
    let language: String?
    let model: String?
    let outputLanguage: String?

    enum CodingKeys: String, CodingKey {
        case task
        case language
        case model
        case outputLanguage = "output_language"
    }
}

struct PolishRequest: Codable, Equatable {
    let text: String
    let context: PolishContext?
    let options: PolishOptions?
}

struct PolishResponse: Codable, Equatable {
    let text: String
    let rawTranscript: String
    let task: String
    let contextDetected: String
    let modelUsed: String
    let llmMs: Int
    let totalMs: Int

    enum CodingKeys: String, CodingKey {
        case text
        case rawTranscript = "raw_transcript"
        case task
        case contextDetected = "context_detected"
        case modelUsed = "model_used"
        case llmMs = "llm_ms"
        case totalMs = "total_ms"
    }
}

struct ErrorResponse: Codable, Equatable {
    struct ErrorPayload: Codable, Equatable {
        let code: String
        let message: String
    }

    let error: ErrorPayload
}

enum EngineClientError: Error, LocalizedError, Equatable {
    case invalidBaseURL
    case invalidResponse
    case connectionFailed
    case notConfigured(String)
    case sttNotConfigured(String)
    case sttFailure(String)
    case llmFailure(String)
    case validationError(String)
    case apiError(statusCode: Int, code: String?, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid Engine host or port"
        case .invalidResponse:
            return "Invalid response from Engine"
        case .connectionFailed:
            return "Unable to connect to Engine"
        case .notConfigured(let message),
             .sttNotConfigured(let message),
             .sttFailure(let message),
             .llmFailure(let message),
             .validationError(let message):
            return message
        case .apiError(_, _, let message):
            return message
        }
    }
}

final class EngineClient {
    static let defaultHost = "127.0.0.1"
    static let defaultPort = 19823

    private let host: String
    private let port: Int
    private let session: URLSessionProtocol
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        host: String = EngineClient.defaultHost,
        port: Int = EngineClient.defaultPort,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.host = host
        self.port = port
        self.session = session
    }

    func health() async throws -> HealthResponse {
        let request = try makeRequest(path: "/health", method: "GET")
        return try await send(request, as: HealthResponse.self)
    }

    func pushConfig(_ requestBody: ConfigRequest) async throws -> ConfigStatusResponse {
        let request = try makeJSONRequest(path: "/config", method: "POST", body: requestBody)
        return try await send(request, as: ConfigStatusResponse.self)
    }

    func fetchConfig() async throws -> ConfigResponse {
        let request = try makeRequest(path: "/config", method: "GET")
        return try await send(request, as: ConfigResponse.self)
    }

    func transcribe(
        audioData: Data,
        fileName: String = "audio.wav",
        mimeType: String = "audio/wav",
        language: String? = nil
    ) async throws -> TranscribeResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try makeRequest(path: "/transcribe", method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = buildMultipartBody(
            audioData: audioData,
            fileName: fileName,
            mimeType: mimeType,
            language: language,
            boundary: boundary
        )
        return try await send(request, as: TranscribeResponse.self)
    }

    func polish(_ requestBody: PolishRequest) async throws -> PolishResponse {
        let request = try makeJSONRequest(path: "/polish", method: "POST", body: requestBody)
        return try await send(request, as: PolishResponse.self)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/\(path)"

        guard let url = components.url else {
            throw EngineClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func makeJSONRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) throws -> URLRequest {
        var request = try makeRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func send<Response: Decodable>(
        _ request: URLRequest,
        as responseType: Response.Type
    ) async throws -> Response {
        let data = try await send(request)

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            throw EngineClientError.invalidResponse
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EngineClientError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw mapError(statusCode: httpResponse.statusCode, data: data)
            }

            return data
        } catch let error as EngineClientError {
            throw error
        } catch is URLError {
            throw EngineClientError.connectionFailed
        } catch {
            throw EngineClientError.apiError(statusCode: -1, code: nil, message: error.localizedDescription)
        }
    }

    private func mapError(statusCode: Int, data: Data) -> EngineClientError {
        guard let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) else {
            return .apiError(statusCode: statusCode, code: nil, message: "HTTP \(statusCode)")
        }

        switch errorResponse.error.code {
        case "NOT_CONFIGURED":
            return .notConfigured(errorResponse.error.message)
        case "STT_NOT_CONFIGURED":
            return .sttNotConfigured(errorResponse.error.message)
        case "STT_FAILURE":
            return .sttFailure(errorResponse.error.message)
        case "LLM_FAILURE":
            return .llmFailure(errorResponse.error.message)
        case "VALIDATION_ERROR":
            return .validationError(errorResponse.error.message)
        default:
            return .apiError(
                statusCode: statusCode,
                code: errorResponse.error.code,
                message: errorResponse.error.message
            )
        }
    }

    private func buildMultipartBody(
        audioData: Data,
        fileName: String,
        mimeType: String,
        language: String?,
        boundary: String
    ) -> Data {
        var body = Data()

        if let language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            body.appendUTF8("\(language)\r\n")
        }

        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n"
        )
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(audioData)
        body.appendUTF8("\r\n")
        body.appendUTF8("--\(boundary)--\r\n")

        return body
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}
