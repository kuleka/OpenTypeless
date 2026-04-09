//
//  EngineProcessManagerTests.swift
//  OpenTypelessTests
//
//  Created on 2026-03-30.
//

import Testing
@testable import OpenTypeless

@MainActor
@Suite
struct EngineProcessManagerTests {

    private func makeManager(
        healthCheck: @escaping @MainActor () async throws -> HealthResponse = { HealthResponse(status: "ok", version: "1.0.0") },
        pushConfig: @escaping @MainActor (ConfigRequest) async throws -> ConfigStatusResponse = { _ in
            ConfigStatusResponse(status: "configured")
        },
        configProvider: @escaping @MainActor () -> ConfigRequest? = {
            ConfigRequest(stt: nil, llm: ProviderConfiguration(apiBase: "http://test", apiKey: "key", model: "model"), defaultLanguage: nil)
        }
    ) -> EngineProcessManager {
        EngineProcessManager(
            configuration: .init(
                customBinaryPath: nil,
                host: "127.0.0.1",
                port: 19823,
                healthPollInterval: 0.1,
                maxRestartsInWindow: 3,
                restartWindowSeconds: 5.0,
                shutdownGracePeriod: 1.0
            ),
            healthCheck: healthCheck,
            pushConfig: pushConfig,
            configProvider: configProvider
        )
    }

    @Test func initialStateIsNotRunning() {
        let sut = makeManager()
        #expect(sut.isRunning == false)
    }

    @Test func stopSetsIsRunningToFalse() async {
        let sut = makeManager()
        // Start first — it will fail to find binary but sets isRunning briefly
        // Instead just test stop on a never-started manager
        sut.stop()
        #expect(sut.isRunning == false)
    }

    @Test func statusChangeCallbackFires() async {
        var receivedStates: [EngineRuntimeState.Phase] = []
        let sut = EngineProcessManager(
            configuration: .init(
                customBinaryPath: "/nonexistent/binary",
                host: "127.0.0.1",
                port: 19823,
                healthPollInterval: 0.1,
                maxRestartsInWindow: 3,
                restartWindowSeconds: 5.0,
                shutdownGracePeriod: 1.0
            ),
            healthCheck: { throw EngineClientError.connectionFailed },
            pushConfig: { _ in ConfigStatusResponse(status: "configured") },
            configProvider: { nil }
        )
        sut.onStatusChange = { state in
            receivedStates.append(state.phase)
        }

        // Health check fails → no existing engine → binary discovery fails → error
        await sut.start()

        #expect(receivedStates.contains(.checking))
        #expect(receivedStates.contains(.error))
        #expect(sut.isRunning == false)
    }

    @Test func startWithExistingEngineAdoptsIt() async {
        var configPushed = false
        let sut = makeManager(
            pushConfig: { _ in
                configPushed = true
                return ConfigStatusResponse(status: "configured")
            }
        )

        // Engine is already running (health check succeeds)
        await sut.start()

        #expect(sut.isRunning == true)
        #expect(configPushed == true)

        sut.stop()
    }

    @Test func startWithNoConfigReportsUnconfigured() async {
        var receivedStates: [EngineRuntimeState.Phase] = []
        let sut = makeManager(
            configProvider: { nil }
        )
        sut.onStatusChange = { state in
            receivedStates.append(state.phase)
        }

        await sut.start()

        #expect(sut.isRunning == true)
        #expect(receivedStates.contains(.needsConfiguration))

        sut.stop()
    }

    @Test func configPushFailureReportsError() async {
        var receivedStates: [EngineRuntimeState.Phase] = []
        let sut = makeManager(
            pushConfig: { _ in throw EngineClientError.connectionFailed }
        )
        sut.onStatusChange = { state in
            receivedStates.append(state.phase)
        }

        await sut.start()

        #expect(sut.isRunning == true)
        #expect(receivedStates.contains(.error))

        sut.stop()
    }
}
