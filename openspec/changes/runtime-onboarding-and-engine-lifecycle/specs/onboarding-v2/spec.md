## ADDED Requirements

### Requirement: Permission-first onboarding
The system SHALL guide users through granting required permissions before any other configuration.

#### Scenario: Microphone permission requested as required
- **WHEN** the user reaches the permissions step in onboarding
- **THEN** the system SHALL request microphone permission and indicate it is required for the app to function

#### Scenario: Accessibility permission requested with context explanation
- **WHEN** the user reaches the permissions step in onboarding
- **THEN** the system SHALL request Accessibility permission, explain it is needed for scene-aware text polishing (detecting current app and window title), and warn that without it all polishing will use the default style

#### Scenario: Accessibility not granted
- **WHEN** the user does not grant Accessibility permission
- **THEN** the system SHALL allow the user to continue but display a persistent warning that scene detection is degraded

### Requirement: STT mode selection in onboarding
The system SHALL let users choose between local and remote STT during onboarding, and conditionally show model download or provider configuration.

#### Scenario: User selects local STT
- **WHEN** the user chooses local STT mode during onboarding
- **THEN** the system SHALL present a model selection and download step for on-device Whisper models

#### Scenario: User selects remote STT
- **WHEN** the user chooses remote STT mode during onboarding
- **THEN** the system SHALL present STT provider configuration (API base URL, API key, model) and skip local model download

### Requirement: LLM provider configuration in onboarding
The system SHALL require users to configure an LLM provider during onboarding, as this is necessary for the core polishing feature.

#### Scenario: LLM provider configured with API key
- **WHEN** the user enters LLM provider credentials (API base URL, API key, model) during onboarding
- **THEN** the system SHALL store the configuration and use it for Engine `/config` push

#### Scenario: User attempts to skip LLM configuration
- **WHEN** the user tries to proceed without configuring an LLM provider
- **THEN** the system SHALL warn that polishing will not work without LLM configuration and require confirmation to continue without it

### Requirement: Transparent Engine readiness on completion
The system SHALL verify Engine connectivity in the background and present a ready state on the completion step without exposing Engine internals to the user.

#### Scenario: Engine ready at completion
- **WHEN** the user reaches the completion step and Engine is running, healthy, and has received the configuration
- **THEN** the system SHALL display a confirmation that everything is ready for use

#### Scenario: Engine still starting at completion
- **WHEN** the user reaches the completion step but Engine has not yet responded to health checks
- **THEN** the system SHALL display a progress indicator and wait for Engine readiness before showing the final confirmation

#### Scenario: Engine failed to start at completion
- **WHEN** the user reaches the completion step but Engine could not be started or is unreachable
- **THEN** the system SHALL display troubleshooting guidance and allow the user to retry or continue in degraded mode
