## MODIFIED Requirements

### Requirement: App SHALL monitor Engine health and auto-restart on failure
The App SHALL periodically poll `GET /health` after Engine startup. If the Engine becomes unresponsive, the App SHALL attempt to restart it automatically. The App SHALL extract and propagate enriched health data (uptime, configuration status, request statistics) from the health response into `EngineRuntimeState` for UI consumption.

#### Scenario: Engine crashes
- **WHEN** the Engine process terminates unexpectedly
- **THEN** the App SHALL attempt to restart it within 3 seconds

#### Scenario: Health check fails
- **WHEN** `GET /health` returns non-200 or times out for 3 consecutive attempts
- **THEN** the App SHALL kill and restart the Engine process

#### Scenario: Restart limit
- **WHEN** the Engine has been restarted more than 5 times within 60 seconds
- **THEN** the App SHALL stop restarting and surface an error to the user

#### Scenario: Enriched health data propagation
- **WHEN** `GET /health` succeeds and the response includes `uptime_seconds` and `stats`
- **THEN** the App SHALL store these values in `EngineRuntimeState` for display in Settings UI
