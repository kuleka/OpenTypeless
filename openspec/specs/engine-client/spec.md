# engine-client Specification

## Purpose
TBD - created by archiving change phase1-macos-client. Update Purpose after archive.
## Requirements
### Requirement: Engine health check
The system SHALL check Engine availability by calling `GET /health` on startup and report the connection status.

#### Scenario: Engine is running
- **WHEN** Client starts up and Engine is running at the configured host:port
- **THEN** `GET /health` returns 200 with `{"status": "ok"}` and Client marks Engine as connected

#### Scenario: Engine is not running
- **WHEN** Client starts up and Engine is not reachable
- **THEN** Client marks Engine as disconnected and allows local STT mode to function without Engine

#### Scenario: Engine becomes unreachable during session
- **WHEN** a request to Engine fails with a connection error
- **THEN** Client marks Engine as disconnected and displays an error to the user

### Requirement: Push configuration to Engine
The system SHALL push user-configured API credentials to Engine via `POST /config` after a successful health check.

#### Scenario: Full configuration with STT and LLM
- **WHEN** user has configured both STT and LLM provider settings
- **THEN** Client sends `POST /config` with both `stt` and `llm` objects and Engine returns `{"status": "configured"}`

#### Scenario: LLM-only configuration (local STT mode)
- **WHEN** user has configured LLM provider but uses local STT
- **THEN** Client sends `POST /config` with only `llm` object (no `stt`) and Engine returns `{"status": "configured"}`

#### Scenario: Configuration not yet set
- **WHEN** user has not configured any API credentials
- **THEN** Client does not call `POST /config` and displays setup instructions

### Requirement: Call transcribe endpoint
The system SHALL send audio to Engine `POST /transcribe` as multipart/form-data when using remote STT mode.

#### Scenario: Successful remote transcription
- **WHEN** Client sends audio file to `POST /transcribe`
- **THEN** Engine returns JSON with `text`, `language_detected`, `duration_ms`, and `stt_ms`

#### Scenario: STT not configured on Engine
- **WHEN** Client sends audio to `POST /transcribe` but Engine has no STT configured
- **THEN** Engine returns 503 `STT_NOT_CONFIGURED` and Client displays an error

### Requirement: Call polish endpoint
The system SHALL send transcribed text to Engine `POST /polish` with app context for scene-aware polishing.

#### Scenario: Text input mode (local STT)
- **WHEN** Client has transcribed text locally and sends `POST /polish` with `text` field and `context`
- **THEN** Engine returns polished text with `context_detected` scene type

#### Scenario: Text input mode after remote STT
- **WHEN** Client first calls `POST /transcribe`, receives transcript text, and then sends `POST /polish` with `text` field and `context`
- **THEN** Engine returns polished text with `context_detected` scene type

#### Scenario: Engine not configured
- **WHEN** Client calls `POST /polish` before `POST /config`
- **THEN** Engine returns 503 `NOT_CONFIGURED` and Client displays an error

### Requirement: Connection configuration
The system SHALL allow users to configure the Engine host and port.

#### Scenario: Default connection
- **WHEN** user has not changed Engine connection settings
- **THEN** Client connects to `127.0.0.1:19823`

#### Scenario: Custom port
- **WHEN** user configures a custom port in settings
- **THEN** Client uses the custom port for all Engine requests

