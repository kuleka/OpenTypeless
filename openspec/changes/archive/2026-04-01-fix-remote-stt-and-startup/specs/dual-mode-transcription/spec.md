## ADDED Requirements

### Requirement: App startup SHALL respect STT mode
The App SHALL check the configured `sttMode` during startup and only load local STT models when `sttMode` is `.local`. When `sttMode` is `.remote`, the App SHALL skip local model loading and initialize the remote transcription engine directly.

#### Scenario: Startup with remote STT mode
- **WHEN** the App starts and `sttMode` is `.remote`
- **THEN** the App SHALL skip WhisperKit model discovery and loading, initialize `EngineTranscriptionEngine`, and proceed to normal operation

#### Scenario: Startup with local STT mode
- **WHEN** the App starts and `sttMode` is `.local`
- **THEN** the App SHALL load the selected WhisperKit model as before (no behavior change)

#### Scenario: Remote STT recording succeeds
- **WHEN** `sttMode` is `.remote` and the user records audio
- **THEN** the App SHALL transcribe via `EngineTranscriptionEngine` without requiring any local model to be loaded

### Requirement: App SHALL show Dock icon when windows are visible
The App SHALL dynamically switch between menu-bar-only mode and regular app mode based on window visibility, so that the Dock icon appears when the user has open windows.

#### Scenario: Window opens
- **WHEN** a settings or main window becomes visible
- **THEN** the App SHALL set activation policy to `.regular` to show the Dock icon

#### Scenario: All windows close
- **WHEN** all App windows are closed
- **THEN** the App SHALL set activation policy to `.accessory` to hide the Dock icon
