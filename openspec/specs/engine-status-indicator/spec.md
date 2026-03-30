# engine-status-indicator Specification

## Purpose
TBD - created by archiving change runtime-onboarding-and-engine-lifecycle. Update Purpose after archive.
## Requirements
### Requirement: Menu bar icon SHALL reflect Engine connection state
The App's menu bar icon SHALL visually indicate the current Engine status. States: connected (ready), connecting (starting/polling), disconnected (error), unconfigured (no API keys).

#### Scenario: Engine connected and configured
- **WHEN** Engine health check passes and config is pushed
- **THEN** the menu bar icon shows the normal/active state

#### Scenario: Engine starting
- **WHEN** Engine process has been spawned but health check has not yet succeeded
- **THEN** the menu bar icon shows a connecting/loading state

#### Scenario: Engine disconnected
- **WHEN** Engine health check fails or process has terminated
- **THEN** the menu bar icon shows a disconnected/error state

#### Scenario: Engine unconfigured
- **WHEN** Engine is healthy but no API credentials have been configured
- **THEN** the menu bar icon shows an unconfigured state

### Requirement: Menu bar tooltip SHALL show Engine status detail
The menu bar icon tooltip SHALL display a human-readable status message describing the current Engine state.

#### Scenario: Hover over icon
- **WHEN** the user hovers over the menu bar icon
- **THEN** a tooltip shows the current state (e.g., "Ready", "Starting Engine...", "Engine not responding", "API key not configured")

### Requirement: Menu bar dropdown SHALL include Engine status section
The menu bar dropdown menu SHALL include a status line showing Engine connection state and a quick action to open Settings if configuration is needed.

#### Scenario: Engine ready
- **WHEN** the user opens the menu bar dropdown and Engine is ready
- **THEN** the status line shows "Engine: Connected"

#### Scenario: Engine needs configuration
- **WHEN** the user opens the menu bar dropdown and Engine is unconfigured
- **THEN** the status line shows "Engine: Not configured" with a "Configure..." action

