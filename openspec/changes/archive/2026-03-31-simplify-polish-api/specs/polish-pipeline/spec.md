## MODIFIED Requirements

### Requirement: Full polish endpoint
The engine SHALL expose `POST /polish` that accepts text + context and returns polished text with metadata. The `text` field is required.

#### Scenario: Successful polish request
- **WHEN** a POST request is sent to `/polish` with valid `text` and `context`
- **THEN** the server SHALL return JSON with `text` (polished), `raw_transcript`, `task` (the executed task type), `context_detected` (scene name), `model_used`, `llm_ms`, and `total_ms`

#### Scenario: Missing text
- **WHEN** a POST request is sent to `/polish` without `text` or with empty `text`
- **THEN** the server SHALL return HTTP 422 with a validation error

### Requirement: Latency tracking
The engine SHALL measure and report latency for the LLM stage and total request duration in the response.

#### Scenario: Latency breakdown in response
- **WHEN** a successful polish request completes
- **THEN** the response SHALL include `llm_ms` (LLM duration) and `total_ms` (end-to-end duration) as integers

## REMOVED Requirements

### Requirement: Audio input mode for polish
**Reason**: `audio_base64` input was never used by any client. macOS uses WhisperKit for local STT and sends text directly. Remote STT is available via the independent `/transcribe` endpoint.
**Migration**: Use `/transcribe` for STT, then pass the result text to `/polish`.
