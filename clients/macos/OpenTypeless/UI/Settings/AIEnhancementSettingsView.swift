//
//  AIEnhancementSettingsView.swift
//  OpenTypeless
//
//  Created on 2026-01-25.
//

import SwiftData
import SwiftUI

struct EngineRuntimePresentation: Equatable {
   let statusLabel: String
   let detail: String
   let guidance: String?
   let recheckTitle: String
   let isBusy: Bool

   init(runtimeState: EngineRuntimeState, sttMode: STTMode, locale: Locale) {
      switch runtimeState.phase {
      case .checking:
         statusLabel = localized("Checking...", locale: locale)
         detail = localized(runtimeState.detail, locale: locale)
         guidance = nil
         recheckTitle = localized("Checking...", locale: locale)
         isBusy = true
      case .syncing:
         statusLabel = localized("Syncing...", locale: locale)
         detail = localized(runtimeState.detail, locale: locale)
         guidance = nil
         recheckTitle = localized("Syncing...", locale: locale)
         isBusy = true
      case .ready:
         if let version = runtimeState.version, !version.isEmpty {
            statusLabel = String(
               format: localized("Ready (v%@)", locale: locale),
               version
            )
         } else {
            statusLabel = localized("Ready", locale: locale)
         }
         detail = localized(runtimeState.detail, locale: locale)
         guidance = nil
         recheckTitle = localized("Recheck", locale: locale)
         isBusy = false
      case .offline:
         statusLabel = localized("Offline", locale: locale)
         detail = localized(runtimeState.detail, locale: locale)
         guidance = sttMode == .local
            ? localized("Start Engine in another terminal, then press Recheck. Local dictation can still run without polishing.", locale: locale)
            : localized("Start Engine in another terminal, then press Recheck, or switch Transcription Mode back to Local.", locale: locale)
         recheckTitle = localized("Reconnect", locale: locale)
         isBusy = false
      case .needsConfiguration:
         statusLabel = localized("Setup Needed", locale: locale)
         detail = localized(runtimeState.detail, locale: locale)
         guidance = Self.runtimeGuidance(
            for: runtimeState.missingConfiguration,
            sttMode: sttMode,
            locale: locale
         )
         recheckTitle = localized("Recheck", locale: locale)
         isBusy = false
      case .error:
         statusLabel = localized("Needs Attention", locale: locale)
         detail = localized(runtimeState.detail, locale: locale)
         guidance = localized("Fix the Engine setup issue, then press Recheck.", locale: locale)
         recheckTitle = localized("Recheck", locale: locale)
         isBusy = false
      }
   }

   private static func runtimeGuidance(
      for missingConfiguration: EngineRuntimeState.MissingConfiguration?,
      sttMode: STTMode,
      locale: Locale
   ) -> String {
      switch (sttMode, missingConfiguration) {
      case (.local, _):
         return localized("Add an LLM provider base URL, model, and API key, then press Recheck.", locale: locale)
      case (.remote, .llm):
         return localized("Add an LLM provider base URL, model, and API key, or switch Transcription Mode back to Local.", locale: locale)
      case (.remote, .stt):
         return localized("Add a Remote STT provider base URL, model, and API key, or switch Transcription Mode back to Local.", locale: locale)
      case (.remote, .sttAndLLM), (.remote, nil):
         return localized("Add both Remote STT and LLM provider settings, or switch Transcription Mode back to Local.", locale: locale)
      }
   }
}

struct AIEnhancementSettingsView: View {
   @ObservedObject var settings: SettingsStore
   @Environment(\.modelContext) private var modelContext
   @Environment(\.locale) private var locale

   @State private var enhancementPrompt = ""
   @State private var noteEnhancementPrompt = ""
   @State private var selectedPromptType: PromptType = .transcription
   @State private var showingEngineSTTAPIKey = false
   @State private var showingEngineLLMAPIKey = false
   @State private var showingPromptSaveSuccess = false
   @State private var showAccessibilityAlert = false
   @State private var accessibilityPermissionGranted = false
   @State private var accessibilityPermissionRequestInFlight = false
   @State private var engineSTTAPIKey = ""
   @State private var engineLLMAPIKey = ""
   @State private var localModels: [ModelManager.WhisperModel] = []
   @State private var downloadedLocalModelNames: Set<String> = []
   @State private var activeLocalModelOperation: String?
   @State private var localModelError: String?

