# engine-polish Specification

## Purpose
TBD - created by archiving change phase1-macos-client. Update Purpose after archive.
## Requirements
### Requirement: Scene-aware polishing via Engine
The system SHALL send transcribed text to Engine `POST /polish` with app context for scene-aware text polishing.

#### Scenario: Polish in email context
- **WHEN** user dictates text while in an email app (e.g., `com.apple.mail`)
- **THEN** Client sends `POST /polish` with `text`, `context.app_id`, and `context.window_title`, and Engine returns text polished in formal email style

#### Scenario: Polish with default context
- **WHEN** user dictates text outside the email scene, including other apps or unrecognized contexts
- **THEN** Client sends `POST /polish` with context and Engine returns text with `context_detected: "default"` while preserving the original meaning and tone

### Requirement: Translation task support
The system SHALL support translation tasks by passing `task: "translate"` and `output_language` to Engine `/polish`.

#### Scenario: Translate Chinese speech to English
- **WHEN** user selects translate mode with `output_language: "en"` and dictates in Chinese
- **THEN** Client sends `POST /polish` with `options.task: "translate"` and `options.output_language: "en"` and receives English text

### Requirement: Display raw transcript
The system SHALL display the raw transcript from the Engine response alongside the polished text.

#### Scenario: Show raw and polished text
- **WHEN** Engine returns a polish response with both `text` and `raw_transcript`
- **THEN** Client stores both values in the transcription record for user review

### Requirement: Handle polish errors gracefully
The system SHALL handle Engine polish errors and display meaningful feedback.

#### Scenario: Engine returns STT failure
- **WHEN** Engine returns 502 `STT_FAILURE` during audio-mode polish
- **THEN** Client displays "Speech recognition failed" error to user

#### Scenario: Engine returns LLM failure
- **WHEN** Engine returns 502 `LLM_FAILURE`
- **THEN** Client displays "Text polishing failed" error and offers to paste raw transcript as fallback

#### Scenario: Engine not configured
- **WHEN** Engine returns 503 `NOT_CONFIGURED`
- **THEN** Client prompts user to configure API settings

### Requirement: Dual-mode polish input
The system SHALL accept either pre-transcribed `text` or `audio_base64` in `POST /polish`, with mutual exclusion validation.

#### Scenario: Polish with text input (local STT mode)
- **WHEN** `POST /polish` is called with `text` field and no `audio_base64`
- **THEN** the engine SHALL skip STT, use the provided text as `raw_transcript`, detect scene, assemble prompt, call LLM, and return `PolishResponse` with `stt_ms: 0`

#### Scenario: Polish with audio input (remote STT mode)
- **WHEN** `POST /polish` is called with `audio_base64` and no `text`
- **THEN** the engine SHALL decode audio, run STT, detect scene, assemble prompt, call LLM, and return `PolishResponse` (existing behavior)

#### Scenario: Neither text nor audio provided
- **WHEN** `POST /polish` is called with neither `text` nor `audio_base64`
- **THEN** the engine SHALL return 422 with error code `VALIDATION_ERROR` and message `"Either text or audio_base64 must be provided"`

#### Scenario: Both text and audio provided
- **WHEN** `POST /polish` is called with both `text` and `audio_base64`
- **THEN** the engine SHALL return 422 with error code `VALIDATION_ERROR` and message `"text and audio_base64 are mutually exclusive"`

#### Scenario: Audio input without STT configured
- **WHEN** `POST /polish` is called with `audio_base64` but `stt` was not configured
- **THEN** the engine SHALL return 503 with error code `STT_NOT_CONFIGURED`
