## ADDED Requirements

### Requirement: HTTP server binds to localhost
The engine SHALL start an HTTP server on `127.0.0.1:19823` by default. The port SHALL be configurable via `OPEN_TYPELESS_PORT` environment variable.

#### Scenario: Default port startup
- **WHEN** the server starts without `OPEN_TYPELESS_PORT` set
- **THEN** it SHALL listen on `127.0.0.1:19823`

#### Scenario: Custom port startup
- **WHEN** `OPEN_TYPELESS_PORT` is set to `8080`
- **THEN** the server SHALL listen on `127.0.0.1:8080`

#### Scenario: Port conflict
- **WHEN** port 19823 is already in use
- **THEN** the server SHALL exit with a clear error message indicating the port conflict

### Requirement: Health check endpoint
The server SHALL expose `GET /health` that returns server status and version.

#### Scenario: Health check success
- **WHEN** a GET request is sent to `/health`
- **THEN** the server SHALL respond with status 200 and JSON body `{"status": "ok", "version": "<current_version>"}`

### Requirement: Configuration endpoint
The server SHALL expose `POST /config` to receive API connection info from the client, and `GET /config` to return the current configuration with API keys masked.

#### Scenario: Set configuration
- **WHEN** a POST request is sent to `/config` with valid `stt` (api_base, api_key, model) and `llm` (api_base, api_key, model)
- **THEN** the server SHALL store the configuration in memory and respond with `{"status": "configured"}`

#### Scenario: Missing required fields
- **WHEN** a POST request to `/config` is missing `stt` or `llm` or any of their required subfields
- **THEN** the server SHALL return HTTP 422 with a validation error

#### Scenario: View configuration
- **WHEN** a GET request is sent to `/config`
- **THEN** the server SHALL respond with the current config, API keys masked (prefix + `****` + last 4 chars), and a `configured` boolean

#### Scenario: View configuration before setup
- **WHEN** a GET request is sent to `/config` before any `POST /config` has been called
- **THEN** the server SHALL respond with `{"configured": false, "stt": null, "llm": null, "default_language": "auto"}`

### Requirement: CLI entry point
The engine SHALL provide a CLI command `open-typeless serve` that starts the HTTP server.

#### Scenario: Start server via CLI
- **WHEN** user runs `open-typeless serve`
- **THEN** the HTTP server SHALL start and log the listening address

#### Scenario: Start server with custom port via CLI
- **WHEN** user runs `open-typeless serve --port 8080`
- **THEN** the HTTP server SHALL start on port 8080
