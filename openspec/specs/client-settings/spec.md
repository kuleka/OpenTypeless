# client-settings Specification

## Purpose
TBD - created by archiving change phase1-macos-client. Update Purpose after archive.
## Requirements
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

### Requirement: STT mode selection UI
The system SHALL provide UI for selecting between local and remote STT modes.

#### Scenario: Select local STT
- **WHEN** user selects "Local" in STT mode picker
- **THEN** local model settings (model selection, download) become visible and remote STT provider settings are hidden

#### Scenario: Select remote STT
- **WHEN** user selects "Remote (Engine)" in STT mode picker
- **THEN** remote STT provider settings (api_base, api_key, model) become visible and local model settings are hidden

### Requirement: STT provider configuration
The system SHALL provide UI for configuring remote STT provider credentials when remote STT mode is selected.

#### Scenario: Configure Groq STT
- **WHEN** user selects remote STT and enters Groq API base, key, and model
- **THEN** settings store the credentials and push them to Engine via `POST /config` on next connection

#### Scenario: STT provider presets
- **WHEN** user opens STT provider configuration
- **THEN** a dropdown offers presets (Groq, OpenAI, Deepgram) that auto-fill `api_base` and default `model`

### Requirement: LLM provider configuration
The system SHALL provide UI for configuring LLM provider credentials used by Engine for polishing.

#### Scenario: Configure OpenRouter LLM
- **WHEN** user enters OpenRouter API base, key, and model name
- **THEN** settings store the credentials and push them to Engine via `POST /config`

#### Scenario: LLM provider presets
- **WHEN** user opens LLM provider configuration
- **THEN** a dropdown offers presets (OpenRouter, OpenAI, local Ollama) that auto-fill `api_base` and default `model`

### Requirement: Auto-push configuration on change
The system SHALL automatically push updated configuration to Engine when user modifies provider settings.

#### Scenario: User changes LLM API key
- **WHEN** user updates the LLM API key in settings and Engine is connected
- **THEN** Client immediately sends `POST /config` with updated credentials

#### Scenario: Engine disconnected during config change
- **WHEN** user updates settings while Engine is disconnected
- **THEN** settings are saved locally and pushed to Engine on next successful health check

### Requirement: API key secure storage
The system SHALL store API keys securely in the macOS Keychain.

#### Scenario: Save API key
- **WHEN** user enters an STT or LLM API key
- **THEN** the key is stored in Keychain, not in UserDefaults or plain text

#### Scenario: Retrieve API key for config push
- **WHEN** Client needs to push config to Engine
- **THEN** API keys are read from Keychain and included in the `POST /config` request body

### Requirement: Runtime recovery actions in settings
The system SHALL provide explicit runtime recovery actions in Engine settings.

#### Scenario: Manual recheck from settings
- **WHEN** the user clicks a recheck or reconnect action in Engine settings
- **THEN** the app SHALL re-run Engine runtime evaluation against the current host and port and refresh the visible status

#### Scenario: Recheck while already evaluating
- **WHEN** the app is already running a health/config evaluation
- **THEN** the settings UI SHALL show that a check is in progress and prevent duplicate recheck actions

### Requirement: Retired note-capture controls are removed from settings
The system SHALL stop surfacing retired quick-capture note controls in the active settings experience.

#### Scenario: Hotkeys settings omit note capture controls
- **WHEN** the user opens Hotkeys settings
- **THEN** the settings UI SHALL omit retired note-capture push-to-talk and toggle controls

#### Scenario: Legacy note-capture settings are not treated as active configuration
- **WHEN** stored quick-capture settings exist from an older version
- **THEN** the settings experience SHALL NOT present them as active supported controls

### Requirement: Legacy AI-only configuration is retired from the active settings surface
The system SHALL consolidate active AI configuration around the Engine-backed settings used by current dictation flows.

#### Scenario: Active settings show only supported Engine-backed AI configuration
- **WHEN** the user opens Engine & AI settings after this cleanup
- **THEN** the UI SHALL present the Engine runtime, STT mode, remote STT provider, and Engine LLM provider configuration used by the supported product flow and SHALL NOT present a separate legacy AI-only endpoint/key/model surface

#### Scenario: Legacy AI values migrate only when Engine LLM settings are still empty
- **WHEN** legacy AI endpoint or model values exist locally but Engine LLM settings have not yet been configured
- **THEN** the app SHALL migrate the legacy values into the Engine LLM configuration once and continue from the consolidated settings model

