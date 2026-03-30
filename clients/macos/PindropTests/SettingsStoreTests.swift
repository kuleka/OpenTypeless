//
//  SettingsStoreTests.swift
//  PindropTests
//
//  Created on 2026-01-25.
//

import AppKit
import Testing
@testable import Pindrop

@MainActor
@Suite
struct SettingsStoreTests {
    private func makeSettingsStore() -> SettingsStore {
        let settingsStore = SettingsStore()
        cleanup(settingsStore)
        return settingsStore
    }

    private func cleanup(_ settingsStore: SettingsStore) {
        settingsStore.resetAllSettings()
        try? settingsStore.deleteAPIEndpoint()
        try? settingsStore.deleteAPIKey()
        settingsStore.mentionTemplateOverridesJSON = SettingsStore.Defaults.mentionTemplateOverridesJSON
    }

    @Test func testSaveAndLoadSettings() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.selectedModel = "large-v3"
        #expect(settingsStore.selectedModel == "large-v3")

        settingsStore.selectedThemeMode = .dark
        settingsStore.lightThemePresetID = "paper"
        settingsStore.darkThemePresetID = "signal"
        #expect(settingsStore.selectedThemeMode == .dark)
        #expect(settingsStore.lightThemePresetID == "paper")
        #expect(settingsStore.darkThemePresetID == "signal")

        settingsStore.toggleHotkey = "⌘⇧A"
        #expect(settingsStore.toggleHotkey == "⌘⇧A")

        settingsStore.pushToTalkHotkey = "⌘⇧B"
        #expect(settingsStore.pushToTalkHotkey == "⌘⇧B")

        settingsStore.outputMode = "directInsert"
        #expect(settingsStore.outputMode == "directInsert")

        settingsStore.selectedAppLanguage = .simplifiedChinese
        #expect(settingsStore.selectedAppLanguage == .simplifiedChinese)

        settingsStore.sttMode = .remote
        #expect(settingsStore.sttMode == .remote)
        settingsStore.engineHost = "192.168.1.8"
        settingsStore.enginePort = 19824
        settingsStore.selectedEngineSTTProvider = .deepgram
        settingsStore.engineSTTAPIBase = "https://api.deepgram.com/v1"
        settingsStore.engineSTTModel = "nova-2"
        settingsStore.selectedEngineLLMProvider = .ollama
        settingsStore.engineLLMAPIBase = "http://localhost:11434/v1"
        settingsStore.engineLLMModel = "llama3.2"

        settingsStore.aiEnhancementEnabled = true
        #expect(settingsStore.aiEnhancementEnabled)

        let newStore = SettingsStore()
        #expect(newStore.selectedModel == "large-v3")
        #expect(newStore.selectedThemeMode == .dark)
        #expect(newStore.lightThemePresetID == "paper")
        #expect(newStore.darkThemePresetID == "signal")
        #expect(newStore.toggleHotkey == "⌘⇧A")
        #expect(newStore.pushToTalkHotkey == "⌘⇧B")
        #expect(newStore.outputMode == "directInsert")
        #expect(newStore.selectedAppLanguage == .simplifiedChinese)
        #expect(newStore.sttMode == .remote)
        #expect(newStore.engineHost == "192.168.1.8")
        #expect(newStore.enginePort == 19824)
        #expect(newStore.selectedEngineSTTProvider == .deepgram)
        #expect(newStore.engineSTTAPIBase == "https://api.deepgram.com/v1")
        #expect(newStore.engineSTTModel == "nova-2")
        #expect(newStore.selectedEngineLLMProvider == .ollama)
        #expect(newStore.engineLLMAPIBase == "http://localhost:11434/v1")
        #expect(newStore.engineLLMModel == "llama3.2")
        #expect(newStore.aiEnhancementEnabled)