   @State private var presets: [PromptPreset] = []
   @State private var showPresetManagement = false

   private var promptPresetStore: PromptPresetStore {
      PromptPresetStore(modelContext: modelContext)
   }

   private var engineHostBinding: Binding<String> {
      Binding(
         get: { settings.engineHost },
         set: { settings.engineHost = $0 }
      )
   }

   private var enginePortBinding: Binding<Int> {
      Binding(
         get: { settings.enginePort },
         set: { settings.enginePort = $0 }
      )
   }

   private var sttModeBinding: Binding<STTMode> {
      Binding(
         get: { settings.sttMode },
         set: { settings.sttMode = $0 }
      )
   }

   private var selectedEngineSTTProviderBinding: Binding<EngineSTTProviderPreset> {
      Binding(
         get: { settings.selectedEngineSTTProvider },
         set: { settings.selectedEngineSTTProvider = $0 }
      )
   }

   private var selectedEngineLLMProviderBinding: Binding<EngineLLMProviderPreset> {
      Binding(
         get: { settings.selectedEngineLLMProvider },
         set: { settings.selectedEngineLLMProvider = $0 }
      )
   }

   private var engineRuntimePresentation: EngineRuntimePresentation {
      EngineRuntimePresentation(
         runtimeState: settings.engineRuntimeState,
         sttMode: settings.sttMode,
         locale: locale
      )
   }

   enum PromptType: String, CaseIterable, Identifiable {
      case transcription = "Transcription"
      case notes = "Notes"

      var id: String { rawValue }

      var icon: Icon {
         switch self {
         case .transcription: return .mic
         case .notes: return .stickyNote
         }
      }

       var description: String {
          switch self {
          case .transcription:
             return localized("Sent to the AI model when processing dictation for direct text insertion.", locale: .autoupdatingCurrent)
          case .notes:
             return
                localized("Used when capturing notes via hotkey. Can add markdown formatting for longer content.", locale: .autoupdatingCurrent)
          }
       }
   }

   var body: some View {
      VStack(spacing: AppTheme.Spacing.xl) {
         enableToggleCard
         providerCard
         promptsCard
         contextCard
      }
      .onAppear {
         loadPresets()
         loadSettingsState()
         refreshPermissionStates()
      }
      .task {
         await refreshLocalModels()
      }
      .onChange(of: settings.selectedPresetId) { _, newValue in
         handlePresetChange(newValue)
      }
      .onChange(of: enhancementPrompt) { _, newValue in
         handlePromptChange(newValue)
      }
      .onChange(of: settings.selectedEngineSTTProvider) { _, newValue in
         applySTTPreset(newValue)
      }
      .onChange(of: settings.selectedEngineLLMProvider) { _, newValue in
         applyLLMPreset(newValue)
      }
      .onChange(of: engineSTTAPIKey) { _, newValue in
         try? settings.saveEngineSTTAPIKey(newValue)
      }
      .onChange(of: engineLLMAPIKey) { _, newValue in
         try? settings.saveEngineLLMAPIKey(newValue)
      }
      .sheet(isPresented: $showPresetManagement) {
         PresetManagementSheet()
            .onDisappear {
               loadPresets()
            }
      }
      .alert(localized("Accessibility Permission Recommended", locale: locale), isPresented: $showAccessibilityAlert) {
         Button(localized("Open System Settings", locale: locale)) {
            PermissionManager().openAccessibilityPreferences()
         }
         Button(localized("Continue Without", locale: locale), role: .cancel) {}
      } message: {
         Text(localized("Vibe mode works best with Accessibility permission. Without it, OpenTypeless falls back to limited app metadata and transcription still works normally.", locale: locale))
      }
   }

   // MARK: - Enable Toggle Card

   private var enableToggleCard: some View {
      SettingsCard(title: localized("Status", locale: locale), icon: "sparkles") {
         Toggle(isOn: $settings.aiEnhancementEnabled) {
            VStack(alignment: .leading, spacing: 2) {
               Text(localized("Enable Engine Polish", locale: locale))
                  .font(AppTypography.body)
                  .foregroundStyle(AppColors.textPrimary)
               Text(localized("Send finished transcripts to Engine `/polish` before output.", locale: locale))
                  .font(AppTypography.caption)
                  .foregroundStyle(AppColors.textSecondary)
            }
         }
         .toggleStyle(.switch)
      }
   }

