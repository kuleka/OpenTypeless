# engine-client Specification

## Purpose
TBD - created by archiving change phase1-macos-client. Update Purpose after archive.
## Requirements
### Requirement: Engine health check
The system SHALL evaluate Engine availability by calling `GET /health` and SHALL expose a runtime state that distinguishes offline, configuration-incomplete, and ready conditions.

#### Scenario: Engine is ready
- **WHEN** Client evaluates Engine runtime, `GET /health` succeeds, and the active mode has the required configuration
- **THEN** Client marks Engine runtime as ready

#### Scenario: Engine is not running
- **WHEN** Client evaluates Engine runtime and Engine is not reachable at the configured host:port
- **THEN** Client marks Engine runtime as offline and allows local STT mode to continue functioning without Engine

#### Scenario: Engine is reachable but not ready for active mode
- **WHEN** Client evaluates Engine runtime, `GET /health` succeeds, but the active STT mode still lacks required provider configuration
- **THEN** Client marks Engine runtime as configuration-incomplete instead of treating Engine as fully ready

#### Scenario: Engine becomes unreachable during session
- **WHEN** a later request to Engine fails with a connection error
- **THEN** Client updates the runtime state to offline and surfaces a recoverable runtime error to the user

### Requirement: Push configuration to Engine
The system SHALL push user-configured API credentials to Engine via `POST /config` after a successful health check and SHALL use the result to determine runtime readiness.

#### Scenario: Full configuration with STT and LLM
- **WHEN** user has configured both STT and LLM provider settings
- **THEN** Client sends `POST /config` with both `stt` and `llm` objects and marks Engine runtime ready after successful sync

#### Scenario: LLM-only configuration (local STT mode)
- **WHEN** user has configured LLM provider but uses local STT
- **THEN** Client sends `POST /config` with only `llm` object (no `stt`) and marks Engine runtime ready for local-STT dictation after successful sync

#### Scenario: Configuration not yet set
- **WHEN** user has not configured the credentials required for the active mode
- **THEN** Client does not treat Engine as ready and surfaces a configuration-incomplete runtime state

#### Scenario: Configuration push fails
- **WHEN** Client attempts `POST /config` and the request fails or returns a validation error
- **THEN** Client preserves a non-ready runtime state and exposes the failure as actionable setup feedback

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

### Requirement: Explicit runtime recheck
The system SHALL support explicit Engine runtime rechecks without restarting the app.

#### Scenario: User-triggered recheck
- **WHEN** the user requests a runtime recheck
- **THEN** Client SHALL re-run health and configuration evaluation against the configured Engine address and update the exposed runtime state

#### Scenario: Connection settings changed
- **WHEN** the user changes Engine host or port
- **THEN** Client SHALL evaluate the new address and expose the resulting runtime state for that address

