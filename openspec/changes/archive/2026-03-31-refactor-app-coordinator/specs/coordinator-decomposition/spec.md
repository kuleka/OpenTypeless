## ADDED Requirements

### Requirement: EventTapManager encapsulates all event tap logic
EventTapManager SHALL own setup, teardown, recovery, and fallback global monitors for both Escape and modifier key event taps. It SHALL expose callbacks for escape signals and modifier state changes. AppCoordinator SHALL NOT contain any CFMachPort, CFRunLoopSource, or event tap recovery logic.

#### Scenario: Event tap setup on app start
- **WHEN** AppCoordinator calls `eventTapManager.setup()`
- **THEN** EventTapManager creates Escape and modifier event taps on a dedicated run loop thread

#### Scenario: Event tap recovery after system disable
- **WHEN** the system disables an event tap
- **THEN** EventTapManager automatically attempts re-enable, falling back to global NSEvent monitors if recovery fails, without AppCoordinator involvement

#### Scenario: Escape key signal
- **WHEN** user presses Escape during recording
- **THEN** EventTapManager invokes the `onEscapeSignal` closure, which AppCoordinator uses to cancel the current operation

### Requirement: HotkeyCoordinator encapsulates hotkey registration
HotkeyCoordinator SHALL own all global hotkey registration, validation, conflict detection, and failure reporting. It SHALL read hotkey settings from SettingsStore and register handlers via HotkeyManager. AppCoordinator SHALL NOT contain hotkey registration or conflict detection logic.

#### Scenario: Register hotkeys from settings
- **WHEN** HotkeyCoordinator is asked to register hotkeys
- **THEN** it reads toggle, push-to-talk, and translate hotkey settings, validates them, checks for conflicts, and registers with HotkeyManager

#### Scenario: Hotkey conflict detected
- **WHEN** two hotkeys share the same key code and modifiers
- **THEN** HotkeyCoordinator skips the duplicate registration and reports the conflict via a toast callback

#### Scenario: Translate hotkey triggers recording with translate task
- **WHEN** user presses the translate hotkey
- **THEN** HotkeyCoordinator invokes the `onTranslateToggle` closure

### Requirement: FloatingIndicatorCoordinator encapsulates indicator state
FloatingIndicatorCoordinator SHALL manage floating indicator visibility, type selection, recording/processing state transitions, and temporary hide behavior. AppCoordinator SHALL NOT contain indicator show/hide logic.

#### Scenario: Recording starts
- **WHEN** a recording session begins
- **THEN** FloatingIndicatorCoordinator transitions the active indicator to recording state

#### Scenario: Recording finishes processing
- **WHEN** processing completes
- **THEN** FloatingIndicatorCoordinator finishes the indicator session and returns to idle

#### Scenario: User hides indicator for one hour
- **WHEN** user selects "Hide for 1 Hour" from indicator menu
- **THEN** FloatingIndicatorCoordinator hides all indicators and schedules automatic re-show after 1 hour

### Requirement: ContextSessionCoordinator encapsulates live context capture
ContextSessionCoordinator SHALL own live context session lifecycle: start, stop, suspend, polling, app focus observation, workspace root detection, and context snapshot management. AppCoordinator SHALL NOT contain context polling timers or app activation observers.

#### Scenario: Context session starts with recording
- **WHEN** a recording begins and UI context is enabled
- **THEN** ContextSessionCoordinator starts polling the focused app's context at the configured interval

#### Scenario: App focus changes during recording
- **WHEN** the user switches apps during an active recording
- **THEN** ContextSessionCoordinator captures the new app context with throttling to avoid excessive updates

#### Scenario: Recording ends
- **WHEN** recording stops
- **THEN** ContextSessionCoordinator suspends updates and provides the final captured snapshot to the caller

### Requirement: EngineRuntimeCoordinator encapsulates engine lifecycle
EngineRuntimeCoordinator SHALL own engine configuration readiness evaluation, health checking, runtime state updates, and config sync scheduling. AppCoordinator SHALL NOT contain engine readiness logic or runtime state error message formatting.

#### Scenario: Engine config sync on startup
- **WHEN** the app finishes onboarding or starts normally
- **THEN** EngineRuntimeCoordinator evaluates engine health and pushes configuration via the engine startup handlers

#### Scenario: Settings change triggers re-sync
- **WHEN** engine-related settings change (host, port, API keys, models)
- **THEN** EngineRuntimeCoordinator schedules a debounced configuration sync

#### Scenario: Engine unavailable
- **WHEN** engine health check fails
- **THEN** EngineRuntimeCoordinator updates the runtime state on SettingsStore and provides a localized error message

### Requirement: RecordingCoordinator encapsulates recording flow
RecordingCoordinator SHALL own the entire recording lifecycle: start, stop, push-to-talk, streaming transcription, audio processing, text normalization, polish orchestration, and output delivery. It SHALL expose `isRecording` and `isProcessing` as observable state. AppCoordinator SHALL NOT contain recording start/stop logic or streaming transcription management.

#### Scenario: Toggle recording via hotkey
- **WHEN** the toggle recording hotkey is pressed
- **THEN** RecordingCoordinator starts or stops recording depending on current state

#### Scenario: Push-to-talk flow
- **WHEN** push-to-talk key is held then released
- **THEN** RecordingCoordinator starts recording on key-down and stops + transcribes on key-up

#### Scenario: Translate recording flow
- **WHEN** recording completes with `pendingTranslateTask = true`
- **THEN** RecordingCoordinator passes `task: .translate` and `outputLanguage` from settings to the polish handler

#### Scenario: Streaming transcription
- **WHEN** streaming mode is enabled and recording starts
- **THEN** RecordingCoordinator manages audio forwarding, partial text insertion, and session finalization

### Requirement: AppCoordinator remains a thin orchestrator
After extraction, AppCoordinator SHALL only contain: initialization/wiring, app lifecycle (start, onboarding), settings observation dispatch, and small action handlers (< 30 lines each). It SHALL delegate all substantial logic to the extracted coordinators.

#### Scenario: AppCoordinator line count
- **WHEN** all extractions are complete
- **THEN** AppCoordinator SHALL be under 1200 lines

#### Scenario: All existing behavior preserved
- **WHEN** the refactored app is built and run
- **THEN** all recording, hotkey, indicator, context, engine, and transcription features work identically to before the refactor
