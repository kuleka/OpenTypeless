//
//  EngineE2ETests.swift
//  OpenTypelessTests
//
//  Created on 2026-03-30.
//

import Foundation
import Testing
@testable import OpenTypeless

/// End-to-end integration tests that launch a real Engine subprocess in stub mode
/// and exercise EngineClient over real HTTP.
@Suite(.serialized)
struct EngineE2ETests {

    static let testPort = 29823
    static let bundledBinaryPort = 29824
    static let crashRecoveryPort = 29825
    static let lifecyclePort = 29826
    static let engineHost = "127.0.0.1"

    /// Resolve the repo root by walking up from the source file path.
    /// #filePath at compile time resolves to the original source location:
    ///   <repo>/clients/macos/OpenTypelessTests/EngineE2ETests.swift
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

    private static func bundledBinaryPath() -> String? {
        guard let root = repoRoot() else { return nil }
        let path = root.appendingPathComponent("engine/dist/open-typeless").path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    private static func engineModuleRoot() -> String? {
        guard let root = repoRoot() else { return nil }
        let path = root.appendingPathComponent("engine").path
        return FileManager.default.isReadableFile(atPath: path) ? path : nil
    }

    /// Returns a standalone Engine binary path suitable for EngineProcessManager's customBinaryPath.
    /// Only returns binaries that work with `serve --port <port>` args (not venv python).
    private static func standaloneBinaryPath() -> String? {
        return bundledBinaryPath()
    }

    // MARK: - Process management

    private static func launchEngine() throws -> Process {
        guard let python = venvPythonPath() else {
            throw SkipError()
        }
        return try launchEngineFromBinary(
            path: python,
            arguments: ["-m", "open_typeless.cli", "serve", "--port", "\(testPort)", "--stub"],
            port: testPort
        )
    }

    private static func launchEngineFromBinary(path: String, arguments: [String], port: Int) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["OPEN_TYPELESS_STUB"] = "1"

        // Set working directory to engine/ so imports resolve (needed for venv python)
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

    // MARK: - Bundled Binary Tests

    @Test func bundledBinaryHealthCheck() async throws {
        guard let binaryPath = EngineE2ETests.bundledBinaryPath() else {
            try #require(Bool(false), "Skipping: engine/dist/open-typeless not found (run scripts/build-engine.sh)")
            return
        }

        let process = try EngineE2ETests.launchEngineFromBinary(
            path: binaryPath,
            arguments: ["serve", "--port", "\(EngineE2ETests.bundledBinaryPort)", "--stub"],
            port: EngineE2ETests.bundledBinaryPort
        )
        defer { process.terminate(); process.waitUntilExit() }

        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: EngineE2ETests.bundledBinaryPort,
            session: URLSession.shared
        )

        // Bundled binary needs longer startup (PyInstaller extraction)
        let ready = await EngineE2ETests.waitForHealthy(client: client, timeout: 15)
        #expect(ready, "Bundled binary Engine did not become healthy within 15s")

        let health = try await client.health()
        #expect(health.status == "ok")
        #expect(!health.version.isEmpty)
    }

    @Test func bundledBinaryPolishPipeline() async throws {
        guard let binaryPath = EngineE2ETests.bundledBinaryPath() else {
            try #require(Bool(false), "Skipping: engine/dist/open-typeless not found (run scripts/build-engine.sh)")
            return
        }

        let process = try EngineE2ETests.launchEngineFromBinary(
            path: binaryPath,
            arguments: ["serve", "--port", "\(EngineE2ETests.bundledBinaryPort)", "--stub"],
            port: EngineE2ETests.bundledBinaryPort
        )
        defer { process.terminate(); process.waitUntilExit() }

        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: EngineE2ETests.bundledBinaryPort,
            session: URLSession.shared
        )

        let ready = await EngineE2ETests.waitForHealthy(client: client, timeout: 15)
        try #require(ready, "Bundled binary Engine did not become healthy")

        // Push config
        let configReq = ConfigRequest(
            stt: nil,
            llm: ProviderConfiguration(apiBase: "https://api.test.com/v1", apiKey: "sk-test-key", model: "test-model"),
            defaultLanguage: nil
        )
        _ = try await client.pushConfig(configReq)

        // Polish with app context for scene detection
        let polishReq = PolishRequest(
            text: "bundled binary test",
            context: PolishContext(appId: "com.apple.mail", windowTitle: "Compose"),
            options: nil
        )
        let polishResp = try await client.polish(polishReq)

        #expect(polishResp.text.contains("[stub]"))
        #expect(polishResp.rawTranscript == "bundled binary test")
        #expect(polishResp.contextDetected == "email")
    }

}

// MARK: - Status Collector

@MainActor
final class StatusCollector {
    var phases: [EngineRuntimeState.Phase] = []

    func record(_ state: EngineRuntimeState) {
        phases.append(state.phase)
    }

    func waitFor(_ target: EngineRuntimeState.Phase, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if phases.contains(target) { return true }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return false
    }

    func reset() {
        phases.removeAll()
    }
}

// MARK: - Managed Engine Lifecycle E2E Tests (MainActor-isolated)

/// Tests that exercise EngineProcessManager with a real Engine process.
/// Requires engine/dist/open-typeless (run scripts/build-engine.sh).
@MainActor
@Suite(.serialized)
struct EngineManagedE2ETests {

