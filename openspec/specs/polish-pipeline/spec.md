# polish-pipeline Specification

## Purpose

Define the polish pipeline endpoint that accepts text and context, orchestrates LLM polishing, and returns the polished text with metadata.

## Requirements

### Requirement: Full polish endpoint
The engine SHALL expose `POST /polish` that accepts `text` (required) and `context`, and returns polished text with metadata.

#### Scenario: Successful polish request
- **WHEN** a POST request is sent to `/polish` with valid `text` and `context`
- **THEN** the server SHALL return JSON with `text` (polished), `raw_transcript`, `task` (the executed task type), `context_detected` (scene name), `model_used`, `llm_ms`, and `total_ms`

#### Scenario: Missing text
- **WHEN** a POST request is sent to `/polish` without `text` or with empty `text`
- **THEN** the server SHALL return HTTP 422 with a validation error

### Requirement: Latency tracking
The engine SHALL measure and report latency for the LLM stage and total request duration in the response.

#### Scenario: Latency breakdown in response
- **WHEN** a successful polish request completes
- **THEN** the response SHALL include `llm_ms` (LLM duration) and `total_ms` (end-to-end duration) as integers

### Requirement: Pipeline error handling
The engine SHALL handle errors at each pipeline stage gracefully.

#### Scenario: LLM failure
- **WHEN** the LLM service fails during a polish request
- **THEN** the server SHALL return HTTP 502 with an error message indicating LLM failure

### Requirement: Task types
The engine SHALL support multiple task types via `options.task`, defaulting to `"polish"`. Each task type uses a different prompt strategy.

#### Scenario: Polish task (default)
- **WHEN** `options.task` is `"polish"` or not specified
- **THEN** the engine SHALL use the scene-appropriate polishing prompt and return text in the same language as the input

#### Scenario: Translate task
- **WHEN** `options.task` is `"translate"` and `options.output_language` is `"en"`
- **THEN** the engine SHALL use a translation prompt and return the text translated into the specified `output_language`

#### Scenario: Translate without output_language
- **WHEN** `options.task` is `"translate"` but `options.output_language` is not provided
- **THEN** the server SHALL return HTTP 422 with error code `VALIDATION_ERROR` and message `"output_language is required when task is translate"`

### Requirement: Request defaults
The engine SHALL apply sensible defaults for optional fields in the polish request.

#### Scenario: Default model
- **WHEN** `options.model` is not specified in the `/polish` request
- **THEN** the engine SHALL use the `llm.model` value from `POST /config`

#### Scenario: Empty app context
- **WHEN** `context` is not provided or empty
- **THEN** the engine SHALL use the `default` scene for prompt routing

### Requirement: Configuration prerequisite
The engine SHALL require `POST /config` to be called before processing any `/polish` request.

#### Scenario: Polish before configuration
- **WHEN** a POST request is sent to `/polish` before `POST /config` has been called
- **THEN** the server SHALL return HTTP 503 with error code `NOT_CONFIGURED` and a message indicating that the engine needs to be configured first
