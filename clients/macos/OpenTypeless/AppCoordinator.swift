//
//  AppCoordinator.swift
//  OpenTypeless
//
//  Created on 2026-01-25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import AppKit
import os.log

@MainActor
@Observable
final class AppCoordinator {

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["OPENTYPELESS_TEST_MODE"] == "1"
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    // MARK: - Services
    
    let permissionManager: PermissionManager
    let audioRecorder: AudioRecorder
    let transcriptionService: TranscriptionService
    let modelManager: ModelManager
    let hotkeyManager: HotkeyManager
    let launchAtLoginManager: LaunchAtLoginManager
    let updateService: UpdateService
    let outputManager: OutputManager
    let historyStore: HistoryStore
    let settingsStore: SettingsStore
    let contextCaptureService: ContextCaptureService
    let contextEngineService: ContextEngineService
    let toastService: ToastService
    let mentionRewriteService: MentionRewriteService
    let engineProcessManager: EngineProcessManager
    let mediaPauseService: MediaPauseService
    let mediaIngestionService: MediaIngestionService
    let mediaPreparationService: MediaPreparationService
    let mediaTranscriptionState: MediaTranscriptionFeatureState

    // MARK: - UI Controllers
    
    let statusBarController: StatusBarController
    let floatingIndicatorState: FloatingIndicatorState
    let floatingIndicatorController: FloatingIndicatorController
    let pillFloatingIndicatorController: PillFloatingIndicatorController
    let floatingIndicatorPresenters: [FloatingIndicatorType: any FloatingIndicatorPresenting]
    let onboardingController: OnboardingWindowController
    let splashController: SplashWindowController
    let mainWindowController: MainWindowController
    let toastWindowController: ToastWindowController
    
    private var mediaTranscriptionTask: Task<Void, Never>?

    // MARK: - State

    private(set) var activeModelName: String?

    private var cancellables = Set<AnyCancellable>()
    private let enableSystemHooks: Bool
    private var lastObservedSettingsSnapshot: SettingsObservationSnapshot?
    private var hasRequestedAccessibilityPermissionThisLaunch = false
    private var hasShownAccessibilityFallbackAlertThisLaunch = false
    private let polishHandlers: PolishHandlers

    // MARK: - Sub-Coordinators

    let floatingIndicatorCoordinator: FloatingIndicatorCoordinator
    let hotkeyCoordinator: HotkeyCoordinator
    let engineRuntimeCoordinator: EngineRuntimeCoordinator
    let contextSessionCoordinator: ContextSessionCoordinator
    let recordingCoordinator: RecordingCoordinator

    // MARK: - Event Tap Manager

