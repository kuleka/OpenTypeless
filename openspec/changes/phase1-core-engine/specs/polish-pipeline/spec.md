## ADDED Requirements

### Requirement: Full polish endpoint
The engine SHALL expose `POST /polish` that accepts audio + context and returns polished text with metadata.

#### Scenario: Successful polish request
- **WHEN** a POST request is sent to `/polish` with valid `audio_base64`, `audio_format`, and `context`
- **THEN** the server SHALL return JSON with `text` (polished), `raw_transcript`, `context_detected` (scene name), `model_used`, `stt_ms`, `llm_ms`, and `total_ms`

#### Scenario: Missing audio
- **WHEN** a POST request is sent to `/polish` without `audio_base64`
- **THEN** the server SHALL return HTTP 422 with a validation error

#### Scenario: Invalid base64 audio
- **WHEN** `audio_base64` contains invalid base64 data
- **THEN** the server SHALL return HTTP 400 with a clear error message

### Requirement: Latency tracking
The engine SHALL measure and report latency for each pipeline stage in the response.

#### Scenario: Latency breakdown in response
- **WHEN** a successful polish request completes
- **THEN** the response SHALL include `stt_ms` (STT duration), `llm_ms` (LLM duration), and `total_ms` (end-to-end duration) as integers

### Requirement: Pipeline error handling
The engine SHALL handle errors at each pipeline stage gracefully.

#### Scenario: STT failure
- **WHEN** the STT service fails during a polish request
- **THEN** the server SHALL return HTTP 502 with an error message indicating STT failure

#### Scenario: LLM failure
- **WHEN** the LLM service fails during a polish request
- **THEN** the server SHALL return HTTP 502 with an error message indicating LLM failure

### Requirement: Request defaults
The engine SHALL apply sensible defaults for optional fields in the polish request.

#### Scenario: Default audio format
- **WHEN** `audio_format` is not specified
- **THEN** the engine SHALL default to `"wav"`

#### Scenario: Default model
- **WHEN** `options.model` is not specified in the `/polish` request
- **THEN** the engine SHALL use the `llm.model` value from `POST /config`

#### Scenario: Default language
- **WHEN** `options.language` is not specified
- **THEN** the engine SHALL use the `default_language` value from `POST /config` (which itself defaults to `"auto"`)

#### Scenario: Empty app context
- **WHEN** `context` is not provided or empty
- **THEN** the engine SHALL use the `default` scene for prompt routing

### Requirement: Configuration prerequisite
The engine SHALL require `POST /config` to be called before processing any `/polish` request.

#### Scenario: Polish before configuration
- **WHEN** a POST request is sent to `/polish` before `POST /config` has been called
- **THEN** the server SHALL return HTTP 503 with error code `NOT_CONFIGURED` and a message indicating that the engine needs to be configured first
