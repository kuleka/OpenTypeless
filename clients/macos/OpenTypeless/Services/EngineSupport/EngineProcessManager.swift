//
//  EngineProcessManager.swift
//  OpenTypeless
//
//  Created on 2026-03-30.
//

import Foundation

// MARK: - Protocol

@MainActor
protocol EngineProcessManaging: AnyObject {
    var isRunning: Bool { get }
    func start() async
    func stop()
}

// MARK: - EngineProcessManager

@MainActor
@Observable
final class EngineProcessManager: EngineProcessManaging {

    // MARK: - Configuration

    struct Configuration {
        var customBinaryPath: String?
        var host: String
        var port: Int
        var stubMode: Bool = false
        var healthPollInterval: TimeInterval = 5.0
        var maxRestartsInWindow: Int = 5
        var restartWindowSeconds: TimeInterval = 60.0
        var shutdownGracePeriod: TimeInterval = 5.0
        var suppressProcessOutput: Bool = false
        var startupGracePeriod: TimeInterval = 2.0
    }

    // MARK: - Dependencies

    private let configuration: Configuration
    private let healthCheck: @MainActor () async throws -> HealthResponse
    private let pushConfig: @MainActor (ConfigRequest) async throws -> ConfigStatusResponse
    private let configProvider: @MainActor () -> ConfigRequest?

    // MARK: - State

    private(set) var isRunning = false
    private(set) var engineProcess: Process?
    private var healthPollTask: Task<Void, Never>?
    private var consecutiveHealthFailures = 0
    private var restartTimestamps: [Date] = []
    private var hasEverConnected = false

    // MARK: - Callbacks

    var onStatusChange: ((EngineRuntimeState) -> Void)?

    // MARK: - Init

    init(
        configuration: Configuration,
        healthCheck: @escaping @MainActor () async throws -> HealthResponse,
        pushConfig: @escaping @MainActor (ConfigRequest) async throws -> ConfigStatusResponse,
        configProvider: @escaping @MainActor () -> ConfigRequest?
    ) {
        self.configuration = configuration
        self.healthCheck = healthCheck
        self.pushConfig = pushConfig
        self.configProvider = configProvider
    }

    // MARK: - Lifecycle

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        Log.boot.info("EngineProcessManager: starting")
        onStatusChange?(.checking(detail: "Starting Engine..."))

        // Check if Engine is already running at the configured address
        if await checkHealthOnce() {
            Log.boot.info("EngineProcessManager: Engine already running, adopting")
            hasEverConnected = true
            await pushConfigIfAvailable()
            startHealthPolling()
            return
        }

        // Try to spawn Engine
        guard spawnEngine() else {
            onStatusChange?(.error(detail: "Could not find Engine binary. Install open_typeless or set a custom path in Settings."))
            isRunning = false
            return
        }

