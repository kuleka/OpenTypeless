//
//  STTConfigStepView.swift
//  OpenTypeless
//
//  Created on 2026-03-30.
//

import SwiftUI

struct STTConfigStepView: View {
    @ObservedObject var settings: SettingsStore
    let onContinue: () -> Void

    @Environment(\.locale) private var locale
    @State private var selectedPreset: EngineSTTProviderPreset = .groq
    @State private var apiBase: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var showingAPIKey = false

    var body: some View {
        VStack(spacing: 20) {
            headerSection

            providerTabs

            ScrollView(.vertical, showsIndicators: false) {
                configFields
            }
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
            IconView(icon: .waveform, size: 36)
                .foregroundStyle(AppColors.accent)

            Text(localized("Remote STT Provider", locale: locale))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(localized("Configure the speech-to-text service for remote transcription.", locale: locale))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var providerTabs: some View {
        HStack(spacing: 0) {
            ForEach(EngineSTTProviderPreset.allCases) { preset in
                providerTab(preset)
            }
        }
        .frame(height: 56)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
    }

    private func providerTab(_ preset: EngineSTTProviderPreset) -> some View {
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

    private func iconForPreset(_ preset: EngineSTTProviderPreset) -> String {
        switch preset {
        case .groq: return "bolt"
        case .openAI: return "brain"
        case .deepgram: return "waveform.path"
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
                Text(localized("API Key", locale: locale))
                    .font(.subheadline)
                    .fontWeight(.medium)

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

                TextField(selectedPreset.defaultModel.isEmpty ? "e.g., whisper-large-v3" : selectedPreset.defaultModel, text: $model)
                    .textFieldStyle(.plain)
                    .aiSettingsInputChrome()
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
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

        guard !trimmedBase.isEmpty, !trimmedModel.isEmpty, !trimmedKey.isEmpty else { return false }
        guard trimmedBase.hasPrefix("http://") || trimmedBase.hasPrefix("https://"),
              URL(string: trimmedBase) != nil else { return false }
        return true
    }

    private func loadSavedConfiguration() {
        selectedPreset = settings.selectedEngineSTTProvider
        apiBase = settings.engineSTTAPIBase
        model = settings.engineSTTModel
        apiKey = settings.configuredEngineSTTAPIKey() ?? ""
    }

    private func applyPresetDefaults(_ preset: EngineSTTProviderPreset) {
        apiBase = preset.defaultAPIBase
        model = preset.defaultModel
        apiKey = settings.configuredEngineSTTAPIKey(for: preset) ?? ""
    }

    private func saveAndContinue() {
        settings.selectedEngineSTTProvider = selectedPreset
        settings.engineSTTAPIBase = apiBase
        settings.engineSTTModel = model

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            try? settings.saveEngineSTTAPIKey(trimmedKey)
        }

        onContinue()
    }
}

#if DEBUG
struct STTConfigStepView_Previews: PreviewProvider {
    static var previews: some View {
        STTConfigStepView(
            settings: SettingsStore(),
            onContinue: {}
        )
        .frame(width: 800, height: 700)
    }
}
#endif
