# dual-mode-transcription Specification

## Purpose
TBD - created by archiving change phase1-macos-client. Update Purpose after archive.
## Requirements
### Requirement: Local STT mode
The system SHALL support local speech-to-text using WhisperKit or Parakeet engines, preserving existing Pindrop functionality.

#### Scenario: Local transcription with WhisperKit
- **WHEN** user selects local STT mode and records audio
- **THEN** Client transcribes audio locally using WhisperKit and returns the text to the pipeline

#### Scenario: Local transcription with Parakeet
- **WHEN** user selects local STT mode with Parakeet engine and records audio
- **THEN** Client transcribes audio locally using Parakeet and returns the text to the pipeline

#### Scenario: Local STT without Engine running
- **WHEN** user selects local STT mode and Engine is not running
- **THEN** Client still transcribes audio locally (but cannot polish without Engine)

### Requirement: Remote STT mode
The system SHALL support remote speech-to-text by sending audio to Engine `/transcribe` endpoint.

#### Scenario: Remote transcription via Engine
- **WHEN** user selects remote STT mode and records audio
- **THEN** Client sends audio as multipart/form-data to Engine `POST /transcribe` and receives transcribed text

#### Scenario: Remote STT with Engine unreachable
- **WHEN** user selects remote STT mode but Engine is not running
- **THEN** Client displays an error indicating Engine is unavailable for remote STT

### Requirement: STT mode selection
The system SHALL allow users to switch between local and remote STT modes in settings.

#### Scenario: Switch to local STT
- **WHEN** user selects "Local" STT mode in settings
- **THEN** subsequent recordings use local WhisperKit/Parakeet engine for transcription

#### Scenario: Switch to remote STT
- **WHEN** user selects "Remote (Engine)" STT mode in settings
- **THEN** subsequent recordings send audio to Engine `/transcribe` for transcription

### Requirement: Unified pipeline output
The system SHALL feed transcribed text (from either mode) into the same downstream polish pipeline.

#### Scenario: Local STT feeds into Engine polish
- **WHEN** local STT produces transcribed text
- **THEN** the text is sent to Engine `POST /polish` with `text` field for scene-aware polishing

#### Scenario: Remote STT feeds into Engine polish
- **WHEN** remote STT produces transcribed text via `/transcribe`
- **THEN** the text is sent to Engine `POST /polish` with `text` field for scene-aware polishing

### Requirement: Optional STT configuration
The system SHALL allow `POST /config` to be called without `stt` configuration. Only `llm` SHALL be required.

#### Scenario: Config with only LLM
- **WHEN** a POST request is sent to `/config` with only `llm` (no `stt`)
- **THEN** the engine SHALL store the config, respond with `{"status": "configured"}`, and allow text-mode `/polish` requests

#### Scenario: Config with both STT and LLM
- **WHEN** a POST request is sent to `/config` with both `stt` and `llm`
- **THEN** the engine SHALL store both and allow all endpoints including `/transcribe` and audio-mode `/polish`

#### Scenario: GET /config with no STT
- **WHEN** config was set without `stt` and a GET request is sent to `/config`
- **THEN** the response SHALL have `configured: true`, `stt: null`, and `llm` with masked key

### Requirement: STT_NOT_CONFIGURED error code
The engine SHALL return a distinct `STT_NOT_CONFIGURED` error (503) when an operation requires STT but it has not been configured.

#### Scenario: Audio polish without STT config
- **WHEN** `/polish` is called with `audio_base64` but `stt` was not configured
- **THEN** the engine SHALL return 503 with error code `STT_NOT_CONFIGURED`

#### Scenario: Transcribe without STT config
- **WHEN** `/transcribe` is called but `stt` was not configured
- **THEN** the engine SHALL return 503 with error code `STT_NOT_CONFIGURED`

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

