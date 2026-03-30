## MODIFIED Requirements

### Requirement: Engine settings reflect app-managed lifecycle
The system SHALL present Engine connection settings that are consistent with the app-managed Engine model, removing references to manual Engine startup.

#### Scenario: Engine status display in settings
- **WHEN** the user views Engine settings
- **THEN** the system SHALL display Engine status (running, offline, error) and a Recheck button, without any text instructing the user to start Engine manually in a terminal

#### Scenario: Engine executable path configuration
- **WHEN** the user wants to use a custom Engine installation
- **THEN** the system SHALL provide an optional setting to specify a custom Engine executable path, overriding automatic discovery
