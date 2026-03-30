## ADDED Requirements

### Requirement: Scene-aware polishing via Engine
The system SHALL send transcribed text to Engine `POST /polish` with app context for scene-aware text polishing.

#### Scenario: Polish in email context
- **WHEN** user dictates text while in an email app (e.g., `com.apple.mail`)
- **THEN** Client sends `POST /polish` with `text`, `context.app_id`, and `context.window_title`, and Engine returns text polished in formal email style

#### Scenario: Polish in chat context
- **WHEN** user dictates text while in a chat app (e.g., Slack)
- **THEN** Client sends `POST /polish` with context and Engine returns text polished in casual chat style

#### Scenario: Polish with default context
- **WHEN** user dictates text in an unrecognized app
- **THEN** Client sends `POST /polish` with context and Engine returns text with `context_detected: "default"`

### Requirement: Translation task support
The system SHALL support translation tasks by passing `task: "translate"` and `output_language` to Engine `/polish`.

#### Scenario: Translate Chinese speech to English
- **WHEN** user selects translate mode with `output_language: "en"` and dictates in Chinese
- **THEN** Client sends `POST /polish` with `options.task: "translate"` and `options.output_language: "en"` and receives English text

### Requirement: Display raw transcript
The system SHALL display the raw transcript from the Engine response alongside the polished text.

#### Scenario: Show raw and polished text
- **WHEN** Engine returns a polish response with both `text` and `raw_transcript`
- **THEN** Client stores both values in the transcription record for user review

### Requirement: Handle polish errors gracefully
The system SHALL handle Engine polish errors and display meaningful feedback.

#### Scenario: Engine returns STT failure
- **WHEN** Engine returns 502 `STT_FAILURE` during audio-mode polish
- **THEN** Client displays "Speech recognition failed" error to user

#### Scenario: Engine returns LLM failure
- **WHEN** Engine returns 502 `LLM_FAILURE`
- **THEN** Client displays "Text polishing failed" error and offers to paste raw transcript as fallback

#### Scenario: Engine not configured
- **WHEN** Engine returns 503 `NOT_CONFIGURED`
- **THEN** Client prompts user to configure API settings
