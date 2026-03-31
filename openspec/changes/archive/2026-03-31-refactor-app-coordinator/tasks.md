## 1. Project Setup

- [x] 1.1 Create `clients/macos/Pindrop/Coordinators/` directory and add folder reference to Xcode project
- [x] 1.2 Move nested types (HotkeyBindingSnapshot, HotkeySettingsSnapshot, EngineSettingsSnapshot, SettingsObservationSnapshot, RecordingTriggerSource, etc.) to a shared `CoordinatorTypes.swift` file so extracted types can reference them

## 2. Extract EventTapManager

- [x] 2.1 Create `EventTapManager.swift` — move all event tap properties (escapeEventTap, modifierEventTap, run loop sources, global monitors, recovery state, EventTapRunLoopThread, double-escape detection) and methods (setupEscapeKeyMonitor, setupModifierKeyMonitor, teardownEscapeKeyMonitor, teardownModifierKeyMonitor, scheduleEventTapRecovery, performEventTapRecovery, resetEventTapRecoveryState, install/remove fallback monitors, handleEscapeSignal, handleEscapeKeyPress). Expose `onEscapeSignal: () -> Void` and `onModifierStateChanged` closures.
- [x] 2.2 Update AppCoordinator to create EventTapManager in init, wire closures, delegate calls. Remove moved code.
- [x] 2.3 Build and verify — zero compilation errors

## 3. Extract FloatingIndicatorCoordinator

- [x] 3.1 Create `FloatingIndicatorCoordinator.swift` — move indicator visibility methods (updateFloatingIndicatorVisibility, configuredFloatingIndicatorType, hideAllFloatingIndicators, startRecordingIndicatorSession, transitionRecordingIndicatorToProcessing, startProcessingIndicatorSession, finishIndicatorSession, isFloatingIndicatorTemporarilyHidden, clearFloatingIndicatorTemporaryHiddenState, handleHideFloatingIndicatorForOneHour), related properties (floatingIndicatorHiddenUntil, floatingIndicatorHiddenTask, activeFloatingIndicatorType), and trigger source mapping methods.
- [x] 3.2 Update AppCoordinator to create FloatingIndicatorCoordinator, wire it, remove moved code.
- [x] 3.3 Build and verify — zero compilation errors

## 4. Extract HotkeyCoordinator

- [x] 4.1 Create `HotkeyCoordinator.swift` — move registerHotkeysFromSettings, validatedHotkeyBinding, handleHotkeyRegistrationFailure, canRegisterHotkey, hotkeyDisplayName, and the HotkeyRegistrationState/HotkeyConflict types. Expose closures: `onToggleRecording`, `onPushToTalkStart`, `onPushToTalkEnd`, `onTranslateToggle`.
- [x] 4.2 Update AppCoordinator to create HotkeyCoordinator, wire closures, delegate setupHotkeys(). Remove moved code.
- [x] 4.3 Build and verify — zero compilation errors

## 5. Extract EngineRuntimeCoordinator

- [x] 5.1 Create `EngineRuntimeCoordinator.swift` — move currentEngineConfigurationReadiness, scheduleEngineConfigurationSync, requestManualEngineRuntimeRecheck, evaluateEngineRuntime, updateEngineRuntimeState, readyRuntimeDetail, missingConfigurationDetail, localEngineUnavailableMessage, remoteEngineBlockedMessage, and engineRuntimeEvaluationTask property. Accept SettingsStore and EngineStartupHandlers via init.
- [x] 5.2 Update AppCoordinator to create EngineRuntimeCoordinator, delegate engine lifecycle calls. Remove moved code.
- [x] 5.3 Build and verify — zero compilation errors

## 6. Extract ContextSessionCoordinator

- [x] 6.1 Create `ContextSessionCoordinator.swift` — move shouldRunLiveContextSession, updateVibeRuntimeStateFromSettings, deriveWorkspaceRoots, currentLiveSessionContext, startLiveContextSessionIfNeeded, stopLiveContextSession, suspendLiveContextSessionUpdates, installContextSessionObserversIfNeeded, removeContextSessionObserversIfNeeded, scheduleFocusOrWindowContextRefreshIfNeeded, updateContextSession, and related properties (contextSessionState, contextSessionPollTimer, contextSessionAppActivationObserver, capturedSnapshot, capturedContext, capturedAdapterCapabilities, capturedRoutingSignal, lastFocusOrWindowUpdateAt, appContextAdapterRegistry, promptRoutingResolver).
- [x] 6.2 Update AppCoordinator to create ContextSessionCoordinator, wire it, remove moved code.
- [x] 6.3 Build and verify — zero compilation errors

## 7. Extract RecordingCoordinator

- [x] 7.1 Create `RecordingCoordinator.swift` as `@Observable` — move isRecording, isProcessing, recordingStartTime, pendingTranslateTask, streaming session state and methods (handlePushToTalkStart/End, handleToggleRecording, startRecording, stopRecordingAndTranscribe, stopRecordingAndFinalizeStreaming, processRecordedAudioData, beginStreamingSessionIfAvailable, all streaming helper methods), text normalization (normalizedTranscriptionText, isTranscriptionEffectivelyEmpty), polish orchestration (polishTranscribedTextIfNeeded), handleTranslateToggle, cancelCurrentOperation, resetProcessingState. Accept AudioRecorder, TranscriptionService, OutputManager, SettingsStore, PolishHandlers, ToastService, HistoryStore, FloatingIndicatorCoordinator, ContextSessionCoordinator, and MediaPauseService via init.
- [x] 7.2 Update AppCoordinator to create RecordingCoordinator, expose its observable state, wire all recording entry points. Remove moved code.
- [x] 7.3 Update any SwiftUI views that read `coordinator.isRecording` or `coordinator.isProcessing` to read from `coordinator.recordingCoordinator`
- [x] 7.4 Build and verify — zero compilation errors

## 8. Final Cleanup

- [x] 8.1 Audit remaining AppCoordinator — 1444 lines (down from ~3900); contains init/wiring, lifecycle, settings observation, media transcription, and small action handlers. Media transcription (~170 lines) is the main remaining extraction candidate if further reduction is needed.
- [x] 8.2 Remove any unused imports, dead code, or orphaned properties from AppCoordinator
- [x] 8.3 Full build + run manual smoke test (record, push-to-talk, translate, hotkey change, floating indicator toggle, engine config sync)