    private static func repoRoot() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<10 {
            url = url.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("engine").path) {
                return url
            }
        }
        return nil
    }

    private static func standaloneBinaryPath() -> String? {
        guard let root = repoRoot() else { return nil }
        let path = root.appendingPathComponent("engine/dist/open-typeless").path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    private static func waitForHealthy(client: EngineClient, timeout: TimeInterval = 20) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            do {
                let resp = try await client.health()
                if resp.status == "ok" { return true }
            } catch {}
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        return false
    }

    /// Kill any leftover process listening on the given port to ensure a clean test.
    private static func ensurePortFree(_ port: Int) {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-ti", ":\(port)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return }
        for line in output.split(separator: "\n") {
            if let pid = Int32(line.trimmingCharacters(in: .whitespaces)) {
                kill(pid, SIGKILL)
            }
        }
    }

    @Test func engineCrashRecovery() async throws {
        guard let binaryPath = EngineManagedE2ETests.standaloneBinaryPath() else {
            try #require(Bool(false), "Skipping: engine/dist/open-typeless not found (run scripts/build-engine.sh)")
            return
        }

        let port = EngineE2ETests.crashRecoveryPort
        EngineManagedE2ETests.ensurePortFree(port)
        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: port,
            session: URLSession.shared
        )

        let stubConfig = ConfigRequest(
            stt: nil,
            llm: ProviderConfiguration(apiBase: "https://api.test.com/v1", apiKey: "sk-test-key", model: "test-model"),
            defaultLanguage: nil
        )

        let status = StatusCollector()

        let manager = EngineProcessManager(
            configuration: .init(
                customBinaryPath: binaryPath,
                host: EngineE2ETests.engineHost,
                port: port,
                stubMode: true,
                healthPollInterval: 2.0,
                maxRestartsInWindow: 5,
                restartWindowSeconds: 60.0,
                shutdownGracePeriod: 2.0,
                suppressProcessOutput: true,
                startupGracePeriod: 10.0
            ),
            healthCheck: { try await client.health() },
            pushConfig: { try await client.pushConfig($0) },
            configProvider: { stubConfig }
        )
        manager.onStatusChange = { status.record($0) }
        defer { manager.stop() }

        await manager.start()

        // Wait for manager to reach ready state (healthy + config pushed)
        let initialReady = await status.waitFor(.ready, timeout: 20)
        try #require(initialReady, "Engine did not reach ready state before crash test")

        // Get the PID for the kill
        guard let process = manager.engineProcess, process.isRunning else {
            try #require(Bool(false), "Engine process not available for crash test")
            return
        }
        let pid = process.processIdentifier

        // Kill the entire process group to ensure child processes (PyInstaller) are also killed
        // This prevents orphaned child processes from holding the port
        kill(-pid, SIGKILL)
        // Also clean up any orphans on the port
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        EngineManagedE2ETests.ensurePortFree(port)

        // Clear status states to track recovery
        status.reset()

        // Wait for manager to recover and reach ready state again
        let recoveredReady = await status.waitFor(.ready, timeout: 25)
        #expect(recoveredReady, "Engine did not recover to ready state after crash")

        // Verify restarted Engine accepts polish after recovery
        if recoveredReady {
            let polishReq = PolishRequest(
                text: "post-crash test",
                context: PolishContext(appId: nil, windowTitle: nil),
                options: nil
            )
            let polishResp = try await client.polish(polishReq)
            #expect(polishResp.text.contains("[stub]"))
        }
    }

    @Test func managedLifecycleHappyPath() async throws {
        guard let binaryPath = EngineManagedE2ETests.standaloneBinaryPath() else {
            try #require(Bool(false), "Skipping: engine/dist/open-typeless not found (run scripts/build-engine.sh)")
            return
        }

        let port = EngineE2ETests.lifecyclePort
        EngineManagedE2ETests.ensurePortFree(port)
        let client = EngineClient(
            host: EngineE2ETests.engineHost,
            port: port,
            session: URLSession.shared
        )

        let stubConfig = ConfigRequest(
            stt: nil,
            llm: ProviderConfiguration(apiBase: "https://api.test.com/v1", apiKey: "sk-test-key", model: "test-model"),
            defaultLanguage: nil
        )

        let status = StatusCollector()

        let manager = EngineProcessManager(
            configuration: .init(
                customBinaryPath: binaryPath,
                host: EngineE2ETests.engineHost,
                port: port,
                stubMode: true,
                healthPollInterval: 2.0,
                maxRestartsInWindow: 5,
                restartWindowSeconds: 60.0,
                shutdownGracePeriod: 2.0,
                suppressProcessOutput: true,
                startupGracePeriod: 10.0
            ),
            healthCheck: { try await client.health() },
            pushConfig: { try await client.pushConfig($0) },
            configProvider: { stubConfig }
        )
        manager.onStatusChange = { status.record($0) }

        await manager.start()

        // Wait for manager to reach ready state (healthy + config pushed)
        let ready = await status.waitFor(.ready, timeout: 20)
        try #require(ready, "Managed Engine did not reach ready state")
        #expect(status.phases.contains(.checking), "Expected checking state in lifecycle")

        // Verify polish works through the managed engine
        let polishReq = PolishRequest(
            text: "lifecycle test",
            context: PolishContext(appId: "com.apple.mail", windowTitle: "Inbox"),
            options: nil
        )
        let polishResp = try await client.polish(polishReq)
        #expect(polishResp.text.contains("[stub]"))
        #expect(polishResp.contextDetected == "email")

        // Get PID before stop
        let pid = manager.engineProcess?.processIdentifier ?? 0

        // Stop and verify cleanup
        manager.stop()
        #expect(manager.isRunning == false)

        // Verify no orphan process remains
        if pid > 0 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            let processStillAlive = kill(pid, 0) == 0
            #expect(!processStillAlive, "Engine process (PID=\(pid)) still alive after stop()")
        }
    }
}
