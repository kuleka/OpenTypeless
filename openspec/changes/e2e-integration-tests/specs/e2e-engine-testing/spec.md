## ADDED Requirements

### Requirement: Engine stub mode
Engine CLI SHALL support a `--stub` flag that replaces real LLM/STT calls with deterministic stub responses, while keeping all other logic (routing, config, scene detection) intact.

#### Scenario: Stub mode polish returns predictable text
- **WHEN** Engine is started with `--stub` AND config is pushed AND POST /polish is called with text "hello world"
- **THEN** response contains polished text `"[stub] hello world"` with correct scene detection and timing fields

#### Scenario: Stub mode transcribe returns predictable text
- **WHEN** Engine is started with `--stub` AND stt config is pushed AND POST /transcribe is called
- **THEN** response contains text `"stub transcription"`

#### Scenario: Stub mode does not affect config or health
- **WHEN** Engine is started with `--stub`
- **THEN** GET /health, POST /config, GET /config, GET /contexts, POST /contexts all behave identically to normal mode

### Requirement: E2E test process management
Swift E2E tests SHALL start a real Engine process using the repo venv Python, wait for it to become healthy, and terminate it after tests complete.

#### Scenario: Engine starts and becomes reachable
- **WHEN** the test suite launches Engine via `engine/.venv/bin/python -m open_typeless.cli serve --port 29823 --stub`
- **THEN** GET /health returns 200 within 10 seconds

#### Scenario: Engine is terminated after tests
- **WHEN** all E2E tests have completed
- **THEN** the Engine process is terminated and no orphan process remains

#### Scenario: Missing venv skips tests
- **WHEN** `engine/.venv/bin/python` does not exist
- **THEN** all E2E tests are skipped with a diagnostic message

### Requirement: E2E health and config flow
Swift E2E tests SHALL verify that EngineClient can perform health check and config push against a real Engine.

#### Scenario: Health check succeeds
- **WHEN** EngineClient calls health() against the running stub Engine
- **THEN** response contains status "ok" and a version string

#### Scenario: Config push succeeds
- **WHEN** EngineClient calls pushConfig with valid LLM provider config
- **THEN** response contains status "configured"

#### Scenario: Fetch config returns masked keys
- **WHEN** config has been pushed AND EngineClient calls fetchConfig()
- **THEN** response shows configured = true with masked API key

### Requirement: E2E polish flow
Swift E2E tests SHALL verify the full polish pipeline through real HTTP.

#### Scenario: Polish text succeeds after config
- **WHEN** config has been pushed AND EngineClient calls polish with text "test input" and context app_id "com.apple.mail"
- **THEN** response contains polished text, scene "email", and timing fields (sttMs, llmMs, totalMs)

#### Scenario: Polish without config returns error
- **WHEN** no config has been pushed AND EngineClient calls polish
- **THEN** EngineClient throws an error indicating NOT_CONFIGURED (503)

### Requirement: E2E error handling
Swift E2E tests SHALL verify that EngineClient correctly handles error responses from a real Engine.

#### Scenario: Invalid polish request returns validation error
- **WHEN** a raw HTTP request sends both text and audio_base64 to POST /polish
- **THEN** Engine returns 422 with error code VALIDATION_ERROR
