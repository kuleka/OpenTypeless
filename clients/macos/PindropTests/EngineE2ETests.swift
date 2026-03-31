//
//  EngineE2ETests.swift
//  PindropTests
//
//  Created on 2026-03-30.
//

import Foundation
import Testing
@testable import Pindrop

/// End-to-end integration tests that launch a real Engine subprocess in stub mode
/// and exercise EngineClient over real HTTP.
@Suite(.serialized)
struct EngineE2ETests {

    static let testPort = 29823
    static let engineHost = "127.0.0.1"

    /// Resolve the repo root by walking up from the source file path.
    /// #filePath at compile time resolves to the original source location:
    ///   <repo>/clients/macos/PindropTests/EngineE2ETests.swift
    private static func repoRoot() -> URL? {
        // #filePath is resolved at compile time to the original source path
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<10 {
            url = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("engine").path) {
                return url
            }
        }
        return nil
    }

    private static func venvPythonPath() -> String? {
        guard let root = repoRoot() else { return nil }
        let path = root.appendingPathComponent("engine/.venv/bin/python").path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    private static func engineModuleRoot() -> String? {
        guard let root = repoRoot() else { return nil }
        let path = root.appendingPathComponent("engine").path
        return FileManager.default.isReadableFile(atPath: path) ? path : nil
    }

    // MARK: - Process management

    private static func launchEngine() throws -> Process {
        guard let python = venvPythonPath() else {
            throw SkipError()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = ["-m", "open_typeless.cli", "serve", "--port", "\(testPort)", "--stub"]
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["OPEN_TYPELESS_STUB"] = "1"

        // Set working directory to engine/ so imports resolve
        if let engineRoot = engineModuleRoot() {
            process.currentDirectoryURL = URL(fileURLWithPath: engineRoot)
        }

        // Suppress stdout/stderr to avoid noise in test output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        return process
    }

    private static func waitForHealthy(client: EngineClient, timeout: TimeInterval = 10) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            do {
                let resp = try await client.health()
                if resp.status == "ok" { return true }
            } catch {
                // Engine not ready yet
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
        return false
    }

    private struct SkipError: Error {}

    // MARK: - Tests

    @Test func healthCheckSucceeds() async throws {
        guard EngineE2ETests.venvPythonPath() != nil else {
            try #require(Bool(false), "Skipping: engine/.venv/bin/python not found")
            return
        }

        let process = try EngineE2ETests.launchEngine()
        defer { process.terminate(); process.waitUntilExit() }

        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: EngineE2ETests.testPort,
            session: URLSession.shared
        )

        let ready = await EngineE2ETests.waitForHealthy(client: client)
        #expect(ready, "Engine did not become healthy within 10s")

        let health = try await client.health()
        #expect(health.status == "ok")
        #expect(!health.version.isEmpty)
    }

    @Test func configPushAndFetch() async throws {
        guard EngineE2ETests.venvPythonPath() != nil else {
            try #require(Bool(false), "Skipping: engine/.venv/bin/python not found")
            return
        }

        let process = try EngineE2ETests.launchEngine()
        defer { process.terminate(); process.waitUntilExit() }

        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: EngineE2ETests.testPort,
            session: URLSession.shared
        )

        let ready = await EngineE2ETests.waitForHealthy(client: client)
        try #require(ready, "Engine did not become healthy")

        // Push config
        let configReq = ConfigRequest(
            stt: ProviderConfiguration(apiBase: "https://api.test.com/v1", apiKey: "sk-test-key-12345", model: "whisper-large-v3"),
            llm: ProviderConfiguration(apiBase: "https://api.test.com/v1", apiKey: "sk-test-key-67890", model: "test-model"),
            defaultLanguage: "auto"
        )
        let pushResp = try await client.pushConfig(configReq)
        #expect(pushResp.status == "configured")

        // Fetch config — keys should be masked
        let fetchResp = try await client.fetchConfig()
        #expect(fetchResp.configured == true)
        #expect(fetchResp.llm != nil)
        #expect(fetchResp.llm?.apiKey.contains("****") == true)
    }

    @Test func polishPipeline() async throws {
        guard EngineE2ETests.venvPythonPath() != nil else {
            try #require(Bool(false), "Skipping: engine/.venv/bin/python not found")
            return
        }

        let process = try EngineE2ETests.launchEngine()
        defer { process.terminate(); process.waitUntilExit() }

        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: EngineE2ETests.testPort,
            session: URLSession.shared
        )

        let ready = await EngineE2ETests.waitForHealthy(client: client)
        try #require(ready, "Engine did not become healthy")

        // Must push config first
        let configReq = ConfigRequest(
            stt: nil,
            llm: ProviderConfiguration(apiBase: "https://api.test.com/v1", apiKey: "sk-test-key", model: "test-model"),
            defaultLanguage: nil
        )
        _ = try await client.pushConfig(configReq)

        // Polish with text mode + app context for scene detection
        let polishReq = PolishRequest(
            text: "test input",
            context: PolishContext(appId: "com.apple.mail", windowTitle: "Compose"),
            options: nil
        )
        let polishResp = try await client.polish(polishReq)

        // Stub mode returns "[stub] {text}" where text is the user portion of the prompt
        #expect(polishResp.text.contains("[stub]"))
        #expect(polishResp.rawTranscript == "test input")
        #expect(polishResp.contextDetected == "email")
        #expect(polishResp.task == "polish")
        #expect(polishResp.llmMs >= 0)
        #expect(polishResp.totalMs >= 0)
    }

    @Test func polishWithoutConfigReturnsNotConfigured() async throws {
        guard EngineE2ETests.venvPythonPath() != nil else {
            try #require(Bool(false), "Skipping: engine/.venv/bin/python not found")
            return
        }

        let process = try EngineE2ETests.launchEngine()
        defer { process.terminate(); process.waitUntilExit() }

        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: EngineE2ETests.testPort,
            session: URLSession.shared
        )

        let ready = await EngineE2ETests.waitForHealthy(client: client)
        try #require(ready, "Engine did not become healthy")

        // Call polish without pushing config first — should get NOT_CONFIGURED
        let polishReq = PolishRequest(
            text: "test",
            context: PolishContext(appId: nil, windowTitle: nil),
            options: nil
        )

        do {
            _ = try await client.polish(polishReq)
            #expect(Bool(false), "Expected notConfigured error")
        } catch let error as EngineClientError {
            switch error {
            case .notConfigured:
                break // expected
            default:
                #expect(Bool(false), "Expected notConfigured, got \(error)")
            }
        }
    }
}
