## MODIFIED Requirements

### Requirement: Scene-aware polishing via Engine
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
