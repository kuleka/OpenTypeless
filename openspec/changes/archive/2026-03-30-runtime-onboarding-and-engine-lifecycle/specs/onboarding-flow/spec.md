## ADDED Requirements

### Requirement: App SHALL show onboarding on first launch
The App SHALL present an onboarding window on first launch (when `hasCompletedOnboarding` is false). The onboarding MUST be completed before the main app functionality is available.

#### Scenario: First launch
- **WHEN** the App launches and `hasCompletedOnboarding` is false
- **THEN** the App presents the onboarding window

#### Scenario: Subsequent launch
- **WHEN** the App launches and `hasCompletedOnboarding` is true
- **THEN** the App skips onboarding and proceeds to normal operation

### Requirement: Onboarding SHALL collect required permissions
The onboarding flow SHALL request Microphone and Accessibility permissions. Both permissions are REQUIRED — the user MUST grant both to proceed.

#### Scenario: Both permissions granted
- **WHEN** the user grants both Microphone and Accessibility permissions
- **THEN** the onboarding advances to the next step

#### Scenario: Permission denied
- **WHEN** the user denies either Microphone or Accessibility permission
- **THEN** the onboarding SHALL explain why the permission is required and provide a button to open System Settings

#### Scenario: Accessibility permission check
- **WHEN** the onboarding checks Accessibility permission
- **THEN** it SHALL verify the App is in the Accessibility allowed list (AXIsProcessTrusted)

### Requirement: Onboarding SHALL collect STT mode selection
The onboarding flow SHALL allow the user to choose between local STT (WhisperKit) and remote STT (API-based). This selection determines whether STT config is required.

#### Scenario: Local STT selected
- **WHEN** the user selects local WhisperKit STT
- **THEN** STT API configuration is skipped; only LLM config is required

#### Scenario: Remote STT selected
- **WHEN** the user selects remote STT
- **THEN** the onboarding SHALL also collect STT API credentials (endpoint, key, model)

### Requirement: Onboarding SHALL collect LLM provider configuration
The onboarding flow SHALL collect LLM API credentials (endpoint, API key, model). This is REQUIRED — the user MUST provide valid LLM configuration to complete onboarding.

#### Scenario: Valid LLM config provided
- **WHEN** the user enters LLM endpoint, API key, and model
- **THEN** the config is saved to SettingsStore

#### Scenario: Provider preset selected
- **WHEN** the user selects a known provider preset (e.g., OpenRouter, Groq)
- **THEN** the endpoint and recommended model are auto-filled; user only needs to enter API key

### Requirement: Onboarding SHALL offer optional hotkey customization
The onboarding flow SHALL show the current default hotkey and allow the user to customize it. This step is optional — the user can skip with the default.

#### Scenario: User keeps default
- **WHEN** the user clicks "Continue" without changing the hotkey
- **THEN** the default hotkey is retained

#### Scenario: User customizes hotkey
- **WHEN** the user records a new hotkey combination
- **THEN** the new hotkey is saved to SettingsStore

### Requirement: Onboarding completion SHALL verify Engine readiness
The final onboarding step SHALL verify that the Engine is running, healthy, and configured. This verification happens in the background — the user sees a "ready" confirmation.

#### Scenario: Engine ready
- **WHEN** the onboarding reaches the completion step and Engine health + config are verified
- **THEN** the App sets `hasCompletedOnboarding` to true and transitions to normal operation

#### Scenario: Engine not ready
- **WHEN** the onboarding reaches the completion step but Engine is not healthy
- **THEN** the App displays a troubleshooting message with retry option

### Requirement: Onboarding SHALL be re-accessible from Settings
The user SHALL be able to re-run the onboarding flow from the Settings window to reconfigure permissions and providers.

#### Scenario: Re-run onboarding
- **WHEN** the user clicks "Re-run Setup" in Settings
- **THEN** the onboarding window opens with current values pre-filled
