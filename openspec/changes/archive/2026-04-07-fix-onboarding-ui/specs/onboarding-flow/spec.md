## MODIFIED Requirements

### Requirement: Onboarding SHALL collect required permissions

The onboarding flow SHALL request Microphone and Accessibility permissions. Both permissions are REQUIRED — the user MUST grant both to proceed. Permission status checks SHALL NOT cause visible UI state flicker.

#### Scenario: First launch

- **WHEN** the App launches and `hasCompletedOnboarding` is false
- **THEN** the App presents the onboarding window

#### Scenario: Subsequent launch

- **WHEN** the App launches and `hasCompletedOnboarding` is true
- **THEN** the App skips onboarding and proceeds to normal operation

#### Scenario: Both permissions granted

- **WHEN** the user grants both Microphone and Accessibility permissions
- **THEN** the onboarding advances to the next step

#### Scenario: Permission denied

- **WHEN** the user denies either Microphone or Accessibility permission
- **THEN** the onboarding SHALL explain why the permission is required and provide a button to open System Settings

#### Scenario: Accessibility permission check

- **WHEN** the onboarding checks Accessibility permission
- **THEN** it SHALL verify the App is in the Accessibility allowed list (AXIsProcessTrusted)

#### Scenario: Accessibility permission request does not flicker

- **WHEN** the user taps Grant for Accessibility permission
- **THEN** the UI SHALL update the permission status exactly once (after async recheck), not flip between states

### Requirement: Onboarding SHALL collect LLM provider configuration

The onboarding flow SHALL collect LLM API credentials (endpoint, API key, model). This is REQUIRED — the user MUST provide valid LLM configuration to complete onboarding. The API Base URL input SHALL be validated for correct URL format before allowing save.

#### Scenario: Valid LLM config provided

- **WHEN** the user enters LLM endpoint, API key, and model
- **THEN** the config is saved to SettingsStore

#### Scenario: Provider preset selected

- **WHEN** the user selects a known provider preset (e.g., OpenRouter, Groq)
- **THEN** the endpoint and recommended model are auto-filled; user only needs to enter API key

#### Scenario: Invalid API Base URL

- **WHEN** the user enters an API Base URL that does not start with `http://` or `https://` or cannot be parsed as a valid URL
- **THEN** the Save button SHALL remain disabled

## ADDED Requirements

### Requirement: Onboarding window SHALL resize bidirectionally

The onboarding window SHALL resize to match each step's preferred content size, both growing and shrinking. The resize animation SHALL be visually synchronized with the content transition animation.

#### Scenario: Navigate from LLMConfig to HotkeySetup

- **WHEN** the user advances from LLMConfig (800×700) to HotkeySetup (800×600)
- **THEN** the window SHALL shrink to 800×600 with smooth animation

#### Scenario: Navigate back from STTConfig to LLMConfig

- **WHEN** the user presses Back from STTConfig
- **THEN** the window SHALL resize to LLMConfig's preferred size with smooth animation

### Requirement: Config step forms SHALL be scrollable

The LLMConfigStepView and STTConfigStepView forms SHALL be wrapped in a vertical ScrollView so that content remains accessible on smaller displays.

#### Scenario: Small display overflow

- **WHEN** the config form content exceeds the available height
- **THEN** the user SHALL be able to scroll vertically to access all form fields and buttons

#### Scenario: Normal display

- **WHEN** the config form content fits within the available height
- **THEN** no visible scroll indicators SHALL appear

### Requirement: STTConfig SHALL have its own step indicator dot

When STT mode is set to remote, the STTConfig step SHALL appear as a distinct dot in the step indicator. When STT mode is local, the STTConfig dot SHALL not appear.

#### Scenario: Remote STT mode indicator

- **WHEN** the user is on the STTConfig step in remote STT mode
- **THEN** the step indicator SHALL highlight the STTConfig dot as active

#### Scenario: Local STT mode indicator

- **WHEN** the user has selected local STT mode
- **THEN** the step indicator SHALL not include an STTConfig dot

### Requirement: Onboarding step action buttons SHALL have consistent sizing

All primary action buttons across onboarding steps SHALL use a uniform maximum width. Button padding and spacing SHALL be consistent.

#### Scenario: Button width consistency

- **WHEN** any onboarding step is displayed
- **THEN** the primary action button SHALL have a maxWidth of 200 points

#### Scenario: CompleteStepView padding

- **WHEN** the CompleteStepView is displayed
- **THEN** horizontal padding SHALL match other steps (`.padding(.horizontal, 40)`)

### Requirement: STTConfig URL validation

The STTConfigStepView API Base URL input SHALL be validated for correct URL format before allowing save, consistent with LLMConfigStepView.

#### Scenario: Invalid STT API Base URL

- **WHEN** the user enters an STT API Base URL that does not start with `http://` or `https://` or cannot be parsed as a valid URL
- **THEN** the Save button SHALL remain disabled
