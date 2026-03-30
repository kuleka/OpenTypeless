//
//  LLMConfigStepView.swift
//  Pindrop
//
//  Created on 2026-03-30.
//

import SwiftUI

struct LLMConfigStepView: View {
    @ObservedObject var settings: SettingsStore
    let onContinue: () -> Void

    @Environment(\.locale) private var locale
    @State private var selectedPreset: EngineLLMProviderPreset = .openRouter
    @State private var apiBase: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var showingAPIKey = false

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            providerTabs

            configFields
                .frame(maxHeight: .infinity)

            actionSection
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .onAppear {
            loadSavedConfiguration()
        }
        .onChange(of: selectedPreset) { _, newValue in
            applyPresetDefaults(newValue)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            IconView(icon: .sparkles, size: 36)
                .foregroundStyle(AppColors.accent)

            Text(localized("LLM Provider", locale: locale))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(localized("Configure the AI model used for text polishing.", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var providerTabs: some View {
        HStack(spacing: 0) {
            ForEach(EngineLLMProviderPreset.allCases) { preset in
                providerTab(preset)
            }
        }
        .frame(height: 56)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private func providerTab(_ preset: EngineLLMProviderPreset) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedPreset = preset
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: iconForPreset(preset))
                    .font(.system(size: 18))
                Text(preset.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                selectedPreset == preset
                    ? AppColors.accent.opacity(0.2)
                    : Color.clear
            )
            .foregroundStyle(selectedPreset == preset ? AppColors.accent : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func iconForPreset(_ preset: EngineLLMProviderPreset) -> String {
        switch preset {
        case .openRouter: return "arrow.triangle.branch"
        case .openAI: return "brain"
        case .ollama: return "desktopcomputer"
        case .custom: return "server.rack"
        }
    }

    @ViewBuilder
    private var configFields: some View {
        VStack(spacing: 16) {
            // API Base
            VStack(alignment: .leading, spacing: 8) {
                Text(localized("API Base URL", locale: locale))
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField(selectedPreset.defaultAPIBase.isEmpty ? "https://api.example.com/v1" : selectedPreset.defaultAPIBase, text: $apiBase)
                    .textFieldStyle(.plain)
                    .aiSettingsInputChrome()
            }

            // API Key
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(localized("API Key", locale: locale))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if !selectedPreset.requiresAPIKey {
                        Text(localized("Optional", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }

                HStack {
                    Group {
                        if showingAPIKey {
                            TextField(selectedPreset.apiKeyPlaceholder, text: $apiKey)
                        } else {
                            SecureField(selectedPreset.apiKeyPlaceholder, text: $apiKey)
                        }
                    }
                    .textFieldStyle(.plain)

                    Button {
                        showingAPIKey.toggle()
                    } label: {
                        IconView(icon: showingAPIKey ? .eyeOff : .eye, size: 16)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .aiSettingsInputChrome()
            }

            // Model
            VStack(alignment: .leading, spacing: 8) {
                Text(localized("Model", locale: locale))
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField(selectedPreset.defaultModel.isEmpty ? "e.g., gpt-4o-mini" : selectedPreset.defaultModel, text: $model)
                    .textFieldStyle(.plain)
                    .aiSettingsInputChrome()
            }

            Spacer()

            featureList
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("The LLM will:", locale: locale))
                .font(.subheadline)
                .fontWeight(.medium)

            featureItem(localized("Polish transcribed text based on context", locale: locale))
            featureItem(localized("Fix punctuation, grammar, and filler words", locale: locale))
            featureItem(localized("Adapt tone to the active application", locale: locale))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.accent.opacity(0.05))
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private func featureItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            IconView(icon: .circleCheck, size: 14)
                .foregroundStyle(.green)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionSection: some View {
        Button(action: saveAndContinue) {
            Text(localized("Save & Continue", locale: locale))
                .font(.headline)
                .frame(maxWidth: 200)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canContinue)
    }

    private var canContinue: Bool {
        let trimmedBase = apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBase.isEmpty, !trimmedModel.isEmpty else { return false }
        if selectedPreset.requiresAPIKey && trimmedKey.isEmpty { return false }
        return true
    }

    private func loadSavedConfiguration() {
        selectedPreset = settings.selectedEngineLLMProvider
        apiBase = settings.engineLLMAPIBase
        model = settings.engineLLMModel
        apiKey = settings.configuredEngineLLMAPIKey() ?? ""
    }

    private func applyPresetDefaults(_ preset: EngineLLMProviderPreset) {
        apiBase = preset.defaultAPIBase
        model = preset.defaultModel
        apiKey = settings.configuredEngineLLMAPIKey() ?? ""
    }

    private func saveAndContinue() {
        settings.selectedEngineLLMProvider = selectedPreset
        settings.engineLLMAPIBase = apiBase
        settings.engineLLMModel = model

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            try? settings.saveEngineLLMAPIKey(trimmedKey)
        }

        onContinue()
    }
}

#if DEBUG
struct LLMConfigStepView_Previews: PreviewProvider {
    static var previews: some View {
        LLMConfigStepView(
            settings: SettingsStore(),
            onContinue: {}
        )
        .frame(width: 800, height: 700)
    }
}
#endif
