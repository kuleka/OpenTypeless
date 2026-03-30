# engine-lifecycle Specification

## Purpose
TBD - created by archiving change runtime-onboarding-and-engine-lifecycle. Update Purpose after archive.
## Requirements
### Requirement: App SHALL auto-spawn Engine process on launch
The App SHALL spawn the Engine as a child process on launch using `Process`. The Engine process SHALL be started before any Engine-dependent functionality is invoked.

#### Scenario: Normal app launch
- **WHEN** the App launches and Engine is not already running
- **THEN** the App spawns the Engine process and begins health polling

#### Scenario: Engine already running
- **WHEN** the App launches and an Engine instance is already responding on the configured port
- **THEN** the App SHALL adopt the existing Engine (skip spawn) and verify health

### Requirement: App SHALL discover Engine binary via priority chain
The App SHALL locate the Engine executable using the following priority: (1) user-configured custom path, (2) `$PATH` lookup, (3) repository venv fallback path. If no executable is found, the App SHALL surface an error to the user.

#### Scenario: Custom path configured
- **WHEN** the user has set a custom Engine path in settings
- **THEN** the App SHALL use that path to spawn the Engine

#### Scenario: Fallback to PATH
- **WHEN** no custom path is configured and `open_typeless` is on `$PATH`
- **THEN** the App SHALL use the PATH-resolved binary

#### Scenario: Fallback to venv
- **WHEN** no custom path and not on `$PATH`, but repo venv exists
- **THEN** the App SHALL use the venv Python to run the Engine module

#### Scenario: No Engine found
- **WHEN** no Engine binary can be resolved through any strategy
- **THEN** the App SHALL display an error with instructions to install the Engine

### Requirement: App SHALL monitor Engine health and auto-restart on failure
The App SHALL periodically poll `GET /health` after Engine startup. If the Engine becomes unresponsive, the App SHALL attempt to restart it automatically.

#### Scenario: Engine crashes
- **WHEN** the Engine process terminates unexpectedly
- **THEN** the App SHALL attempt to restart it within 3 seconds

#### Scenario: Health check fails
- **WHEN** `GET /health` returns non-200 or times out for 3 consecutive attempts
- **THEN** the App SHALL kill and restart the Engine process

#### Scenario: Restart limit
- **WHEN** the Engine has been restarted more than 5 times within 60 seconds
- **THEN** the App SHALL stop restarting and surface an error to the user

### Requirement: App SHALL terminate Engine on quit
The App SHALL send SIGTERM to the Engine child process when the App quits. If the Engine does not exit within 5 seconds, the App SHALL send SIGKILL.

#### Scenario: Normal app quit
- **WHEN** the user quits the App
- **THEN** the Engine process is terminated gracefully (SIGTERM then SIGKILL fallback)

#### Scenario: App crash
- **WHEN** the App process is killed unexpectedly
- **THEN** the Engine process SHALL detect parent loss and self-terminate (best-effort)

### Requirement: App SHALL push configuration to Engine after spawn
After the Engine responds to `GET /health`, the App SHALL immediately call `POST /config` with the user's saved STT and LLM configuration.

#### Scenario: Config push after spawn
- **WHEN** Engine health check succeeds for the first time after spawn
- **THEN** the App calls `POST /config` with stored API credentials

#### Scenario: Config not yet set
- **WHEN** Engine is healthy but no API credentials are configured (first launch)
- **THEN** the App SHALL skip config push and report NOT_CONFIGURED status

