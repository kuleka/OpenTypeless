## ADDED Requirements

### Requirement: App-managed Engine process startup
The system SHALL automatically start the Engine process in the background when the app launches, without requiring any user action.

#### Scenario: Engine starts on app launch
- **WHEN** the app launches and no Engine process is already running on the configured port
- **THEN** the system SHALL spawn the Engine process in the background and begin health polling until Engine responds to `GET /health`

#### Scenario: Existing Engine detected on configured port
- **WHEN** the app launches and an Engine process is already responding on the configured port
- **THEN** the system SHALL reuse the existing Engine instance and skip process spawning

#### Scenario: Engine binary not found
- **WHEN** the app attempts to start Engine but cannot locate the `open-typeless` executable in any configured or discoverable path
- **THEN** the system SHALL set Engine runtime state to an error condition and present installation guidance to the user

### Requirement: Engine process health monitoring
The system SHALL continuously monitor the Engine process health and automatically recover from failures.

#### Scenario: Engine process exits unexpectedly
- **WHEN** the managed Engine process terminates unexpectedly while the app is running
- **THEN** the system SHALL automatically restart the Engine process with exponential backoff and update the runtime state to reflect the recovery attempt

#### Scenario: Engine health check fails after successful startup
- **WHEN** the Engine was previously healthy but `GET /health` stops responding
- **THEN** the system SHALL update the runtime state to offline and attempt process restart if the managed process is no longer running

### Requirement: Engine process cleanup on app exit
The system SHALL terminate the managed Engine process when the app exits.

#### Scenario: Normal app quit
- **WHEN** the user quits the app and the Engine process was spawned by this app instance
- **THEN** the system SHALL send SIGTERM to the managed Engine process and wait briefly for graceful shutdown before the app exits

#### Scenario: App crash does not orphan Engine
- **WHEN** the app crashes or is force-quit
- **THEN** the Engine process SHALL eventually detect the absence of the managing client (via its own idle timeout or OS process cleanup) rather than running indefinitely

### Requirement: Engine binary discovery
The system SHALL locate the Engine executable using a priority-ordered search strategy.

#### Scenario: Engine found via user-configured path
- **WHEN** the user has set a custom Engine executable path in Settings
- **THEN** the system SHALL use that path and skip other discovery methods

#### Scenario: Engine found via PATH
- **WHEN** no custom path is set and the `open-typeless` command exists in `$PATH`
- **THEN** the system SHALL use the PATH-resolved executable

#### Scenario: Engine found via repository-relative path
- **WHEN** no custom path is set, `open-typeless` is not in `$PATH`, and the app detects it is running from a development environment with a known repository layout
- **THEN** the system SHALL attempt to locate the Engine in the repository's venv (e.g., `engine/.venv/bin/open-typeless`)
