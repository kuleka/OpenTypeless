## ADDED Requirements

### Requirement: POST /transcribe endpoint
The engine SHALL expose a `POST /transcribe` endpoint that accepts audio via multipart/form-data and returns transcribed text.

#### Scenario: Successful transcription
- **WHEN** a POST request is sent to `/transcribe` with a valid audio file and STT is configured
- **THEN** the engine SHALL return 200 with JSON body containing `text`, `language_detected`, `duration_ms`, and `stt_ms` fields

#### Scenario: STT not configured
- **WHEN** a POST request is sent to `/transcribe` but `stt` has not been configured via `POST /config`
- **THEN** the engine SHALL return 503 with error code `STT_NOT_CONFIGURED` and message indicating STT must be configured

#### Scenario: STT API failure
- **WHEN** a POST request is sent to `/transcribe` and the upstream STT API returns an error
- **THEN** the engine SHALL return 502 with error code `STT_FAILURE`

#### Scenario: Language hint
- **WHEN** a POST request includes a `language` form field (e.g., `"zh"`)
- **THEN** the engine SHALL pass the language hint to the STT API