    let eventTapManager: EventTapManager
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        enableSystemHooks: Bool? = nil,
        transcriptionService: TranscriptionService? = nil,
        outputManager: OutputManager? = nil,
        engineStartupHandlers: EngineStartupHandlers? = nil,
        polishHandlers: PolishHandlers? = nil,
        toastPresenter: (any ToastPresenting)? = nil
    ) {
        self.enableSystemHooks = enableSystemHooks ?? !Self.isRunningTests
        let resolvedSettingsStore = SettingsStore()
        let resolvedToastWindowController = ToastWindowController()
        self.permissionManager = PermissionManager()
        do {
            self.audioRecorder = try AudioRecorder(permissionManager: permissionManager)
        } catch {
            Log.app.error("Failed to initialize AudioRecorder: \(error)")
            fatalError("Failed to initialize AudioRecorder: \(error)")
        }
        self.transcriptionService = transcriptionService ?? TranscriptionService(
            sttModeProvider: { [resolvedSettingsStore] in
                resolvedSettingsStore.sttMode
            },
            remoteEngineFactory: { [resolvedSettingsStore] in
                EngineTranscriptionEngine(
                    client: EngineClient(
                        host: resolvedSettingsStore.engineHost,
                        port: resolvedSettingsStore.enginePort
                    )
                )
            }
        )
        self.modelManager = ModelManager()
        self.hotkeyManager = HotkeyManager()
        self.launchAtLoginManager = LaunchAtLoginManager()
        self.updateService = UpdateService()
        self.settingsStore = resolvedSettingsStore
        let resolvedEngineStartupHandlers = engineStartupHandlers ?? EngineStartupHandlers(
            health: { [resolvedSettingsStore] in
                try await EngineClient(
                    host: resolvedSettingsStore.engineHost,
                    port: resolvedSettingsStore.enginePort
                ).health()
            },
            fetchConfig: { [resolvedSettingsStore] in
                try await EngineClient(
                    host: resolvedSettingsStore.engineHost,
                    port: resolvedSettingsStore.enginePort
                ).fetchConfig()
            },
            pushConfig: { [resolvedSettingsStore] requestBody in
                try await EngineClient(
                    host: resolvedSettingsStore.engineHost,
                    port: resolvedSettingsStore.enginePort
                ).pushConfig(requestBody)
            }
        )
        self.polishHandlers = polishHandlers ?? PolishHandlers(
            polish: { [resolvedSettingsStore] text, appContext, task, outputLanguage in
                let service = PolishService(
                    client: EngineClient(
                        host: resolvedSettingsStore.engineHost,
                        port: resolvedSettingsStore.enginePort
                    )
                )
                return try await service.polish(
                    text: text,
                    appContext: appContext,
                    task: task,
                    outputLanguage: outputLanguage
                )
            }
        )
        self.engineProcessManager = EngineProcessManager(
            configuration: EngineProcessManager.Configuration(
                customBinaryPath: resolvedSettingsStore.engineBinaryPath.isEmpty ? nil : resolvedSettingsStore.engineBinaryPath,
                host: resolvedSettingsStore.engineHost,
                port: resolvedSettingsStore.enginePort
            ),
            healthCheck: { try await resolvedEngineStartupHandlers.health() },
            pushConfig: { try await resolvedEngineStartupHandlers.pushConfig($0) },
            configProvider: { [resolvedSettingsStore] in
                guard let llmConfig = resolvedSettingsStore.currentEngineLLMProviderConfiguration() else {
                    return nil
                }
                let sttConfig = resolvedSettingsStore.sttMode == .remote
                    ? resolvedSettingsStore.currentEngineSTTProviderConfiguration()
                    : nil
                return ConfigRequest(stt: sttConfig, llm: llmConfig, defaultLanguage: nil)
            }
        )
        self.engineProcessManager.onStatusChange = { [resolvedSettingsStore] state in
            resolvedSettingsStore.updateEngineRuntimeState(state)
        }

        self.audioRecorder.setPreferredInputDeviceUID(settingsStore.selectedInputDeviceUID)

        let initialOutputMode: OutputMode = settingsStore.outputMode == "directInsert" ? .directInsert : .clipboard
        self.outputManager = outputManager ?? OutputManager(outputMode: initialOutputMode)
        self.historyStore = HistoryStore(modelContext: modelContext)
        self.contextCaptureService = ContextCaptureService()
        self.contextEngineService = ContextEngineService()
        self.toastWindowController = resolvedToastWindowController
        self.toastService = ToastService(presenter: toastPresenter ?? resolvedToastWindowController)
        self.mentionRewriteService = MentionRewriteService()
        self.mediaPauseService = MediaPauseService()
        self.mediaIngestionService = MediaIngestionService()
        self.mediaPreparationService = MediaPreparationService()
        self.mediaTranscriptionState = MediaTranscriptionFeatureState()

        self.statusBarController = StatusBarController(
            audioRecorder: audioRecorder,
            settingsStore: settingsStore
        )
        self.floatingIndicatorState = FloatingIndicatorState()
        self.floatingIndicatorController = FloatingIndicatorController(state: floatingIndicatorState)
        self.pillFloatingIndicatorController = PillFloatingIndicatorController(
            state: floatingIndicatorState,
            settingsStore: settingsStore
        )
        self.floatingIndicatorPresenters = [
            .notch: floatingIndicatorController,
            .pill: pillFloatingIndicatorController
        ]
        self.onboardingController = OnboardingWindowController()
        let splashState = SplashScreenState()
        self.splashController = SplashWindowController(state: splashState)
        self.mainWindowController = MainWindowController()
        self.eventTapManager = EventTapManager(enableSystemHooks: self.enableSystemHooks)
        self.floatingIndicatorCoordinator = FloatingIndicatorCoordinator(
            settingsStore: resolvedSettingsStore,
            floatingIndicatorPresenters: self.floatingIndicatorPresenters
        )
        self.hotkeyCoordinator = HotkeyCoordinator(
            hotkeyManager: self.hotkeyManager,
            settingsStore: resolvedSettingsStore,
            toastService: self.toastService
        )
        self.engineRuntimeCoordinator = EngineRuntimeCoordinator(
            settingsStore: resolvedSettingsStore,
            engineStartupHandlers: resolvedEngineStartupHandlers,
            toastService: self.toastService
        )
        self.contextSessionCoordinator = ContextSessionCoordinator(
            settingsStore: resolvedSettingsStore,
            contextEngineService: self.contextEngineService,
            contextCaptureService: self.contextCaptureService,
            mentionRewriteService: self.mentionRewriteService,
            permissionManager: self.permissionManager
        )
        self.recordingCoordinator = RecordingCoordinator(
            audioRecorder: self.audioRecorder,
            transcriptionService: self.transcriptionService,
            outputManager: self.outputManager,
            settingsStore: resolvedSettingsStore,
            historyStore: self.historyStore,
            polishHandlers: self.polishHandlers,
            toastService: self.toastService,
            mediaPauseService: self.mediaPauseService,
            contextEngineService: self.contextEngineService,
            mentionRewriteService: self.mentionRewriteService,
            permissionManager: self.permissionManager,
            floatingIndicatorCoordinator: self.floatingIndicatorCoordinator,
            contextSessionCoordinator: self.contextSessionCoordinator,
            engineRuntimeCoordinator: self.engineRuntimeCoordinator
        )
        self.mainWindowController.setModelContainer(modelContainer)
        self.mainWindowController.configureTranscribeFeature(
            state: mediaTranscriptionState,
            modelManager: modelManager,
            settingsStore: settingsStore,
            onImportMediaFiles: { [weak self] urls in
                self?.handleImportMediaFiles(urls)
            },
            onSubmitMediaLink: { [weak self] link in
                self?.handleSubmitMediaLink(link)
            },
            onDownloadDiarizationModel: { [weak self] in
                self?.handleDownloadDiarizationModel()
            }
        )

        self.statusBarController.onToggleRecording = { [weak self] in
            await self?.recordingCoordinator.handleToggleRecording(source: .statusBarMenu)
        }

        self.statusBarController.onCopyLastTranscript = { [weak self] in
            await self?.recordingCoordinator.handleTranslateToggle()
        }

        self.statusBarController.onPasteLastTranscript = { [weak self] in
            await self?.handlePasteLastTranscript()
        }

        self.statusBarController.onExportLastTranscript = { [weak self] in
            await self?.handleExportLastTranscript()
        }

        self.statusBarController.onClearAudioBuffer = { [weak self] in
            await self?.handleClearAudioBuffer()
        }

        self.statusBarController.onCancelOperation = { [weak self] in
            await self?.handleCancelOperation()
        }

        self.statusBarController.onToggleOutputMode = { [weak self] in
            self?.handleToggleOutputMode()
        }

        self.statusBarController.onToggleFloatingIndicator = { [weak self] in
            self?.handleToggleFloatingIndicator()
        }

        self.statusBarController.onToggleLaunchAtLogin = { [weak self] in
            self?.handleToggleLaunchAtLogin()
        }

        self.statusBarController.onOpenHistory = { [weak self] in
            self?.handleOpenHistory()
        }


        self.statusBarController.onReportIssue = { [weak self] in
            self?.handleReportIssue()
        }

        self.statusBarController.onSelectInputDeviceUID = { [weak self] uid in
            self?.handleSelectInputDeviceUID(uid)
        }

        self.statusBarController.onSelectLanguage = { [weak self] language in
            self?.handleSelectLanguage(language)
        }

        self.statusBarController.onShowApp = { [weak self] in
            self?.handleShowApp()
        }

        self.statusBarController.onSelectModel = { [weak self] modelName in
            Task { @MainActor in
                await self?.switchToModel(named: modelName)
            }
        }

        self.statusBarController.onMenuWillOpen = { [weak self] in
            await self?.refreshStatusBarModelMenu()
        }

        self.statusBarController.onCheckForUpdates = { [weak self] in
            self?.handleCheckForUpdates()
        }

        self.statusBarController.setMainWindowController(mainWindowController)
        
        self.audioRecorder.onAudioLevel = { [weak self] level in
            self?.floatingIndicatorState.updateAudioLevel(level)
        }

        let floatingIndicatorActions = FloatingIndicatorActions(
            onStartRecording: { [weak self] type in
                Task { @MainActor in
                    await self?.recordingCoordinator.handleToggleRecording(source: self?.floatingIndicatorCoordinator.recordingTriggerSourceForIndicatorStart(type) ?? .floatingIndicatorStart)
                }
            },
            onStopRecording: { [weak self] type in
                Task { @MainActor in
                    await self?.recordingCoordinator.handleToggleRecording(source: self?.floatingIndicatorCoordinator.recordingTriggerSourceForIndicatorStop(type) ?? .floatingIndicatorStop)
                }
            },
            onCancelRecording: { [weak self] in
                Task { @MainActor in
                    await self?.handleCancelOperation()
                }
            },
            onHideForOneHour: { [weak self] in
                self?.floatingIndicatorCoordinator.handleHideFloatingIndicatorForOneHour()
            },
            onReportIssue: { [weak self] in
                self?.handleReportIssue()
            },
            onGoToSettings: { [weak self] in
                self?.statusBarController.showSettings(tab: .general)
            },
            onViewTranscriptHistory: { [weak self] in
                self?.handleOpenHistory()
            },
            onPasteLastTranscript: { [weak self] in
                await self?.handlePasteLastTranscript()
            },
            onSelectInputDeviceUID: { [weak self] uid in
                self?.handleSelectInputDeviceUID(uid)
            },
            onSelectLanguage: { [weak self] language in
                self?.handleSelectLanguage(language)
            },
            availableInputDevicesProvider: {
                AudioDeviceManager.inputDevices().map { (uid: $0.uid, displayName: $0.displayName) }
            },
            selectedInputDeviceUIDProvider: { [weak self] in
                self?.settingsStore.selectedInputDeviceUID ?? ""
            },
            selectedLanguageProvider: { [weak self] in
                self?.settingsStore.selectedAppLanguage ?? .automatic
            },
            anchorProvider: { [weak self] in
                self?.contextEngineService.captureFocusedElementAnchorRect()
            }
        )

        for presenter in self.floatingIndicatorPresenters.values {
            presenter.configure(actions: floatingIndicatorActions)
        }
        self.floatingIndicatorState.updateHotkeys(
            toggleHotkey: settingsStore.toggleHotkey,
            pushToTalkHotkey: settingsStore.pushToTalkHotkey
        )

        self.hotkeyCoordinator.onToggleRecording = { [weak self] source in
            await self?.recordingCoordinator.handleToggleRecording(source: source)
        }
        self.hotkeyCoordinator.onPushToTalkStart = { [weak self] in
            await self?.recordingCoordinator.handlePushToTalkStart()
        }
        self.hotkeyCoordinator.onPushToTalkEnd = { [weak self] in
            await self?.recordingCoordinator.handlePushToTalkEnd()
        }
        self.hotkeyCoordinator.onTranslateToggle = { [weak self] in
            await self?.recordingCoordinator.handleTranslateToggle()
        }

        self.eventTapManager.onCancelCurrentOperation = { [weak self] in
            self?.recordingCoordinator.cancelCurrentOperation()
        }
        self.eventTapManager.onResetProcessingState = { [weak self] in
            self?.recordingCoordinator.resetProcessingState()
        }
        self.eventTapManager.onNonEscapeKeyDown = { [weak self] in
            self?.contextSessionCoordinator.scheduleFocusOrWindowContextRefreshIfNeeded()
        }
        self.eventTapManager.onModifierFlagsChanged = { [weak self] event in
            self?.hotkeyManager.handleModifierFlagsChanged(event: event)
        }
        self.eventTapManager.isRecordingProvider = { [weak self] in
            self?.recordingCoordinator.isRecording ?? false
        }
        self.eventTapManager.isProcessingProvider = { [weak self] in
            self?.recordingCoordinator.isProcessing ?? false
        }
        self.eventTapManager.isFloatingIndicatorEnabledProvider = { [weak self] in
            self?.settingsStore.floatingIndicatorEnabled ?? false
        }
        self.eventTapManager.showEscapePrimed = { [weak self] in
            self?.floatingIndicatorState.showEscapePrimed()
        }
        self.eventTapManager.clearEscapePrimed = { [weak self] in
            self?.floatingIndicatorState.clearEscapePrimed()
        }

        self.contextSessionCoordinator.isRecordingProvider = { [weak self] in
            self?.recordingCoordinator.isRecording ?? false
        }
        self.contextSessionCoordinator.recordingStartTimeProvider = { [weak self] in
            self?.recordingCoordinator.recordingStartTime
        }

        self.recordingCoordinator.onStatusBarRecording = { [weak self] in
            self?.statusBarController.setRecordingState()
        }
        self.recordingCoordinator.onStatusBarProcessing = { [weak self] in
            self?.statusBarController.setProcessingState()
        }
        self.recordingCoordinator.onStatusBarIdle = { [weak self] in
            self?.statusBarController.setIdleState()
        }
        self.recordingCoordinator.onUpdateMenuState = { [weak self] in
            self?.statusBarController.updateMenuState()
        }
        self.recordingCoordinator.onUpdateRecentTranscriptsMenu = { [weak self] in
            self?.updateRecentTranscriptsMenu()
        }
        self.recordingCoordinator.onEnsureAccessibilityForDirectInsert = { [weak self] trigger, showFallbackAlert in
            self?.ensureAccessibilityPermissionForDirectInsert(trigger: trigger, showFallbackAlert: showFallbackAlert)
        }
        self.recordingCoordinator.onEnsureGlobalKeyMonitors = { [weak self] in
            self?.ensureGlobalKeyMonitorsIfPossible()
        }
        self.recordingCoordinator.onCancelMediaTranscription = { [weak self] in
            guard let self else { return }
            self.mediaTranscriptionTask?.cancel()
            self.mediaTranscriptionTask = nil
            self.mediaTranscriptionState.showLibrary()
            self.mediaTranscriptionState.libraryMessage = "Transcription canceled."
            self.mediaTranscriptionState.clearCurrentJob()
        }

        self.lastObservedSettingsSnapshot = currentSettingsObservationSnapshot()
        if self.enableSystemHooks {
            hotkeyCoordinator.setupHotkeys()
            eventTapManager.setupEscapeKeyMonitor()
            eventTapManager.setupModifierKeyMonitor()
        } else {
            Log.app.debug("Skipping global hotkey and key monitor setup in test environment")
        }
        observeSettings()
        setupNotifications()
        Log.boot.info("AppCoordinator init finished enableSystemHooks=\(self.enableSystemHooks)")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .switchModel,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let modelName = notification.userInfo?["modelName"] as? String else {
                return
            }
            Task {
                await self.switchToModel(named: modelName)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .requestActiveModel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let activeModel = self.activeModelName else { return }
                NotificationCenter.default.post(
                    name: .modelActiveChanged,
                    object: nil,
                    userInfo: ["modelName": activeModel]
                )
            }
        }

        NotificationCenter.default.addObserver(
            forName: .rerunOnboarding,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showOnboarding()
            }
        }
    }

    // MARK: - Lifecycle

    func start() async {
        Log.boot.info("AppCoordinator.start() entered hasCompletedOnboarding=\(settingsStore.hasCompletedOnboarding) selectedModel=\(settingsStore.selectedModel)")

        if !settingsStore.hasCompletedOnboarding {
            // During onboarding, start Engine in background (non-blocking)
            Task { @MainActor in
                await engineProcessManager.start()
            }
            Log.boot.info("Taking onboarding path (skipping splash and normal operation until complete)")
            showOnboarding()
            return
        }

        // Normal startup: await Engine process before proceeding to avoid race conditions
        await engineProcessManager.start()

        Log.boot.info("Taking normal startup path: splash, startNormalOperation")

        splashController.show()

        await startNormalOperation()

        splashController.dismiss { [weak self] in
            self?.mainWindowController.show()
        }
        Log.boot.info("AppCoordinator.start() finished normal path")
    }
    
    private func showOnboarding() {
        Log.boot.info("showOnboarding: presenting onboarding window")
        onboardingController.showOnboarding(
            settings: settingsStore,
            permissionManager: permissionManager,
            engineHealthCheck: { [weak self] in
                guard let self else { return false }
                do {
                    _ = try await self.engineRuntimeCoordinator.engineStartupHandlers.health()
                    return true
                } catch {
                    return false
                }
            },
            onComplete: { [weak self] in
                Task { @MainActor in
                    await self?.finishPostOnboardingSetup()
                    self?.mainWindowController.show()
                    self?.showWelcomePopoverAfterDelay()
                }
            }
        )
    }
    
    private func showWelcomePopoverAfterDelay() {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            statusBarController.showWelcomePopover()
        }
    }
    
    private func finishPostOnboardingSetup() async {
        Log.boot.info("finishPostOnboardingSetup begin")
        hotkeyCoordinator.registerHotkeysFromSettings()

        ensureAccessibilityPermissionForDirectInsert(trigger: "post-onboarding", showFallbackAlert: false)
        await engineRuntimeCoordinator.syncEngineConfigurationOnStartup()
        contextSessionCoordinator.updateVibeRuntimeStateFromSettings()
        Log.boot.info("finishPostOnboardingSetup complete")
    }

    private func refreshStatusBarModelMenu() async {
        let downloadedModels = await modelManager.getDownloadedModels()
        let mappedModels = downloadedModels.map { (name: $0.name, displayName: $0.displayName) }
        statusBarController.updateSwitchableModels(mappedModels)
    }

    private func setActiveModel(_ modelName: String) {
        activeModelName = modelName
        statusBarController.updateSelectedModel(modelName)
        NotificationCenter.default.post(
            name: .modelActiveChanged,
            object: nil,
            userInfo: ["modelName": modelName]
        )
    }

    private func loadAndActivateModel(
        named modelName: String,
        provider: ModelManager.ModelProvider
    ) async throws {
        try await transcriptionService.loadModel(modelName: modelName, provider: provider)
        setActiveModel(modelName)
    }

    private func attemptWhisperModelRepairAndReload(
        modelName: String,
        displayName: String
    ) async throws {
        Log.boot.info("attemptWhisperModelRepairAndReload begin model=\(modelName)")
        Log.model.warning("Selected Whisper model failed to load, attempting repair for \(modelName)")

        do {
            try await modelManager.deleteModel(named: modelName)
        } catch ModelManager.ModelError.modelNotFound {
            Log.model.debug("Model \(modelName) was not present when starting repair")
        }

        splashController.setDownloading("Repairing \(displayName)...")
        try await modelManager.downloadModel(named: modelName) { [weak self] progress in
            Task { @MainActor in
                self?.splashController.updateProgress(progress)
            }
        }

        splashController.setLoading("Loading \(displayName)...")
        try await loadAndActivateModel(named: modelName, provider: .whisperKit)
        Log.boot.info("attemptWhisperModelRepairAndReload finished OK model=\(modelName)")
    }

    private func handleModelLoadError(_ error: Error, context: String) {
        self.recordingCoordinator.error = error
        Log.app.error("\(context): \(error)")

        let errorMessage = (error as? LocalizedError)?.errorDescription ?? ""
        if errorMessage.contains("timed out") {
            AlertManager.shared.showModelTimeoutAlert()
        }
    }
    
    private func startNormalOperation() async {
        Log.boot.info("startNormalOperation begin")
        // Sync launch at login state on startup
        let actualLaunchAtLoginState = launchAtLoginManager.isEnabled
        if settingsStore.launchAtLogin != actualLaunchAtLoginState {
            settingsStore.launchAtLogin = actualLaunchAtLoginState
            Log.app.info("Synced launch at login state: \(actualLaunchAtLoginState)")
        }

        let micStatus = permissionManager.checkPermissionStatus()
        if micStatus == .denied || micStatus == .restricted {
            Log.app.warning("Microphone permission denied - recording will not work")
            AlertManager.shared.showMicrophonePermissionAlert()
        } else if micStatus == .notDetermined {
            Log.app.info("Microphone permission not determined at launch; request deferred until recording starts")
        }

        ensureAccessibilityPermissionForDirectInsert(trigger: "startup", showFallbackAlert: false)
        await engineRuntimeCoordinator.syncEngineConfigurationOnStartup()

        if settingsStore.sttMode == .remote {
            // Remote STT: skip local model loading, initialize remote transcription engine
            Log.boot.info("Remote STT mode configured, skipping local model load")
            splashController.setLoading("Connecting to Engine...")
            do {
                try await transcriptionService.loadModel(modelName: "remote", provider: .whisperKit)
                Log.model.info("Remote transcription engine initialized")
            } catch {
                Log.model.warning("Failed to initialize remote transcription engine: \(error)")
            }
        } else {
            // Local STT: load WhisperKit model as before
            var modelName = settingsStore.selectedModel

            if !modelManager.availableModels.contains(where: { $0.name == modelName }) {
                Log.model.warning("Selected model \(modelName) is not recognized, resetting to default")
                modelName = SettingsStore.Defaults.selectedModel
                settingsStore.selectedModel = modelName
            }

            let selectedModel = modelManager.availableModels.first(where: { $0.name == modelName })
            let selectedProvider = selectedModel?.provider ?? .whisperKit
            let selectedDisplayName = selectedModel?.displayName ?? modelName

            await modelManager.refreshDownloadedModels()
            let modelExists = modelManager.isModelDownloaded(modelName)

            if modelExists {
                splashController.setLoading("Loading model...")
                Log.model.info("Model \(modelName) found, loading...")
                do {
                    try await loadAndActivateModel(named: modelName, provider: selectedProvider)
                    Log.model.info("Model loaded successfully")
                } catch {
                    if selectedProvider == .whisperKit {
                        do {
                            try await attemptWhisperModelRepairAndReload(
                                modelName: modelName,
                                displayName: selectedDisplayName
                            )
                            Log.model.info("Model repaired and loaded successfully")
                        } catch {
                            handleModelLoadError(error, context: "Failed to repair transcription model")
                        }
                    } else {
                        handleModelLoadError(error, context: "Failed to load transcription model")
                    }
                }
            } else {
                // Model missing - check if any model is available for fallback
                let downloadedModels = await modelManager.getDownloadedModels()

                if let fallbackModel = downloadedModels.first {
                    Log.model.info("Selected model \(modelName) not found, falling back to \(fallbackModel.name)")
                    splashController.setLoading("Using \(fallbackModel.displayName)...")
                    settingsStore.selectedModel = fallbackModel.name
                    do {
                        try await loadAndActivateModel(named: fallbackModel.name, provider: fallbackModel.provider)
                        Log.model.info("Fallback model loaded successfully")
                    } catch {
                        handleModelLoadError(error, context: "Failed to load fallback model")
                    }
                } else {
                    // No models available - download the selected one
                    splashController.setDownloading("Downloading \(modelName)...")
                    Log.model.info("Model \(modelName) not found, downloading...")

                    do {
                        try await modelManager.downloadModel(named: modelName) { [weak self] progress in
                            Task { @MainActor in
                                self?.splashController.updateProgress(progress)
                            }
                        }
                        splashController.setLoading("Loading model...")
                        Log.model.info("Model downloaded, loading...")
                        try await loadAndActivateModel(named: modelName, provider: selectedProvider)
                        Log.model.info("Model loaded successfully")
                    } catch {
                        handleModelLoadError(error, context: "Failed to download/load model")
                    }
                }
            }
        }

        // Load recent transcripts for the menu
        updateRecentTranscriptsMenu()
        await refreshStatusBarModelMenu()
        
        floatingIndicatorCoordinator.updateFloatingIndicatorVisibility()

        contextSessionCoordinator.updateVibeRuntimeStateFromSettings()
        Log.boot.info("startNormalOperation complete")
    }

    // Hotkey methods live in HotkeyCoordinator
    
    // MARK: - Settings Observation

    private func currentEngineObservationSnapshot() -> EngineSettingsSnapshot {
        EngineSettingsSnapshot(
            host: settingsStore.engineHost,
            port: settingsStore.enginePort,
            sttMode: settingsStore.sttMode,
            stt: EngineProviderSettingsSnapshot(
                provider: settingsStore.selectedEngineSTTProvider.rawValue,
                apiBase: settingsStore.engineSTTAPIBase.trimmingCharacters(in: .whitespacesAndNewlines),
                model: settingsStore.engineSTTModel.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: settingsStore.configuredEngineSTTAPIKey()
            ),
            llm: EngineProviderSettingsSnapshot(
                provider: settingsStore.selectedEngineLLMProvider.rawValue,
                apiBase: settingsStore.engineLLMAPIBase.trimmingCharacters(in: .whitespacesAndNewlines),
                model: settingsStore.engineLLMModel.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: settingsStore.configuredEngineLLMAPIKey()
            )
        )
    }
    
    private func currentSettingsObservationSnapshot() -> SettingsObservationSnapshot {
        SettingsObservationSnapshot(
            outputMode: settingsStore.outputMode,
            selectedInputDeviceUID: settingsStore.selectedInputDeviceUID,
            selectedAppLanguage: settingsStore.selectedAppLanguage,
            floatingIndicatorEnabled: settingsStore.floatingIndicatorEnabled,
            floatingIndicatorType: settingsStore.selectedFloatingIndicatorType,
            aiEnhancementEnabled: settingsStore.aiEnhancementEnabled,
            enableUIContext: settingsStore.enableUIContext,
            vibeLiveSessionEnabled: settingsStore.vibeLiveSessionEnabled,
            hotkeys: HotkeySettingsSnapshot(
                hasCompletedOnboarding: settingsStore.hasCompletedOnboarding,
                pushToTalk: HotkeyBindingSnapshot(
                    hotkey: settingsStore.pushToTalkHotkey,
                    keyCode: settingsStore.pushToTalkHotkeyCode,
                    modifiers: settingsStore.pushToTalkHotkeyModifiers
                ),
                toggle: HotkeyBindingSnapshot(
                    hotkey: settingsStore.toggleHotkey,
                    keyCode: settingsStore.toggleHotkeyCode,
                    modifiers: settingsStore.toggleHotkeyModifiers
                ),
                translate: HotkeyBindingSnapshot(
                    hotkey: settingsStore.translateHotkey,
                    keyCode: settingsStore.translateHotkeyCode,
                    modifiers: settingsStore.translateHotkeyModifiers
                )
            ),
            engine: currentEngineObservationSnapshot(),
            engineRuntimeRecheckSequence: settingsStore.engineRuntimeRecheckSequence
        )
    }
    private func observeSettings() {
        lastObservedSettingsSnapshot = currentSettingsObservationSnapshot()
        settingsStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    guard !self.settingsStore.isApplyingHotkeyUpdate else { return }

                    let snapshot = self.currentSettingsObservationSnapshot()
                    let previousSnapshot = self.lastObservedSettingsSnapshot ?? snapshot
                    self.lastObservedSettingsSnapshot = snapshot

                    if previousSnapshot.outputMode != snapshot.outputMode {
                        let mode: OutputMode = snapshot.outputMode == "clipboard" ? .clipboard : .directInsert
                        self.outputManager.setOutputMode(mode)
                        if mode == .directInsert {
                            self.ensureAccessibilityPermissionForDirectInsert(trigger: "settings-change", showFallbackAlert: true)
                        }
                    }

                    if previousSnapshot.selectedInputDeviceUID != snapshot.selectedInputDeviceUID {
                        self.audioRecorder.setPreferredInputDeviceUID(snapshot.selectedInputDeviceUID)
                    }

                    if previousSnapshot.floatingIndicatorEnabled != snapshot.floatingIndicatorEnabled
                        || previousSnapshot.floatingIndicatorType != snapshot.floatingIndicatorType {
                        if (!previousSnapshot.floatingIndicatorEnabled && snapshot.floatingIndicatorEnabled)
                            || previousSnapshot.floatingIndicatorType != snapshot.floatingIndicatorType {
                            self.floatingIndicatorCoordinator.clearFloatingIndicatorTemporaryHiddenState()
                        }
                        self.floatingIndicatorCoordinator.updateFloatingIndicatorVisibility(
                            isRecording: self.recordingCoordinator.isRecording,
                            isProcessing: self.recordingCoordinator.isProcessing,
                            previousType: previousSnapshot.floatingIndicatorType
                        )
                    }

                    if previousSnapshot.hotkeys != snapshot.hotkeys {
                        self.hotkeyCoordinator.registerHotkeysFromSettings()
                        self.floatingIndicatorState.updateHotkeys(
                            toggleHotkey: self.settingsStore.toggleHotkey,
                            pushToTalkHotkey: self.settingsStore.pushToTalkHotkey
                        )
                    }

                    if previousSnapshot.selectedAppLanguage != snapshot.selectedAppLanguage {
                        self.statusBarController.reloadLocalizedStrings()
                        self.pillFloatingIndicatorController.reloadLocalizedStrings()
                    }

                    if previousSnapshot.engineRuntimeRecheckSequence != snapshot.engineRuntimeRecheckSequence {
                        self.engineRuntimeCoordinator.requestManualEngineRuntimeRecheck()
                    } else if previousSnapshot.engine != snapshot.engine {
                        self.engineRuntimeCoordinator.scheduleEngineConfigurationSync()
                    }

                    self.statusBarController.updateDynamicItems()
                    if self.recordingCoordinator.isRecording {
                        if self.contextSessionCoordinator.shouldRunLiveContextSession() {
                            self.contextSessionCoordinator.startLiveContextSessionIfNeeded(initialSnapshot: self.contextSessionCoordinator.capturedSnapshot)
                        } else {
                            self.contextSessionCoordinator.stopLiveContextSession()
                        }
                    } else if previousSnapshot.aiEnhancementEnabled != snapshot.aiEnhancementEnabled
                        || previousSnapshot.enableUIContext != snapshot.enableUIContext
                        || previousSnapshot.vibeLiveSessionEnabled != snapshot.vibeLiveSessionEnabled {
                        self.contextSessionCoordinator.updateVibeRuntimeStateFromSettings()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Recording entry points and lifecycle are in RecordingCoordinator

    private func handlePasteLastTranscript() async {
        do {
            let records = try historyStore.fetch(limit: 1)
            guard let lastRecord = records.first else {
                Log.app.warning("No transcripts to paste")
                return
            }

            if permissionManager.checkAccessibilityPermission() {
                do {
                    try await outputManager.pasteText(lastRecord.text)
                    Log.output.info("Pasted last transcript into active app")
                    return
                } catch {
                    Log.output.error("Failed to paste last transcript directly: \(error)")
                }
            }

            try outputManager.copyToClipboard(lastRecord.text)
            Log.output.info("Copied last transcript to clipboard (paste fallback)")
        } catch {
            Log.output.error("Failed to prepare last transcript for paste: \(error)")
        }
    }

    // MARK: - Export Last Transcript

    private func handleExportLastTranscript() async {
        do {
            let records = try historyStore.fetch(limit: 1)
            guard let lastRecord = records.first else {
                Log.app.warning("No transcripts to export")
                return
            }

            await MainActor.run {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.plainText]
                savePanel.nameFieldStringValue = "transcript.txt"
                savePanel.title = "Export Transcript"

                guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

                do {
                    try lastRecord.text.write(to: url, atomically: true, encoding: .utf8)
                    Log.app.info("Exported transcript to \(url.lastPathComponent)")
                } catch {
                    Log.app.error("Failed to export transcript: \(error)")
                }
            }
        } catch {
            Log.app.error("Failed to fetch transcript for export: \(error)")
        }
    }

    // MARK: - Media Transcription

    private func handleImportMediaFiles(_ urls: [URL]) {
        guard let firstURL = urls.first else { return }
        startMediaTranscriptionTask(from: .file(firstURL))
    }

    private func handleSubmitMediaLink(_ link: String) {
        startMediaTranscriptionTask(from: .link(link))
    }

    private func handleDownloadDiarizationModel() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.modelManager.downloadFeatureModel(.diarization)
                self.mediaTranscriptionState.setupIssue = nil
                self.mediaTranscriptionState.libraryMessage = "Speaker diarization is ready."
            } catch {
                self.mediaTranscriptionState.setSetupIssue(error.localizedDescription)
            }
        }
    }

    private func startMediaTranscriptionTask(from request: MediaTranscriptionRequest) {
        guard mediaTranscriptionTask == nil else {
            mediaTranscriptionState.libraryMessage = "Another transcription is already in progress."
            return
        }

        mediaTranscriptionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performMediaTranscription(request)
            self.mediaTranscriptionTask = nil
        }
    }

    private func performMediaTranscription(_ request: MediaTranscriptionRequest) async {
        guard !recordingCoordinator.isRecording && !recordingCoordinator.isProcessing else {
            mediaTranscriptionState.libraryMessage = "Finish the active transcription before starting another one."
            return
        }

        await modelManager.refreshDownloadedFeatureModels()
        guard modelManager.isFeatureModelDownloaded(.diarization) else {
            mediaTranscriptionState.setSetupIssue("Download the speaker diarization model before starting media transcription.")
            return
        }

        let job = MediaTranscriptionJobState(
            request: request,
            destinationFolderID: mediaTranscriptionState.selectedFolderID,
            stage: request.sourceKind == .webLink ? .preflight : .importing,
            progress: nil,
            detail: request.sourceKind == .webLink ? "Checking yt-dlp and ffmpeg" : "Importing local media"
        )

        mediaTranscriptionState.beginJob(job)
        mainWindowController.showTranscribe()

        recordingCoordinator.isProcessing = true
        statusBarController.setProcessingState()
        statusBarController.updateMenuState()
        floatingIndicatorCoordinator.startProcessingIndicatorSession()

        var didResetProcessingState = false

        defer {
            if !didResetProcessingState {
                recordingCoordinator.resetProcessingState()
            }
        }

        do {
            let managedAsset = try await mediaIngestionService.ingest(
                request: request,
                jobID: job.id,
                progressHandler: { [weak self] progress, detail in
                    guard let self else { return }
                    let stage: MediaTranscriptionStage = request.sourceKind == .webLink ? .downloading : .importing
                    self.mediaTranscriptionState.updateJob(
                        stage: stage,
                        progress: progress,
                        detail: detail,
                        errorMessage: nil
                    )
                }
            )

            try Task.checkCancellation()

            mediaTranscriptionState.updateJob(
                stage: .preparingAudio,
                progress: nil,
                detail: "Preparing audio for transcription",
                errorMessage: nil
            )
            let preparedAudio = try await mediaPreparationService.prepareAudio(from: managedAsset.mediaURL)

            try Task.checkCancellation()

            mediaTranscriptionState.updateJob(
                stage: .transcribing,
                progress: nil,
                detail: "Running diarization and transcription",
                errorMessage: nil
            )

            let transcriptionOutput = try await transcriptionService.transcribe(
                audioData: preparedAudio.audioData,
                diarizationEnabled: true,
                options: TranscriptionOptions(language: .automatic)
            )
            let diarizationSegmentsJSON = recordingCoordinator.encodeDiarizationSegmentsJSON(transcriptionOutput.diarizedSegments)

            try Task.checkCancellation()

            mediaTranscriptionState.updateJob(
                stage: .saving,
                progress: nil,
                detail: "Saving transcript to history",
                errorMessage: nil
            )

            let finalText = RecordingCoordinator.normalizedTranscriptionText(transcriptionOutput.text)
            guard !RecordingCoordinator.isTranscriptionEffectivelyEmpty(finalText) else {
                throw MediaPreparationError.readFailed("No speech could be transcribed from this media.")
            }

            let record = try historyStore.save(
                text: finalText,
                originalText: nil,
                duration: preparedAudio.duration,
                modelUsed: settingsStore.selectedModel,
                enhancedWith: nil,
                diarizationSegmentsJSON: diarizationSegmentsJSON,
                sourceKind: managedAsset.sourceKind,
                sourceDisplayName: managedAsset.displayName,
                originalSourceURL: managedAsset.originalSourceURL,
                managedMediaPath: managedAsset.mediaURL.path,
                thumbnailPath: managedAsset.thumbnailURL?.path,
                folderID: job.destinationFolderID
            )
            updateRecentTranscriptsMenu()

            let shouldNavigateToDetail = mediaTranscriptionState.route == .processing(job.id)
            recordingCoordinator.resetProcessingState()
            didResetProcessingState = true
            mediaTranscriptionState.completeCurrentJob(with: record.id, shouldNavigateToDetail: shouldNavigateToDetail)
        } catch is CancellationError {
            recordingCoordinator.resetProcessingState()
            didResetProcessingState = true
            mediaTranscriptionState.showLibrary()
            mediaTranscriptionState.libraryMessage = "Transcription canceled."
            mediaTranscriptionState.clearCurrentJob()
        } catch let error as MediaIngestionError {
            Log.app.error("Media ingestion failed: \(error.localizedDescription)")
            recordingCoordinator.resetProcessingState()
            didResetProcessingState = true
            mediaTranscriptionState.clearCurrentJob()
            if case .toolingUnavailable(let message) = error {
                mediaTranscriptionState.setSetupIssue(message)
            } else {
                mediaTranscriptionState.libraryMessage = error.localizedDescription
            }
        } catch {
            Log.app.error("Media transcription failed: \(error)")
            recordingCoordinator.resetProcessingState()
            didResetProcessingState = true
            let shouldReturnToLibrary = mediaTranscriptionState.route != .processing(job.id)
            mediaTranscriptionState.failCurrentJob(error.localizedDescription, returnToLibrary: shouldReturnToLibrary)
        }
    }

    // MARK: - Clear Audio Buffer

    private func handleClearAudioBuffer() async {
        guard recordingCoordinator.isRecording else {
            floatingIndicatorCoordinator.finishIndicatorSession()
            return
        }

        Log.app.info("Clearing audio buffer")
        audioRecorder.cancelRecording()
        if recordingCoordinator.isStreamingTranscriptionSessionActive {
            await recordingCoordinator.cancelStreamingSession(preserveInsertedText: true)
        } else {
            recordingCoordinator.clearStreamingSessionBindings(cancelPendingWork: true)
        }
        mediaPauseService.endRecordingSession()
        recordingCoordinator.isRecording = false
        recordingCoordinator.recordingStartTime = nil
        contextSessionCoordinator.stopLiveContextSession()
        contextSessionCoordinator.updateVibeRuntimeStateFromSettings()

        statusBarController.setIdleState()

        floatingIndicatorCoordinator.finishIndicatorSession()
    }

    // MARK: - Cancel Operation

    private func handleCancelOperation() async {
        recordingCoordinator.cancelCurrentOperation()
    }

    // MARK: - Toggle Output Mode

    private func handleToggleOutputMode() {
        let newMode = settingsStore.outputMode == "clipboard" ? "directInsert" : "clipboard"
        settingsStore.outputMode = newMode
        Log.app.info("Output mode changed to: \(newMode)")
    }

    private func ensureAccessibilityPermissionForDirectInsert(trigger: String, showFallbackAlert: Bool) {
        guard outputManager.outputMode == .directInsert else { return }

        let hasPermission = permissionManager.checkAccessibilityPermission()
        if hasPermission {
            hasShownAccessibilityFallbackAlertThisLaunch = false
            ensureGlobalKeyMonitorsIfPossible()
            return
        }

        if !hasRequestedAccessibilityPermissionThisLaunch {
            hasRequestedAccessibilityPermissionThisLaunch = true

            let grantedImmediately = permissionManager.requestAccessibilityPermission(showPrompt: true)
            Log.app.info("Requested Accessibility permission (trigger=\(trigger), grantedImmediately=\(grantedImmediately))")

            permissionManager.refreshAccessibilityPermissionStatus()
        }

        let hasPermissionAfterRequest = permissionManager.checkAccessibilityPermission()
        if hasPermissionAfterRequest {
            hasShownAccessibilityFallbackAlertThisLaunch = false
            ensureGlobalKeyMonitorsIfPossible()
            return
        }

        Log.app.info("Accessibility permission not granted - direct insert will use clipboard fallback")

        if showFallbackAlert && !hasShownAccessibilityFallbackAlertThisLaunch {
            hasShownAccessibilityFallbackAlertThisLaunch = true
            AlertManager.shared.showAccessibilityPermissionAlert()
        }

    }

    private func ensureGlobalKeyMonitorsIfPossible() {
        guard permissionManager.checkAccessibilityPermission() else { return }

        eventTapManager.ensureGlobalKeyMonitorsIfPossible()
    }

    // MARK: - Toggle AI Enhancement

    // MARK: - Toggle Floating Indicator

    private func handleToggleFloatingIndicator() {
        settingsStore.floatingIndicatorEnabled.toggle()

        if settingsStore.floatingIndicatorEnabled {
            floatingIndicatorCoordinator.clearFloatingIndicatorTemporaryHiddenState()
        }

        let status = settingsStore.floatingIndicatorEnabled ? "enabled" : "disabled"
        Log.app.info("Floating indicator \(status)")
    }

    // MARK: - Toggle Launch at Login

    private func handleToggleLaunchAtLogin() {
        let newValue = !settingsStore.launchAtLogin
        do {
            try launchAtLoginManager.setEnabled(newValue)
            settingsStore.launchAtLogin = newValue
            let status = newValue ? "enabled" : "disabled"
            Log.app.info("Launch at login \(status)")
        } catch {
            Log.app.error("Failed to toggle launch at login: \(error)")
        }
    }

    private func handleCheckForUpdates() {
        if updateService.shouldDeferUpdate(isRecording: recordingCoordinator.isRecording || recordingCoordinator.isProcessing) {
            AlertManager.shared.showGenericErrorAlert(
                title: "Update Deferred",
                message: "Finish recording or processing before checking for updates."
            )
            return
        }

        updateService.checkForUpdates()
    }

    // MARK: - Report Issue

    private func handleReportIssue() {
        guard let supportURL = URL(string: "https://github.com/kuleka/OpenTypeless/issues") else { return }
        NSWorkspace.shared.open(supportURL)
    }

    // MARK: - Input Device / Language

    private func handleSelectInputDeviceUID(_ uid: String) {
        settingsStore.selectedInputDeviceUID = uid
        audioRecorder.setPreferredInputDeviceUID(uid)

        if uid.isEmpty {
            Log.audio.info("Selected input device: system default")
        } else {
            Log.audio.info("Selected input device UID: \(uid)")
        }
    }

    private func handleSelectLanguage(_ language: AppLanguage) {
        settingsStore.selectedAppLanguage = language
        Log.ui.info("Selected app language: \(language.rawValue)")
    }

    // MARK: - Open History

    private func handleOpenHistory() {
        mainWindowController.showHistory()
    }

    // MARK: - Show App

    private func handleShowApp() {
        mainWindowController.show()
    }

    func switchToModel(named modelName: String) async {
        guard modelName != activeModelName else {
            Log.app.info("Model \(modelName) is already active")
            return
        }
        
        guard !recordingCoordinator.isRecording && !recordingCoordinator.isProcessing else {
            Log.app.warning("Cannot switch model while recording or processing")
            return
        }
        
        Log.app.info("Switching to model: \(modelName)")
        
        await modelManager.refreshDownloadedModels()
        guard let model = modelManager.availableModels.first(where: { $0.name == modelName }) else {
            Log.app.error("Cannot switch to model \(modelName): not found")
            return
        }
        
        if !modelManager.isModelDownloaded(modelName) {
            Log.app.error("Cannot switch to model \(modelName): not downloaded")
            return
        }
        
        splashController.setLoading("Switching to \(model.displayName)...")
        
        do {
            try await loadAndActivateModel(named: modelName, provider: model.provider)
            settingsStore.selectedModel = modelName
            statusBarController.updateDynamicItems()
            Log.model.info("Switched to model \(modelName) successfully")
        } catch {
            if model.provider == .whisperKit {
                do {
                    try await attemptWhisperModelRepairAndReload(
                        modelName: modelName,
                        displayName: model.displayName
                    )
                    settingsStore.selectedModel = modelName
                    statusBarController.updateDynamicItems()
                    Log.model.info("Model repaired and switched successfully: \(modelName)")
                    return
                } catch {
                    handleModelLoadError(error, context: "Failed to repair switched model")
                    AlertManager.shared.showModelLoadErrorAlert(error: error)
                    return
                }
            }

            handleModelLoadError(error, context: "Failed to switch model")
            AlertManager.shared.showModelLoadErrorAlert(error: error)
        }
    }
    
    // MARK: - Update Recent Transcripts

    private func updateRecentTranscriptsMenu() {
        Task {
            do {
                let records = try historyStore.fetch(limit: 5)
                let transcripts = records.map { (id: $0.id, text: $0.text, timestamp: $0.timestamp) }
                await MainActor.run {
                    statusBarController.updateRecentTranscripts(transcripts)
                }
            } catch {
                Log.app.error("Failed to update recent transcripts: \(error)")
            }
        }
    }

    func cleanup() {
        engineProcessManager.stop()
        floatingIndicatorCoordinator.clearFloatingIndicatorTemporaryHiddenState()
        engineRuntimeCoordinator.cancelPendingEvaluation()
        eventTapManager.cleanup()
    }
}
