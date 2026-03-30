## ADDED Requirements

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
