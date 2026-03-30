## ADDED Requirements

### Requirement: Runtime onboarding states
The system SHALL present a user-visible Engine runtime onboarding state that distinguishes offline, configuration-incomplete, and ready conditions.

#### Scenario: Engine offline on first use
- **WHEN** the app evaluates Engine runtime and `GET /health` cannot reach the configured host and port
- **THEN** the app SHALL show an onboarding state indicating that Engine is not running and explain how the user can start it and retry

#### Scenario: Engine reachable but configuration incomplete
- **WHEN** Engine responds to health checks but the active STT mode still lacks required provider configuration
- **THEN** the app SHALL show an onboarding state indicating that configuration is incomplete and identify the next setup step

#### Scenario: Engine ready
- **WHEN** Engine is reachable and the active mode has the required configuration for subsequent requests
- **THEN** the app SHALL show an onboarding state indicating that Engine is ready for dictation

### Requirement: Mode-aware runtime recovery
The system SHALL provide different recovery behavior depending on whether the user is in local STT mode or remote STT mode.

#### Scenario: Local STT mode with Engine unavailable
- **WHEN** the user is in local STT mode and Engine is offline or polish fails due to runtime availability issues
- **THEN** the app SHALL continue outputting the raw or locally processed transcript and show actionable guidance for restoring Engine-backed polish

#### Scenario: Remote STT mode with Engine unavailable
- **WHEN** the user is in remote STT mode and Engine is offline before transcription can begin
- **THEN** the app SHALL stop the remote transcription flow and show guidance telling the user to start Engine or switch STT mode

### Requirement: User-triggered runtime recovery
The system SHALL allow users to explicitly retry runtime evaluation after changing the environment outside the app.

#### Scenario: Recheck after starting Engine
- **WHEN** the user starts Engine manually and triggers a recheck action in the app
- **THEN** the app SHALL re-run runtime evaluation and update the onboarding state without requiring an app restart

