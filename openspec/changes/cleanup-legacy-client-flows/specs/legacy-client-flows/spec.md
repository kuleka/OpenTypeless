## ADDED Requirements

### Requirement: Quick capture note workflow is retired
The system SHALL stop exposing and executing the retired quick capture note workflow in the supported macOS client.

#### Scenario: Quick capture hotkeys are no longer shown
- **WHEN** the user opens Hotkeys settings
- **THEN** the app SHALL show only supported dictation hotkeys and SHALL NOT show note-capture push-to-talk or note-capture toggle controls

#### Scenario: Stored quick capture settings are ignored
- **WHEN** older quick-capture hotkey values exist in local settings from a previous build
- **THEN** the app SHALL NOT register or execute the retired quick capture workflow and standard dictation hotkeys SHALL continue to work

### Requirement: Supported runtime flows no longer depend on provider-specific AI enhancement
The system SHALL remove `AIEnhancementService` from supported runtime flows after the Engine-backed baseline is established.

#### Scenario: Standard dictation does not route through legacy enhancement service
- **WHEN** the user records through the supported dictation flow
- **THEN** the app SHALL complete the flow without calling the legacy provider-specific enhancement service

#### Scenario: Manual notes do not require legacy AI configuration
- **WHEN** the user creates or edits notes after this cleanup
- **THEN** note persistence SHALL continue to work without requiring legacy AI endpoint, key, or model settings

### Requirement: Note capture is no longer a dictation side effect
The system SHALL avoid opening the note editor or entering a note-capture-specific recording branch as part of the supported dictation lifecycle.

#### Scenario: Recording lifecycle stays in the supported dictation path
- **WHEN** the user starts and stops recording through the supported app hotkeys or controls
- **THEN** the app SHALL remain in the standard dictation pipeline and SHALL NOT branch into retired note-capture state
