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

