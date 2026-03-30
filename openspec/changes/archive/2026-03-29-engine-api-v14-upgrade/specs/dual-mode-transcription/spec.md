## MODIFIED Requirements

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
