## ADDED Requirements

### Requirement: Health endpoint SHALL return configuration status
The Engine `/health` endpoint SHALL include `configured` (bool) and `stt_configured` (bool) fields indicating whether LLM and STT API configurations have been pushed via `POST /config`. These fields SHALL default to `false`.

#### Scenario: Health before config push
- **WHEN** `GET /health` is called before any `POST /config`
- **THEN** the response SHALL include `"configured": false` and `"stt_configured": false`

#### Scenario: Health after LLM-only config push
- **WHEN** `POST /config` has been called with `llm` but no `stt`
- **THEN** `GET /health` SHALL return `"configured": true` and `"stt_configured": false`

#### Scenario: Health after full config push
- **WHEN** `POST /config` has been called with both `llm` and `stt`
- **THEN** `GET /health` SHALL return `"configured": true` and `"stt_configured": true`

### Requirement: Health endpoint SHALL return uptime
The Engine `/health` endpoint SHALL include `uptime_seconds` (int) indicating seconds since the Engine process started. The timer SHALL start during the FastAPI lifespan startup.

#### Scenario: Uptime after startup
- **WHEN** `GET /health` is called 10 seconds after Engine start
- **THEN** `uptime_seconds` SHALL be approximately 10 (±1 second tolerance)

### Requirement: Health endpoint SHALL return request statistics
The Engine `/health` endpoint SHALL include a `stats` object with `requests_total` (int), `requests_failed` (int), and `last_request_at` (string, ISO 8601 UTC, nullable). Statistics SHALL only count `/polish` and `/transcribe` requests. Counters SHALL be in-memory and reset to zero on Engine restart.

#### Scenario: Stats at startup
- **WHEN** `GET /health` is called immediately after Engine start (no requests processed)
- **THEN** `stats` SHALL contain `requests_total: 0`, `requests_failed: 0`, `last_request_at: null`

#### Scenario: Stats after successful polish
- **WHEN** one `POST /polish` request succeeds
- **THEN** `stats.requests_total` SHALL be 1, `stats.requests_failed` SHALL be 0, `stats.last_request_at` SHALL be a valid ISO 8601 timestamp

#### Scenario: Stats after failed request
- **WHEN** `POST /polish` is called without configuration (returns 503)
- **THEN** `stats.requests_total` SHALL be 1 and `stats.requests_failed` SHALL be 1

#### Scenario: Stats after mixed requests
- **WHEN** 3 polish requests succeed and 1 transcribe request fails
- **THEN** `stats.requests_total` SHALL be 4 and `stats.requests_failed` SHALL be 1

### Requirement: Health response SHALL be backwards compatible
All new fields in the `/health` response SHALL have default values. Clients that do not recognize the new fields SHALL continue to function without error.

#### Scenario: Old client receives enriched response
- **WHEN** a client that only expects `status` and `version` receives the enriched response
- **THEN** JSON decoding SHALL succeed, ignoring unknown fields

#### Scenario: New client receives old response
- **WHEN** a new client connects to an old Engine that only returns `status` and `version`
- **THEN** the new optional fields SHALL decode as nil/null without error

### Requirement: Client SHALL display Engine stats in Settings
The Settings Engine Connection card SHALL display uptime and request statistics below the status label when the Engine is in `ready` state and stats data is available.

#### Scenario: Engine ready with stats
- **WHEN** Engine is in `ready` state and health reports `uptime_seconds: 4320` and `stats.requests_total: 42, requests_failed: 1`
- **THEN** the Settings card SHALL display a line like "Uptime: 1h 12m · Requests: 42 (1 failed)"

#### Scenario: Engine ready with no requests yet
- **WHEN** Engine is in `ready` state and `stats.requests_total` is 0
- **THEN** the Settings card SHALL display only uptime (e.g. "Uptime: 5m")

#### Scenario: Engine not ready
- **WHEN** Engine is in `offline`, `checking`, or `error` state
- **THEN** the stats line SHALL NOT be displayed
