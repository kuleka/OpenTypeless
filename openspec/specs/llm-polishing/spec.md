# llm-polishing Specification

## Purpose

Define the LLM polishing service that takes text and a prompt, calls any OpenAI Chat Completions-compatible API, and returns polished text.

## Requirements

### Requirement: Provider-agnostic LLM polishing
The engine SHALL polish text using any OpenAI Chat Completions-compatible API. The API connection info (`api_base`, `api_key`, `model`) SHALL be provided by the client via `POST /config`.

#### Scenario: Successful polishing
- **WHEN** a prompt (system message + user message) and model name are provided
- **THEN** the service SHALL call `{llm.api_base}/chat/completions` with the configured `llm.api_key` and return the polished text from the LLM response

#### Scenario: Not configured
- **WHEN** LLM config has not been provided via `POST /config` and polishing is requested
- **THEN** the service SHALL raise a clear error indicating that LLM is not configured

#### Scenario: API error
- **WHEN** the LLM API returns an error response
- **THEN** the service SHALL raise an `LLMError` with the error details

#### Scenario: Request timeout
- **WHEN** the LLM API does not respond within 30 seconds
- **THEN** the service SHALL raise an `LLMError` indicating timeout

### Requirement: Configurable model selection
The LLM service SHALL accept a model identifier per request, defaulting to the `llm.model` value from `POST /config`.

#### Scenario: Default model
- **WHEN** no model is specified in the `/polish` request `options.model`
- **THEN** the service SHALL use the `llm.model` value provided in `POST /config`

#### Scenario: Per-request model override
- **WHEN** `options.model` is set to `google/gemini-2.0-flash-001` in the `/polish` request
- **THEN** the service SHALL use that model for this request, overriding the config default
