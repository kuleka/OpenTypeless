# prompt-routing Specification

## Purpose

Define the scene detection and prompt assembly system that routes raw transcripts to the appropriate prompt template based on app context.

## Requirements

### Requirement: Scene detection from app context
The engine SHALL detect the current scene type based on the app's bundle ID and window title, using configurable match rules.

#### Scenario: Match by app bundle ID
- **WHEN** app context has `app_id: "com.apple.mail"`
- **THEN** the detected scene SHALL be `email`

#### Scenario: Match by window title
- **WHEN** app context has `window_title: "Inbox - Gmail - Google Chrome"`
- **THEN** the detected scene SHALL be `email` (matched via window_title_contains: "Gmail")

#### Scenario: No match falls back to default
- **WHEN** app context has `app_id: "com.unknown.app"` with no matching window title
- **THEN** the detected scene SHALL be `default`

#### Scenario: First match wins
- **WHEN** app context could match multiple scenes
- **THEN** the first matching scene in the defined order SHALL be selected

### Requirement: YAML-based prompt templates
The engine SHALL load prompt templates from a YAML file (`prompts/defaults.yaml`) containing a shared system prompt and per-scene context prompts with match rules.

#### Scenario: Load default prompts
- **WHEN** the server starts
- **THEN** it SHALL load prompts from the bundled `defaults.yaml`

#### Scenario: Custom prompts path
- **WHEN** `OPEN_TYPELESS_PROMPTS_PATH` environment variable is set
- **THEN** the engine SHALL load prompts from that path instead

### Requirement: Three-layer prompt assembly
The engine SHALL assemble prompts in three layers: system prompt (shared rules), context prompt (scene-specific), and user message (raw transcript).

#### Scenario: Email scene assembly
- **WHEN** scene is `email` and raw transcript is "hi tom thanks for the report"
- **THEN** the assembled prompt SHALL contain the shared system rules, email-specific formatting rules, and the raw transcript as user message

#### Scenario: Default scene assembly
- **WHEN** scene is `default`
- **THEN** the assembled prompt SHALL contain the shared system rules, default context rules, and the raw transcript

### Requirement: Scene types
The engine SHALL support 6 scene types: `email`, `chat`, `ai_chat`, `document`, `code`, `default`.

#### Scenario: All scene types are recognized
- **WHEN** any of the 6 scene types is used
- **THEN** the engine SHALL load the corresponding prompt template without error

### Requirement: View and update contexts via API
The engine SHALL expose `GET /contexts` to list current scene configurations and `POST /contexts` to update the in-memory configuration.

#### Scenario: List contexts
- **WHEN** a GET request is sent to `/contexts`
- **THEN** the server SHALL return all scene names with their match rules

#### Scenario: Update contexts
- **WHEN** a POST request with a new scene configuration is sent to `/contexts`
- **THEN** the server SHALL update the in-memory scene config (not persisted to disk)