   // MARK: - Provider Card

   private var providerCard: some View {
      VStack(spacing: AppTheme.Spacing.xl) {
         engineConnectionCard
         sttModeCard

         if settings.sttMode == .local {
            localSTTCard
         } else {
            remoteSTTProviderCard
         }

         llmProviderCard
      }
   }

   private var engineConnectionCard: some View {
      SettingsCard(
         title: localized("Engine Connection", locale: locale),
         icon: "server.rack",
         accessibilityIdentifier: "settings.ai.engineConnection",
         headerAccessory: {
            SettingsCardActionButton(
               title: engineRuntimePresentation.recheckTitle
            ) {
               settings.requestEngineRuntimeRecheck()
            }
            .disabled(engineRuntimePresentation.isBusy)
            .accessibilityIdentifier("settings.ai.engine.recheck")
         }
      ) {
         VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
               VStack(alignment: .leading, spacing: 6) {
                  Text(localized("Host", locale: locale))
                     .font(.subheadline.weight(.medium))
                  TextField("127.0.0.1", text: engineHostBinding)
                     .textFieldStyle(.roundedBorder)
                     .autocorrectionDisabled()
                     .accessibilityIdentifier("settings.ai.engine.host")
               }

               VStack(alignment: .leading, spacing: 6) {
                  Text(localized("Port", locale: locale))
                     .font(.subheadline.weight(.medium))
                  TextField(
                     "19823",
                     value: enginePortBinding,
                     format: .number
                  )
                  .textFieldStyle(.roundedBorder)
                  .accessibilityIdentifier("settings.ai.engine.port")
               }

               Spacer()

               VStack(alignment: .leading, spacing: 6) {
                  Text(localized("Status", locale: locale))
                     .font(.subheadline.weight(.medium))
                  HStack(spacing: 8) {
                     Circle()
                        .fill(engineRuntimeTint)
                        .frame(width: 8, height: 8)
                     Text(engineRuntimePresentation.statusLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(engineRuntimeTint)
                        .accessibilityIdentifier("settings.ai.engine.status")
                  }
               }
            }

            Text(engineRuntimePresentation.detail)
               .font(AppTypography.caption)
               .foregroundStyle(AppColors.textSecondary)

            if let guidance = engineRuntimePresentation.guidance {
               SettingsInfoBanner(
                  icon: engineRuntimeBannerIcon,
                  text: guidance,
                  tint: engineRuntimeBannerTint,
                  background: engineRuntimeBannerTint.opacity(0.12)
               )
               .accessibilityIdentifier("settings.ai.engine.guidance")
            }

            Text(localized("Client talks to Engine over localhost HTTP. Host and port and provider changes are rechecked automatically, and you can run Recheck any time after starting Engine manually.", locale: locale))
               .font(AppTypography.caption)
               .foregroundStyle(AppColors.textSecondary)
         }
      }
   }

   private var sttModeCard: some View {
      SettingsCard(
         title: localized("Transcription Mode", locale: locale),
         icon: "waveform",
         accessibilityIdentifier: "settings.ai.sttModeCard"
      ) {
         VStack(alignment: .leading, spacing: 16) {
            Picker(localized("Speech-to-text mode", locale: locale), selection: sttModeBinding) {
               Text(localized("Local", locale: locale)).tag(STTMode.local)
               Text(localized("Remote (Engine)", locale: locale)).tag(STTMode.remote)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.ai.sttMode")

            Text(
               settings.sttMode == .local
               ? localized("Local mode keeps speech-to-text on the client and only uses Engine for text polishing.", locale: locale)
               : localized("Remote mode uploads recorded audio to Engine `/transcribe`, then sends the transcript to `/polish`.", locale: locale)
            )
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)
         }
      }
   }

   private var localSTTCard: some View {
      SettingsCard(
         title: localized("Local STT", locale: locale),
         icon: "desktopcomputer",
         accessibilityIdentifier: "settings.ai.localSTT"
      ) {
         VStack(alignment: .leading, spacing: 16) {
            if localModels.isEmpty {
               Text(localized("No local transcription models are available yet.", locale: locale))
                  .font(AppTypography.caption)
                  .foregroundStyle(AppColors.textSecondary)
            } else {
               Picker(localized("Default model", locale: locale), selection: $settings.selectedModel) {
                  ForEach(localModels) { model in
                     Text(model.displayName).tag(model.name)
                  }
               }
               .pickerStyle(.menu)
               .accessibilityIdentifier("settings.ai.local.model")

               if let selectedModelMetadata = localModels.first(where: { $0.name == settings.selectedModel }) {
                  VStack(alignment: .leading, spacing: 6) {
                     Text(selectedModelMetadata.description)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                     HStack(spacing: 8) {
                        Text(selectedModelMetadata.formattedSize)
                           .font(AppTypography.caption)
                           .foregroundStyle(AppColors.textSecondary)

                        if downloadedLocalModelNames.contains(selectedModelMetadata.name) {
                           Label(localized("Downloaded", locale: locale), systemImage: "checkmark.circle.fill")
                              .font(AppTypography.caption)
                              .foregroundStyle(.green)
                        } else {
                           Label(localized("Not downloaded", locale: locale), systemImage: "arrow.down.circle")
                              .font(AppTypography.caption)
                              .foregroundStyle(AppColors.warning)
                        }
                     }
                  }
               }

               HStack(spacing: 12) {
                  Button(localized("Refresh Downloads", locale: locale)) {
                     Task { await refreshLocalModels() }
                  }
                  .buttonStyle(.bordered)

                  if !downloadedLocalModelNames.contains(settings.selectedModel) {
                     Button(activeLocalModelOperation == settings.selectedModel ? localized("Downloading...", locale: locale) : localized("Download Selected Model", locale: locale)) {
                        Task { await downloadSelectedLocalModel() }
                     }
                     .buttonStyle(.borderedProminent)
                     .disabled(activeLocalModelOperation == settings.selectedModel)
                  }
               }
            }

            if let localModelError {
               Text(localModelError)
                  .font(AppTypography.caption)
                  .foregroundStyle(AppColors.warning)
            }
         }
      }
   }

   private var remoteSTTProviderCard: some View {
      SettingsCard(
         title: localized("Remote STT Provider", locale: locale),
         icon: "icloud.and.arrow.up",
         accessibilityIdentifier: "settings.ai.remoteSTT"
      ) {
         VStack(alignment: .leading, spacing: 16) {
            Picker(localized("Provider preset", locale: locale), selection: selectedEngineSTTProviderBinding) {
               ForEach(EngineSTTProviderPreset.allCases) { preset in
                  Text(preset.displayName).tag(preset)
               }
            }
            .pickerStyle(.menu)

            engineTextField(
               title: localized("API Base", locale: locale),
               text: $settings.engineSTTAPIBase,
               placeholder: settings.selectedEngineSTTProvider.defaultAPIBase,
               accessibilityIdentifier: "settings.ai.remote.apiBase"
            )

            engineSecureField(
               title: localized("API Key", locale: locale),
               text: $engineSTTAPIKey,
               isShowing: $showingEngineSTTAPIKey,
               placeholder: settings.selectedEngineSTTProvider.apiKeyPlaceholder
            )

            engineTextField(
               title: localized("Model", locale: locale),
               text: $settings.engineSTTModel,
               placeholder: settings.selectedEngineSTTProvider.defaultModel,
               accessibilityIdentifier: "settings.ai.remote.model"
            )
         }
      }
   }

   private var llmProviderCard: some View {
      SettingsCard(
         title: localized("LLM Provider", locale: locale),
         icon: "sparkles.rectangle.stack",
         accessibilityIdentifier: "settings.ai.llmProvider"
      ) {
         VStack(alignment: .leading, spacing: 16) {
            Picker(localized("Provider preset", locale: locale), selection: selectedEngineLLMProviderBinding) {
               ForEach(EngineLLMProviderPreset.allCases) { preset in
                  Text(preset.displayName).tag(preset)
               }
            }
            .pickerStyle(.menu)

            engineTextField(
               title: localized("API Base", locale: locale),
               text: $settings.engineLLMAPIBase,
               placeholder: settings.selectedEngineLLMProvider.defaultAPIBase,
               accessibilityIdentifier: "settings.ai.llm.apiBase"
            )

            engineSecureField(
               title: settings.selectedEngineLLMProvider.requiresAPIKey
                  ? localized("API Key", locale: locale)
                  : localized("API Key (Optional)", locale: locale),
               text: $engineLLMAPIKey,
               isShowing: $showingEngineLLMAPIKey,
               placeholder: settings.selectedEngineLLMProvider.apiKeyPlaceholder
            )

            engineTextField(
               title: localized("Model", locale: locale),
               text: $settings.engineLLMModel,
               placeholder: settings.selectedEngineLLMProvider.defaultModel,
               accessibilityIdentifier: "settings.ai.llm.model"
            )
         }
      }
   }

   private func engineTextField(
      title: String,
      text: Binding<String>,
      placeholder: String,
      accessibilityIdentifier: String? = nil
   ) -> some View {
      VStack(alignment: .leading, spacing: 6) {
         Text(title)
            .font(.subheadline.weight(.medium))
         TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
      }
   }

   private func engineSecureField(
      title: String,
      text: Binding<String>,
      isShowing: Binding<Bool>,
      placeholder: String
   ) -> some View {
      VStack(alignment: .leading, spacing: 6) {
         HStack {
            Text(title)
               .font(.subheadline.weight(.medium))
            Spacer()
            Button(isShowing.wrappedValue ? localized("Hide", locale: locale) : localized("Show", locale: locale)) {
               isShowing.wrappedValue.toggle()
            }
            .buttonStyle(.plain)
            .font(AppTypography.caption)
         }

         if isShowing.wrappedValue {
            TextField(placeholder, text: text)
               .textFieldStyle(.roundedBorder)
               .autocorrectionDisabled()
         } else {
            SecureField(placeholder, text: text)
               .textFieldStyle(.roundedBorder)
         }
      }
   }

   // MARK: - Prompts Card

   private var promptsCard: some View {
      SettingsCard(title: localized("Enhancement Prompts", locale: locale), icon: "text.bubble") {
         VStack(spacing: 16) {
            if selectedPromptType == .transcription {
               presetPicker
               Divider()
                  .overlay(AppColors.divider)
            }

            promptTypeTabs
            promptContent
         }
         .opacity(settings.aiEnhancementEnabled ? 1 : 0.5)
         .disabled(!settings.aiEnhancementEnabled)
      }
   }

   private var validatedPresetSelection: Binding<String?> {
      Binding(
         get: {
            guard let presetId = settings.selectedPresetId,
               presets.contains(where: { $0.id.uuidString == presetId })
            else {
               return nil
            }
            return presetId
         },
         set: { settings.selectedPresetId = $0 }
      )
   }

   private var presetPicker: some View {
      VStack(alignment: .leading, spacing: 6) {
         Text(localized("Prompt Preset", locale: locale))
            .font(.subheadline)
            .fontWeight(.medium)

         HStack(spacing: 8) {
            SelectField(
               options: promptPresetOptions,
               selection: promptPresetSelection,
                placeholder: localized("Custom", locale: locale)
            )
            .frame(maxWidth: 260)

            Button(localized("Manage Presets...", locale: locale)) {
               showPresetManagement = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            if let presetId = settings.selectedPresetId,
               let preset = presets.first(where: { $0.id.uuidString == presetId })
            {
               Text(preset.isBuiltIn ? localized("Built-in (read-only)", locale: locale) : localized("Custom", locale: locale))
                  .font(AppTypography.caption)
                  .foregroundStyle(AppColors.textSecondary)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(AppColors.mutedSurface, in: Capsule())
             }
         }
      }
   }

   // MARK: - Context Card

   private var contextCard: some View {
      SettingsCard(title: localized("Vibe Mode", locale: locale), icon: "wand.and.stars") {
         VStack(alignment: .leading, spacing: 16) {
             Text(localized("Vibe mode captures structured UI context when recording starts so AI enhancement can use your active app state as reference.", locale: locale))
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)

             Toggle(
                localized("Enable vibe mode (UI context)", locale: locale),
               isOn: Binding(
                  get: { settings.enableUIContext },
                  set: { newValue in
                     settings.enableUIContext = newValue
                     if newValue {
                        requestAccessibilityPermissionIfNeeded()
                     }
                  }
               )
            )
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .leading)

             Toggle(
                localized("Enable live session updates during recording", locale: locale),
               isOn: $settings.vibeLiveSessionEnabled
            )
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
               IconView(icon: accessibilityPermissionGranted ? .check : .info, size: 12)
                  .foregroundStyle(accessibilityPermissionGranted ? AppColors.success : AppColors.textSecondary)
                Text(
                    accessibilityPermissionGranted
                      ? localized("Accessibility permission is enabled. Full UI context is available.", locale: locale)
                      : localized("Accessibility permission is not granted. Vibe mode remains non-blocking with limited context.", locale: locale)
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

               if !accessibilityPermissionGranted {
                  Spacer(minLength: 8)
                  Button(localized("Open Settings", locale: locale)) {
                     PermissionManager().openAccessibilityPreferences()
                  }
                  .buttonStyle(.borderless)
                  .font(.caption)
               }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
               RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .strokeBorder(AppColors.border.opacity(0.5), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
               HStack(spacing: 6) {
                  Circle()
                     .fill(vibeRuntimeColor)
                     .frame(width: 8, height: 8)
                  Text(String(format: localized("Runtime: %@", locale: locale), vibeRuntimeLabel))
                     .font(.caption.weight(.semibold))
                     .foregroundStyle(vibeRuntimeColor)
               }

                Text(settings.vibeRuntimeDetail)
                   .font(AppTypography.caption)
                   .foregroundStyle(AppColors.textSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
               RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .strokeBorder(AppColors.border.opacity(0.5), lineWidth: 1)
            )

            VStack(spacing: 12) {
               Toggle(localized("Include clipboard text", locale: locale), isOn: $settings.enableClipboardContext)
                  .toggleStyle(.switch)
                  .frame(maxWidth: .infinity, alignment: .leading)
            }
         }
         .opacity(settings.aiEnhancementEnabled ? 1 : 0.5)
         .disabled(!settings.aiEnhancementEnabled)
      }
   }

   private var vibeRuntimeLabel: String {
      switch settings.vibeRuntimeState {
      case .ready:
         return localized("Ready", locale: locale)
      case .limited:
         return localized("Limited", locale: locale)
      case .degraded:
         return localized("Degraded", locale: locale)
      }
   }

   private var vibeRuntimeColor: Color {
       switch settings.vibeRuntimeState {
       case .ready:
          return AppColors.success
       case .limited:
          return AppColors.warning
       case .degraded:
          return AppColors.error
       }
    }

   private var promptTypeTabs: some View {
      HStack(spacing: 0) {
         ForEach(PromptType.allCases) { type in
            promptTypeTab(type)
         }
      }
      .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
   }

   private func promptTypeTab(_ type: PromptType) -> some View {
      Button {
         withAnimation(.spring(duration: 0.3)) {
            selectedPromptType = type
         }
      } label: {
         VStack(spacing: 3) {
            IconView(icon: type.icon, size: 14)
            Text(localized(type.rawValue, locale: locale))
               .font(.caption2)
               .fontWeight(.medium)
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .padding(.vertical, 10)
         .contentShape(Rectangle())
         .background(
            selectedPromptType == type
               ? AppColors.accent.opacity(0.2)
               : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
         )
         .foregroundStyle(selectedPromptType == type ? AppColors.accent : AppColors.textSecondary)
      }
      .buttonStyle(.plain)
   }

   @ViewBuilder
   private var promptContent: some View {
      let currentPrompt =
         selectedPromptType == .transcription ? $enhancementPrompt : $noteEnhancementPrompt
      let charCount =
         selectedPromptType == .transcription
         ? enhancementPrompt.count : noteEnhancementPrompt.count

      let isReadOnly = selectedPromptType == .transcription && isBuiltInPresetSelected

      VStack(alignment: .leading, spacing: 12) {
          TextEditor(text: currentPrompt)
             .font(AppTypography.body)
             .frame(minHeight: 120, maxHeight: 220)
             .padding(8)
             .scrollContentBackground(.hidden)
             .background(AppColors.inputBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
             .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                   .strokeBorder(AppColors.inputBorder, lineWidth: 1)
             )
             .disabled(isReadOnly)
             .opacity(isReadOnly ? 0.7 : 1)

         HStack {
            Button(localized("Reset to Default", locale: locale)) {
               resetCurrentPrompt()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

             Text(String(format: localized("%d characters", locale: locale), charCount))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
         }

          Text(selectedPromptType.description)
             .font(AppTypography.caption)
             .foregroundStyle(AppColors.textSecondary)

         HStack {
            Button(localized("Save Prompt", locale: locale)) {
               saveCurrentPrompt()
            }
            .buttonStyle(.borderedProminent)
            .disabled(charCount == 0 || isReadOnly)

            Spacer()

            if showingPromptSaveSuccess {
               HStack(spacing: 6) {
                  IconView(icon: .check, size: 12)
                     .foregroundStyle(AppColors.success)
                   Text(localized("Saved", locale: locale))
                     .font(AppTypography.caption)
                     .foregroundStyle(AppColors.success)
               }
            }
         }
      }
   }

   private var isBuiltInPresetSelected: Bool {
      guard let id = settings.selectedPresetId,
         let preset = presets.first(where: { $0.id.uuidString == id })
      else { return false }
      return preset.isBuiltIn
   }

   private func resetCurrentPrompt() {
      switch selectedPromptType {
      case .transcription:
         settings.selectedPresetId = nil  // Reset preset to Custom
         enhancementPrompt = localizedTranscriptionPrompt(SettingsStore.Defaults.aiEnhancementPrompt)
      case .notes:
         noteEnhancementPrompt = localizedNotePrompt(SettingsStore.Defaults.noteEnhancementPrompt)
      }
   }

   private func saveCurrentPrompt() {
      switch selectedPromptType {
      case .transcription:
         savePrompt()
      case .notes:
         saveNotePrompt()
      }
   }

    private func loadSettingsState() {
       noteEnhancementPrompt = localizedNotePrompt(settings.noteEnhancementPrompt)
       engineSTTAPIKey = settings.loadEngineSTTAPIKey() ?? ""
       engineLLMAPIKey = settings.loadEngineLLMAPIKey() ?? ""
    }

   private func applySTTPreset(_ preset: EngineSTTProviderPreset) {
      settings.engineSTTAPIBase = preset.defaultAPIBase
      settings.engineSTTModel = preset.defaultModel
      engineSTTAPIKey = settings.loadEngineSTTAPIKey(for: preset) ?? ""
   }

   private func applyLLMPreset(_ preset: EngineLLMProviderPreset) {
      settings.engineLLMAPIBase = preset.defaultAPIBase
      settings.engineLLMModel = preset.defaultModel
      engineLLMAPIKey = settings.loadEngineLLMAPIKey(for: preset) ?? ""
   }

   private var engineRuntimeTint: Color {
      switch settings.engineRuntimeState.phase {
      case .checking, .syncing:
         return AppColors.textSecondary
      case .ready:
         return .green
      case .offline, .needsConfiguration, .error:
         return AppColors.warning
      }
   }

   private var engineRuntimeBannerTint: Color {
      switch settings.engineRuntimeState.phase {
      case .error:
         return AppColors.warning
      case .offline, .needsConfiguration:
         return AppColors.accent
      case .checking, .syncing, .ready:
         return AppColors.textSecondary
      }
   }

   private var engineRuntimeBannerIcon: String {
      switch settings.engineRuntimeState.phase {
      case .offline:
         return "bolt.horizontal.circle"
      case .needsConfiguration:
         return "slider.horizontal.3"
      case .error:
         return "exclamationmark.triangle"
      case .checking, .syncing, .ready:
         return "info.circle"
      }
   }

   @MainActor
   private func refreshLocalModels() async {
      let modelManager = ModelManager()
      localModels = modelManager.availableModels.filter {
         $0.provider.isLocal && $0.availability == .available
      }

      await modelManager.refreshDownloadedModels()
      let downloadedModels = await modelManager.getDownloadedModels()
      downloadedLocalModelNames = Set(downloadedModels.map(\.name))
   }

   @MainActor
   private func downloadSelectedLocalModel() async {
      let modelName = settings.selectedModel
      guard !modelName.isEmpty else { return }

      activeLocalModelOperation = modelName
      localModelError = nil
      let modelManager = ModelManager()

      do {
         try await modelManager.downloadModel(named: modelName)
         let downloadedModels = await modelManager.getDownloadedModels()
         downloadedLocalModelNames = Set(downloadedModels.map(\.name))
      } catch {
         localModelError = String(
            format: localized("Failed to download %@: %@", locale: locale),
            modelName,
            error.localizedDescription
         )
      }

      activeLocalModelOperation = nil
   }

   private func savePrompt() {
      settings.aiEnhancementPrompt = enhancementPrompt

      showingPromptSaveSuccess = true

      Task {
         try? await Task.sleep(for: .seconds(3))
         showingPromptSaveSuccess = false
      }
   }

   private func saveNotePrompt() {
      settings.noteEnhancementPrompt = noteEnhancementPrompt

      showingPromptSaveSuccess = true

      Task {
         try? await Task.sleep(for: .seconds(3))
         showingPromptSaveSuccess = false
      }
   }

   private func loadPresets() {
      do {
         presets = try promptPresetStore.fetchAll()

         if let presetId = settings.selectedPresetId {
            if let preset = presets.first(where: { $0.id.uuidString == presetId }) {
               enhancementPrompt = preset.prompt
            } else {
               settings.selectedPresetId = nil
               enhancementPrompt = localizedTranscriptionPrompt(settings.aiEnhancementPrompt)
            }
         } else {
            enhancementPrompt = localizedTranscriptionPrompt(settings.aiEnhancementPrompt)
         }
      } catch {
         Log.ui.error("Failed to load presets: \(error)")
         enhancementPrompt = localizedTranscriptionPrompt(settings.aiEnhancementPrompt)
      }
   }

   private func handlePresetChange(_ presetId: String?) {
      if let presetId, let preset = presets.first(where: { $0.id.uuidString == presetId }) {
         enhancementPrompt = preset.prompt
      }
   }

   private func handlePromptChange(_ newPrompt: String) {
      // If text is modified and we have a selected preset, switch to Custom
      // unless the text matches the preset exactly (e.g. initial load)
      if let presetId = settings.selectedPresetId,
         let preset = presets.first(where: { $0.id.uuidString == presetId })
      {
         if newPrompt != preset.prompt {
            settings.selectedPresetId = nil
         }
      }
   }

   private func refreshPermissionStates() {
      let permissionManager = PermissionManager()
      accessibilityPermissionGranted = permissionManager.checkAccessibilityPermission()
   }

   private func requestAccessibilityPermissionIfNeeded() {
      guard !accessibilityPermissionRequestInFlight else { return }
      let permissionManager = PermissionManager()
      let alreadyGranted = permissionManager.checkAccessibilityPermission()
      accessibilityPermissionGranted = alreadyGranted
      guard !alreadyGranted else { return }

      accessibilityPermissionRequestInFlight = true
      _ = permissionManager.requestAccessibilityPermission(showPrompt: true)
      Task {
         try? await Task.sleep(for: .milliseconds(500))
         let granted = permissionManager.checkAccessibilityPermission()
         accessibilityPermissionGranted = granted
         accessibilityPermissionRequestInFlight = false
         if !granted {
            showAccessibilityAlert = true
         }
      }
   }
}

#Preview {
   AIEnhancementSettingsView(settings: SettingsStore())
      .padding()
      .frame(width: 500)
}

private extension AIEnhancementSettingsView {
   var promptPresetOptions: [SelectFieldOption] {
      [SelectFieldOption(id: customPromptPresetId, displayName: localized("Custom", locale: locale))]
         + presets.map {
            SelectFieldOption(
               id: $0.id.uuidString,
               displayName: $0.name
            )
         }
   }

   var promptPresetSelection: Binding<String> {
      Binding(
         get: { settings.selectedPresetId ?? customPromptPresetId },
         set: { newValue in
            settings.selectedPresetId = (newValue == customPromptPresetId) ? nil : newValue
         }
      )
   }

   var customPromptPresetId: String { "__custom__" }

   func localizedTranscriptionPrompt(_ prompt: String) -> String {
      if prompt == SettingsStore.Defaults.aiEnhancementPrompt {
         return localized("You are a text enhancement assistant. Improve the grammar, punctuation, and formatting of the provided text while preserving its original meaning and tone. Return only the enhanced text without any additional commentary.", locale: locale)
      }

      return prompt
   }

   func localizedNotePrompt(_ prompt: String) -> String {
      if prompt == SettingsStore.Defaults.noteEnhancementPrompt {
         return localized("You are a note formatting assistant. Transform the transcribed text into a well-structured note.\n\nRules:\n- Fix grammar, punctuation, and spelling errors\n- For longer content (3+ paragraphs), add markdown formatting:\n  - Use headers (## or ###) to organize sections\n  - Use bullet points or numbered lists where appropriate\n  - Use **bold** for emphasis on key terms\n- For shorter content, keep it simple with minimal formatting\n- Preserve the original meaning and tone\n- Do not add content that wasn't in the original\n- Return only the formatted note without any commentary", locale: locale)
      }

      return prompt
   }
}

extension AIModelService.AIModel: SearchableDropdownItem {
    public var displayName: String { name }

    public var searchableValues: [String] {
       [name, id, description].compactMap { $0 }
    }
}