        startHealthPolling()
    }

    func stop() {
        Log.boot.info("EngineProcessManager: stopping")
        isRunning = false
        healthPollTask?.cancel()
        healthPollTask = nil
        terminateProcess()
    }

    // MARK: - Binary Discovery

    private func resolveEngineBinary() -> (executableURL: URL, arguments: [String])? {
        // Priority 0: Custom path from settings (explicit user override — no fallthrough if set but invalid)
        if let customPath = configuration.customBinaryPath,
           !customPath.isEmpty {
            let url = URL(fileURLWithPath: customPath)
            if FileManager.default.isExecutableFile(atPath: customPath) {
                Log.boot.info("EngineProcessManager: using custom path: \(customPath)")
                return (url, ["serve", "--port", String(configuration.port)])
            }
            Log.boot.error("EngineProcessManager: custom path not executable: \(customPath)")
            return nil
        }

        // Priority 1: Bundled binary in app bundle Resources
        if let bundledURL = Bundle.main.resourceURL?.appendingPathComponent("engine/open-typeless"),
           FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            Log.boot.info("EngineProcessManager: using bundled binary: \(bundledURL.path)")
            return (bundledURL, ["serve", "--port", String(configuration.port)])
        }

        // Priority 2: PATH lookup
        if let pathURL = findInPath("open_typeless") {
            Log.boot.info("EngineProcessManager: found on PATH: \(pathURL.path)")
            return (pathURL, ["serve", "--port", String(configuration.port)])
        }

        // Priority 3: Repo venv fallback
        let repoRoot = resolveRepoRoot()
        let venvPython = repoRoot.appendingPathComponent("engine/.venv/bin/python")
        if FileManager.default.isExecutableFile(atPath: venvPython.path) {
            Log.boot.info("EngineProcessManager: using venv python: \(venvPython.path)")
            return (venvPython, ["-m", "open_typeless.cli", "serve", "--port", String(configuration.port)])
        }

        Log.boot.error("EngineProcessManager: no Engine binary found")
        return nil
    }

    private func findInPath(_ name: String) -> URL? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func resolveRepoRoot() -> URL {
        // Walk up from the app bundle to find the repo root (contains engine/)
        var url = Bundle.main.bundleURL
        for _ in 0..<6 {
            let engineDir = url.appendingPathComponent("engine")
            if FileManager.default.fileExists(atPath: engineDir.path) {
                return url
            }
            url = url.deletingLastPathComponent()
        }
        // Fallback: assume CWD
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // MARK: - Process Management

    private func spawnEngine() -> Bool {
        guard let resolved = resolveEngineBinary() else {
            return false
        }

        let executableURL = resolved.executableURL
        var arguments = resolved.arguments
        if configuration.stubMode {
            arguments.append("--stub")
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        if configuration.suppressProcessOutput {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        } else {
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Log stdout/stderr in background
            readPipeAsync(stdoutPipe, label: "Engine stdout")
            readPipeAsync(stderrPipe, label: "Engine stderr")
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                Log.boot.warning("EngineProcessManager: Engine process terminated with status \(proc.terminationStatus)")
                self.engineProcess = nil
                self.handleProcessTermination()
            }
        }

        do {
            try process.run()
            engineProcess = process
            Log.boot.info("EngineProcessManager: spawned Engine PID=\(process.processIdentifier)")
            return true
        } catch {
            Log.boot.error("EngineProcessManager: failed to spawn Engine: \(error)")
            return false
        }
    }

    private func readPipeAsync(_ pipe: Pipe, label: String) {
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Log.boot.debug("\(label): \(trimmed)")
            }
        }
    }

    private func terminateProcess() {
        guard let process = engineProcess, process.isRunning else {
            engineProcess = nil
            return
        }

        Log.boot.info("EngineProcessManager: sending SIGTERM to PID=\(process.processIdentifier)")
        process.terminate() // sends SIGTERM

        // Wait for graceful shutdown, then SIGKILL
        DispatchQueue.global().asyncAfter(deadline: .now() + configuration.shutdownGracePeriod) { [weak self] in
            guard process.isRunning else { return }
            Log.boot.warning("EngineProcessManager: SIGTERM timeout, sending SIGKILL to PID=\(process.processIdentifier)")
            kill(process.processIdentifier, SIGKILL)
            Task { @MainActor in
                self?.engineProcess = nil
            }
        }
    }

    // MARK: - Health Polling

    private func startHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Initial wait for Engine to start up
            if !self.hasEverConnected {
                try? await Task.sleep(for: .seconds(self.configuration.startupGracePeriod))
            }

            while !Task.isCancelled && self.isRunning {
                let healthy = await self.checkHealthOnce()

                if healthy {
                    if self.consecutiveHealthFailures > 0 || !self.hasEverConnected {
                        Log.boot.info("EngineProcessManager: Engine health check passed")
                        self.consecutiveHealthFailures = 0

                        if !self.hasEverConnected {
                            self.hasEverConnected = true
                            await self.pushConfigIfAvailable()
                        }
                    }
                    self.consecutiveHealthFailures = 0
                } else {
                    self.consecutiveHealthFailures += 1
                    Log.boot.warning("EngineProcessManager: health check failed (\(self.consecutiveHealthFailures) consecutive)")

                    if self.consecutiveHealthFailures >= 3 {
                        self.handleHealthCheckFailure()
                    }
                }

                try? await Task.sleep(for: .seconds(self.configuration.healthPollInterval))
            }
        }
    }

    private func checkHealthOnce() async -> Bool {
        do {
            _ = try await healthCheck()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Config Push

    private func pushConfigIfAvailable() async {
        guard let config = configProvider() else {
            onStatusChange?(.needsConfiguration(.llm, detail: "Engine is running but needs API configuration."))
            return
        }

        do {
            _ = try await pushConfig(config)
            onStatusChange?(.ready(version: nil, detail: "Engine is running and configured."))
        } catch {
            Log.boot.warning("EngineProcessManager: config push failed: \(error)")
            onStatusChange?(.error(detail: "Engine config push failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - Restart Logic

    private func handleProcessTermination() {
        guard isRunning else { return }
        attemptRestart()
    }

    private func handleHealthCheckFailure() {
        guard isRunning else { return }
        consecutiveHealthFailures = 0
        terminateProcess()
        attemptRestart()
    }

    private func attemptRestart() {
        // Rate limiting: max N restarts in the window
        let now = Date()
        restartTimestamps = restartTimestamps.filter {
            now.timeIntervalSince($0) < configuration.restartWindowSeconds
        }

        if restartTimestamps.count >= configuration.maxRestartsInWindow {
            Log.boot.error("EngineProcessManager: restart limit reached (\(configuration.maxRestartsInWindow) in \(Int(configuration.restartWindowSeconds))s)")
            onStatusChange?(.error(detail: "Engine keeps crashing. Restart limit reached."))
            isRunning = false
            healthPollTask?.cancel()
            return
        }

        restartTimestamps.append(now)
        Log.boot.info("EngineProcessManager: attempting restart (\(restartTimestamps.count)/\(configuration.maxRestartsInWindow))")
        onStatusChange?(.checking(detail: "Restarting Engine..."))

        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            try? await Task.sleep(for: .seconds(1))

            if self.spawnEngine() {
                self.hasEverConnected = false
                self.startHealthPolling()
            } else {
                self.onStatusChange?(.error(detail: "Failed to restart Engine."))
                self.isRunning = false
            }
        }
    }
}
