## ADDED Requirements

### Requirement: Runtime recovery actions in settings
The system SHALL provide explicit runtime recovery actions in Engine settings.

#### Scenario: Manual recheck from settings
- **WHEN** the user clicks a recheck or reconnect action in Engine settings
- **THEN** the app SHALL re-run Engine runtime evaluation against the current host and port and refresh the visible status

#### Scenario: Recheck while already evaluating
- **WHEN** the app is already running a health/config evaluation
- **THEN** the settings UI SHALL show that a check is in progress and prevent duplicate recheck actions

## MODIFIED Requirements

### Requirement: Engine connection settings
The system SHALL provide UI for configuring Engine connection parameters and surfacing the current runtime setup state.

#### Scenario: Default Engine address
- **WHEN** user opens settings and has not modified Engine connection
- **THEN** settings show default host `127.0.0.1` and port `19823`

#### Scenario: Custom port configuration
- **WHEN** user changes the Engine port to `19824`
- **THEN** all subsequent Engine requests use port `19824`

#### Scenario: Engine offline status
- **WHEN** user opens settings and Engine is not reachable at the configured host and port
- **THEN** settings display an offline runtime state instead of only a generic disconnected indicator

#### Scenario: Engine configuration incomplete status
- **WHEN** Engine is reachable but required provider configuration is missing for the active STT mode
- **THEN** settings display a configuration-incomplete runtime state and identify the missing setup area

#### Scenario: Engine ready status
- **WHEN** Engine is reachable and the active mode has the required configuration
- **THEN** settings display a ready runtime state indicating that dictation can use the configured Engine flow
