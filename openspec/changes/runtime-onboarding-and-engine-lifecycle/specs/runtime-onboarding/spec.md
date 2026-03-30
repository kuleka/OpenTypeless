## MODIFIED Requirements

### Requirement: Runtime onboarding states
The system SHALL present a user-visible Engine runtime onboarding state that distinguishes offline, configuration-incomplete, and ready conditions.

#### Scenario: Engine offline on first use
- **WHEN** the app evaluates Engine runtime and `GET /health` cannot reach the configured host and port
- **THEN** the app SHALL show an onboarding state indicating that Engine is starting or has failed to start, and provide recovery options appropriate to app-managed Engine (retry or troubleshoot), rather than instructing the user to start Engine manually

#### Scenario: Engine reachable but configuration incomplete
- **WHEN** Engine responds to health checks but the active STT mode still lacks required provider configuration
- **THEN** the app SHALL show an onboarding state indicating that configuration is incomplete and identify the next setup step

#### Scenario: Engine ready
- **WHEN** Engine is reachable and the active mode has the required configuration for subsequent requests
- **THEN** the app SHALL show an onboarding state indicating that Engine is ready for dictation

### Requirement: User-triggered runtime recovery
The system SHALL allow users to explicitly retry runtime evaluation after changing the environment outside the app.

#### Scenario: Recheck after Engine recovery
- **WHEN** the user triggers a recheck action in the app
- **THEN** the app SHALL re-run runtime evaluation (including attempting to restart the managed Engine process if it is not running) and update the onboarding state without requiring an app restart