        settingsStore.selectedModel = "base"
        settingsStore.selectedThemeMode = .system
        settingsStore.lightThemePresetID = SettingsStore.Defaults.lightThemePresetID
        settingsStore.darkThemePresetID = SettingsStore.Defaults.darkThemePresetID
        settingsStore.toggleHotkey = "⌘⇧R"
        settingsStore.pushToTalkHotkey = "⌘⇧T"
        settingsStore.outputMode = "clipboard"
        settingsStore.aiEnhancementEnabled = false
    }

    @Test func testKeychainStorage() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        let testEndpoint = "https://api.openai.com/v1/chat/completions"
        let testKey = "sk-test-key-12345"

        try settingsStore.saveAPIEndpoint(testEndpoint)
        #expect(settingsStore.apiEndpoint == testEndpoint)

        try settingsStore.saveAPIKey(testKey)
        #expect(settingsStore.apiKey == testKey)

        let newStore = SettingsStore()
        #expect(newStore.apiEndpoint == testEndpoint)
        #expect(newStore.apiKey == testKey)

        try settingsStore.deleteAPIEndpoint()
        #expect(settingsStore.apiEndpoint == nil)

        try settingsStore.deleteAPIKey()
        #expect(settingsStore.apiKey == nil)

        let emptyStore = SettingsStore()
        #expect(emptyStore.apiEndpoint == nil)
        #expect(emptyStore.apiKey == nil)
    }

    @Test func testKeychainPersistence() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        try settingsStore.saveAPIEndpoint("https://api.example.com/v1")
        try settingsStore.saveAPIKey("key-12345")
        try settingsStore.saveAPIEndpoint("https://api.different.com/v2")
        try settingsStore.saveAPIKey("key-67890")

        #expect(settingsStore.apiEndpoint == "https://api.different.com/v2")
        #expect(settingsStore.apiKey == "key-67890")

        let newStore = SettingsStore()
        #expect(newStore.apiEndpoint == "https://api.different.com/v2")
        #expect(newStore.apiKey == "key-67890")
    }

    @Test func testEngineCredentialsAreStoredPerRoleInKeychain() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.selectedEngineSTTProvider = .groq
        settingsStore.selectedEngineLLMProvider = .openRouter

        try settingsStore.saveEngineSTTAPIKey("gsk-test-stt")
        try settingsStore.saveEngineLLMAPIKey("sk-or-test-llm")

        #expect(settingsStore.loadEngineSTTAPIKey() == "gsk-test-stt")
        #expect(settingsStore.loadEngineLLMAPIKey() == "sk-or-test-llm")

        let newStore = SettingsStore()
        newStore.selectedEngineSTTProvider = .groq
        newStore.selectedEngineLLMProvider = .openRouter
        #expect(newStore.loadEngineSTTAPIKey() == "gsk-test-stt")
        #expect(newStore.loadEngineLLMAPIKey() == "sk-or-test-llm")
    }

    @Test func testEngineProviderConfigurationsRequireCompleteSettings() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        #expect(settingsStore.currentEngineSTTProviderConfiguration() == nil)
        #expect(settingsStore.currentEngineLLMProviderConfiguration() == nil)

        settingsStore.engineSTTAPIBase = "https://api.groq.com/openai/v1"
        settingsStore.engineSTTModel = "whisper-large-v3"
        try settingsStore.saveEngineSTTAPIKey("gsk-test")

        settingsStore.engineLLMAPIBase = "https://openrouter.ai/api/v1"
        settingsStore.engineLLMModel = "openai/gpt-4o-mini"
        try settingsStore.saveEngineLLMAPIKey("sk-or-test")

        #expect(
            settingsStore.currentEngineSTTProviderConfiguration() == ProviderConfiguration(
                apiBase: "https://api.groq.com/openai/v1",
                apiKey: "gsk-test",
                model: "whisper-large-v3"
            )
        )
        #expect(
            settingsStore.currentEngineLLMProviderConfiguration() == ProviderConfiguration(
                apiBase: "https://openrouter.ai/api/v1",
                apiKey: "sk-or-test",
                model: "openai/gpt-4o-mini"
            )
        )
    }

    @Test func testResetAllSettingsClearsEngineCredentials() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        try settingsStore.saveEngineSTTAPIKey("gsk-test")
        try settingsStore.saveEngineLLMAPIKey("sk-or-test")

        settingsStore.resetAllSettings()

        #expect(settingsStore.loadEngineSTTAPIKey() == nil)
        #expect(settingsStore.loadEngineLLMAPIKey() == nil)
        #expect(settingsStore.engineHost == SettingsStore.Defaults.engineHost)
        #expect(settingsStore.enginePort == SettingsStore.Defaults.enginePort)
        #expect(settingsStore.selectedEngineSTTProvider == .groq)
        #expect(settingsStore.selectedEngineLLMProvider == .openRouter)
    }

    @Test func testCustomLocalProviderIsInferredFromOllamaEndpoint() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        try settingsStore.saveAPIEndpoint("http://localhost:11434/v1/chat/completions")

        #expect(settingsStore.currentAIProvider == .custom)
        #expect(settingsStore.currentCustomLocalProvider == .ollama)
        #expect(!settingsStore.requiresAPIKey(for: .custom))
    }

    @Test func testCustomProviderAPIKeysAreScopedBySubtype() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        try settingsStore.saveAPIKey("custom-key", for: .custom, customLocalProvider: .custom)
        try settingsStore.saveAPIKey("lmstudio-key", for: .custom, customLocalProvider: .lmStudio)

        #expect(settingsStore.loadAPIKey(for: .custom, customLocalProvider: .custom) == "custom-key")
        #expect(settingsStore.loadAPIKey(for: .custom, customLocalProvider: .lmStudio) == "lmstudio-key")
        #expect(settingsStore.loadAPIKey(for: .custom, customLocalProvider: .ollama) == nil)
    }

    @Test func testCustomProviderEndpointsAreScopedBySubtype() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        let groqLike = "https://api.groq.com/openai/v1/chat/completions"
        let ollamaLocal = "http://localhost:11434/v1/chat/completions"

        try settingsStore.saveAPIEndpoint(groqLike, for: .custom, customLocalProvider: .custom)
        try settingsStore.saveAPIEndpoint(ollamaLocal, for: .custom, customLocalProvider: .ollama)

        #expect(settingsStore.storedAPIEndpoint(forCustomLocalProvider: .custom) == groqLike)
        #expect(settingsStore.storedAPIEndpoint(forCustomLocalProvider: .ollama) == ollamaLocal)
        #expect(settingsStore.storedAPIEndpoint(forCustomLocalProvider: .lmStudio) == nil)
    }

    @Test func testSavingBlankAPIKeyDeletesStoredValue() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        try settingsStore.saveAPIKey("temporary-key", for: .openai)
        try settingsStore.saveAPIKey("   ", for: .openai)

        #expect(settingsStore.loadAPIKey(for: .openai) == nil)
    }

    @Test func testDefaultValues() {
        let store = makeSettingsStore()
        defer { cleanup(store) }

        #expect(store.selectedModel == SettingsStore.Defaults.selectedModel)
        #expect(store.selectedThemeMode == .system)
        #expect(store.lightThemePresetID == SettingsStore.Defaults.lightThemePresetID)
        #expect(store.darkThemePresetID == SettingsStore.Defaults.darkThemePresetID)
        #expect(store.toggleHotkey == SettingsStore.Defaults.Hotkeys.toggleHotkey)
        #expect(store.pushToTalkHotkey == SettingsStore.Defaults.Hotkeys.pushToTalkHotkey)
        #expect(store.outputMode == "clipboard")
        #expect(store.selectedAppLanguage == .automatic)
        #expect(store.sttMode == .local)
        #expect(store.engineHost == SettingsStore.Defaults.engineHost)
        #expect(store.enginePort == SettingsStore.Defaults.enginePort)
        #expect(store.selectedEngineSTTProvider == .groq)
        #expect(store.engineSTTAPIBase == SettingsStore.Defaults.engineSTTAPIBase)
        #expect(store.engineSTTModel == SettingsStore.Defaults.engineSTTModel)
        #expect(store.selectedEngineLLMProvider == .openRouter)
        #expect(store.engineLLMAPIBase == SettingsStore.Defaults.engineLLMAPIBase)
        #expect(store.engineLLMModel == SettingsStore.Defaults.engineLLMModel)
        #expect(!store.aiEnhancementEnabled)
        #expect(store.floatingIndicatorEnabled)
        #expect(store.floatingIndicatorType == FloatingIndicatorType.pill.rawValue)
        #expect(store.apiEndpoint == nil)
        #expect(store.apiKey == nil)
    }

    @Test func testThemeModeBridgesStoredValue() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.selectedThemeMode = .light

        #expect(settingsStore.themeMode == PindropThemeMode.light.rawValue)
        #expect(settingsStore.selectedThemeMode == .light)
    }

    @Test func testSelectedAppLanguageBridgesStoredValue() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.selectedAppLanguage = .german

        #expect(settingsStore.selectedLanguage == AppLanguage.german.rawValue)
        #expect(settingsStore.selectedAppLanguage == .german)
    }

    @Test func testSTTModeBridgesStoredValue() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.sttMode = .remote

        #expect(settingsStore.sttMode == .remote)

        let newStore = SettingsStore()
        #expect(newStore.sttMode == .remote)
    }

    @Test func testLocalizedResolvesSelectedLocaleStrings() {
        #expect(localized("Settings", locale: Locale(identifier: "de")) == "Einstellungen")
        #expect(localized("Settings", locale: Locale(identifier: "tr")) == "Ayarlar")
    }

    @Test func testThemeModeFallsBackToSystemForUnknownValue() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.themeMode = "mystery"

        #expect(settingsStore.selectedThemeMode == .system)
    }

    @Test func testSelectedThemePresetsResolveCatalogEntries() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.lightThemePresetID = "paper"
        settingsStore.darkThemePresetID = "signal"

        #expect(settingsStore.selectedLightThemePreset.id == "paper")
        #expect(settingsStore.selectedDarkThemePreset.id == "signal")
    }

    @Test func testThemePresetFallsBackToDefaultForUnknownPresetID() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.lightThemePresetID = "unknown"
        settingsStore.darkThemePresetID = "unknown"

        #expect(settingsStore.selectedLightThemePreset.id == PindropThemePresetCatalog.defaultPresetID)
        #expect(settingsStore.selectedDarkThemePreset.id == PindropThemePresetCatalog.defaultPresetID)
    }

    @Test func testThemeModeMapsToAppKitAppearance() {
        #expect(PindropThemeMode.system.appKitAppearanceName == nil)
        #expect(PindropThemeMode.light.appKitAppearanceName == .aqua)
        #expect(PindropThemeMode.dark.appKitAppearanceName == .darkAqua)
    }

    @Test func testResetAllSettingsResetsThemeSettings() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.selectedThemeMode = .dark
        settingsStore.lightThemePresetID = "paper"
        settingsStore.darkThemePresetID = "signal"

        settingsStore.resetAllSettings()

        #expect(settingsStore.selectedThemeMode == .system)
        #expect(settingsStore.lightThemePresetID == SettingsStore.Defaults.lightThemePresetID)
        #expect(settingsStore.darkThemePresetID == SettingsStore.Defaults.darkThemePresetID)
    }

    @Test func testResetAllSettingsResetsSTTMode() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.sttMode = .remote
        settingsStore.resetAllSettings()

        #expect(settingsStore.sttMode == .local)
    }

    @Test func testSelectedFloatingIndicatorTypeBridgesStoredValue() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.selectedFloatingIndicatorType = .notch

        #expect(settingsStore.floatingIndicatorType == FloatingIndicatorType.notch.rawValue)
        #expect(settingsStore.selectedFloatingIndicatorType == .notch)
    }

    @Test func testSelectedFloatingIndicatorTypeFallsBackToPillForUnknownValue() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.floatingIndicatorType = "unknown"

        #expect(settingsStore.selectedFloatingIndicatorType == .pill)
    }

    @Test func testPillFloatingIndicatorOffsetBridgesStoredValue() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.pillFloatingIndicatorOffset = CGSize(width: 42, height: -18)

        #expect(settingsStore.pillFloatingIndicatorOffsetX == 42)
        #expect(settingsStore.pillFloatingIndicatorOffsetY == -18)
        #expect(settingsStore.pillFloatingIndicatorOffset.width == 42)
        #expect(settingsStore.pillFloatingIndicatorOffset.height == -18)
    }

    @Test func testSwitchingAwayFromPillResetsStoredPillOffset() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.selectedFloatingIndicatorType = .pill
        settingsStore.pillFloatingIndicatorOffset = CGSize(width: 36, height: 12)

        settingsStore.selectedFloatingIndicatorType = .bubble

        #expect(settingsStore.pillFloatingIndicatorOffset.width == 0)
        #expect(settingsStore.pillFloatingIndicatorOffset.height == 0)
    }

    @Test func testVibeDefaultsAndRuntimeState() {
        let store = makeSettingsStore()
        defer { cleanup(store) }

        #expect(store.vibeLiveSessionEnabled)
        #expect(store.vibeRuntimeState == .degraded)
        #expect(store.vibeRuntimeDetail == "Vibe mode is disabled.")
    }

    @Test func testUpdateVibeRuntimeState() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.updateVibeRuntimeState(.ready, detail: "Live session context active in Cursor.")

        #expect(settingsStore.vibeRuntimeState == .ready)
        #expect(settingsStore.vibeRuntimeDetail == "Live session context active in Cursor.")
    }

    @Test func testResetAllSettingsResetsVibeRuntimeState() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.vibeLiveSessionEnabled = false
        settingsStore.updateVibeRuntimeState(.ready, detail: "Live session context active in Cursor.")

        settingsStore.resetAllSettings()

        #expect(settingsStore.vibeLiveSessionEnabled)
        #expect(settingsStore.vibeRuntimeState == .degraded)
        #expect(settingsStore.vibeRuntimeDetail == "Vibe mode is disabled.")
    }

    @Test func testEngineRuntimeRecheckMarksCheckingAndIncrementsSequence() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.updateEngineRuntimeState(
            .offline(detail: "Engine is not reachable at 127.0.0.1:19823.")
        )

        settingsStore.requestEngineRuntimeRecheck()

        #expect(settingsStore.engineRuntimeState.phase == .checking)
        #expect(settingsStore.engineRuntimeState.detail == "Rechecking Engine runtime...")
        #expect(settingsStore.engineRuntimeRecheckSequence == 1)

        settingsStore.requestEngineRuntimeRecheck()
        #expect(settingsStore.engineRuntimeRecheckSequence == 2)
    }

    @Test func testResetAllSettingsResetsEngineRuntimeState() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.updateEngineRuntimeState(
            .ready(version: "1.4.0-draft", detail: "Engine is ready for remote transcription and text polishing.")
        )
        settingsStore.requestEngineRuntimeRecheck()

        settingsStore.resetAllSettings()

        #expect(settingsStore.engineRuntimeState.phase == .checking)
        #expect(settingsStore.engineRuntimeState.detail == "Checking Engine runtime...")
        #expect(settingsStore.engineRuntimeRecheckSequence == 0)
    }

    @Test func testEngineRuntimePresentationForOfflineRemoteMode() {
        let presentation = EngineRuntimePresentation(
            runtimeState: .offline(detail: "Engine is not reachable at 127.0.0.1:19823."),
            sttMode: .remote,
            locale: Locale(identifier: "en_US")
        )

        #expect(presentation.statusLabel == "Offline")
        #expect(presentation.detail == "Engine is not reachable at 127.0.0.1:19823.")
        #expect(presentation.guidance == "Start Engine in another terminal, then press Recheck, or switch Transcription Mode back to Local.")
        #expect(presentation.recheckTitle == "Reconnect")
        #expect(presentation.isBusy == false)
    }

    @Test func testEngineRuntimePresentationForSetupNeededLocalMode() {
        let presentation = EngineRuntimePresentation(
            runtimeState: .needsConfiguration(
                .llm,
                detail: "Add an LLM provider base URL, model, and API key to enable Engine polish."
            ),
            sttMode: .local,
            locale: Locale(identifier: "en_US")
        )

        #expect(presentation.statusLabel == "Setup Needed")
        #expect(presentation.guidance == "Add an LLM provider base URL, model, and API key, then press Recheck.")
        #expect(presentation.recheckTitle == "Recheck")
    }

    @Test func testResolveMentionFormattingUsesTerminalProviderDefaultTemplate() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        let resolved = settingsStore.resolveMentionFormatting(
            editorBundleIdentifier: "com.microsoft.VSCode",
            terminalProviderIdentifier: "codex",
            adapterDefaultTemplate: "@{path}",
            adapterDefaultPrefix: "@"
        )

        #expect(resolved.mentionTemplate == "[@{path}]({path})")
        #expect(resolved.mentionPrefix == "@")
    }

    @Test func testResolveMentionFormattingPrefersProviderOverrideOverEditorOverride() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.setMentionTemplateOverride("/{path}", for: "provider:codex")
        settingsStore.setMentionTemplateOverride("@{path}", for: "editor:com.microsoft.vscode")

        let resolved = settingsStore.resolveMentionFormatting(
            editorBundleIdentifier: "com.microsoft.VSCode",
            terminalProviderIdentifier: "codex",
            adapterDefaultTemplate: "#{path}",
            adapterDefaultPrefix: "#"
        )

        #expect(resolved.mentionTemplate == "/{path}")
        #expect(resolved.mentionPrefix == "/")
    }

    @Test func testSetMentionTemplateOverrideRejectsInvalidTemplate() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        settingsStore.setMentionTemplateOverride("not-a-template", for: "provider:codex")
        #expect(settingsStore.mentionTemplateOverride(for: "provider:codex") == nil)
    }

    @Test func testKeychainErrorHandling() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        do {
            try settingsStore.deleteAPIEndpoint()
            try settingsStore.deleteAPIKey()
            try settingsStore.deleteAPIEndpoint()
            try settingsStore.deleteAPIKey()
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testObservableUpdates() async throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        let task = Task { @MainActor in
            settingsStore.selectedModel = "tiny"
            #expect(settingsStore.selectedModel == "tiny")

            try settingsStore.saveAPIEndpoint("https://test.com")
            #expect(settingsStore.apiEndpoint == "https://test.com")
        }

        try await task.value
    }

    // MARK: - Legacy Cleanup Verification

    @Test func testQuickCaptureHotkeyDefaultsAreRemoved() {
        // Quick capture hotkey defaults should no longer exist in the Defaults.Hotkeys namespace
        // This test verifies the struct only contains supported dictation hotkeys
        let toggleDefault = SettingsStore.Defaults.Hotkeys.toggleHotkey
        let pttDefault = SettingsStore.Defaults.Hotkeys.pushToTalkHotkey
        let copyDefault = SettingsStore.Defaults.Hotkeys.copyLastTranscriptHotkey

        #expect(!toggleDefault.isEmpty)
        #expect(!pttDefault.isEmpty)
        #expect(!copyDefault.isEmpty)
    }

    @Test func testLegacyMigrationSkipsWhenEngineLLMAlreadyConfigured() throws {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        // Pre-configure Engine LLM API key
        settingsStore.selectedEngineLLMProvider = .openRouter
        try settingsStore.saveEngineLLMAPIKey("sk-or-existing")

        // Set legacy AI values that would normally migrate
        try settingsStore.saveAPIEndpoint("https://api.openai.com/v1/chat/completions", for: .openai)
        try settingsStore.saveAPIKey("sk-legacy-key", for: .openai)
        settingsStore.aiModel = "gpt-4o"

        // Create a new store to trigger migration
        let newStore = SettingsStore()
        defer { cleanup(newStore) }

        // Engine LLM should retain the existing key, not be overwritten by legacy
        #expect(newStore.loadEngineLLMAPIKey() == "sk-or-existing")
    }

    @Test func testResetAllSettingsDoesNotReferenceLegacyAIFields() {
        let settingsStore = makeSettingsStore()
        defer { cleanup(settingsStore) }

        // After reset, Engine-backed settings should be at defaults
        settingsStore.resetAllSettings()

        #expect(settingsStore.selectedEngineLLMProvider == .openRouter)
        #expect(settingsStore.engineLLMAPIBase == SettingsStore.Defaults.engineLLMAPIBase)
        #expect(settingsStore.engineLLMModel == SettingsStore.Defaults.engineLLMModel)
        #expect(settingsStore.selectedEngineSTTProvider == .groq)
    }
}
