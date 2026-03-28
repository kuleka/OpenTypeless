## ADDED Requirements

### Requirement: OpenRouter LLM polishing
The engine SHALL polish text using the OpenRouter chat completions API. The API key SHALL be read from `OPENROUTER_API_KEY` environment variable.

#### Scenario: Successful polishing
- **WHEN** a prompt (system message + user message) and model name are provided
- **THEN** the service SHALL return the polished text from the LLM response

#### Scenario: Missing API key
- **WHEN** `OPENROUTER_API_KEY` is not set and polishing is requested
- **THEN** the service SHALL raise a clear error indicating the missing API key

#### Scenario: API error
- **WHEN** the OpenRouter API returns an error response
- **THEN** the service SHALL raise an `LLMError` with the error details

#### Scenario: Request timeout
- **WHEN** the OpenRouter API does not respond within 30 seconds
- **THEN** the service SHALL raise an `LLMError` indicating timeout

### Requirement: Configurable model selection
The LLM service SHALL accept a model identifier per request, defaulting to `minimax/minimax-m2.7`.

#### Scenario: Default model
- **WHEN** no model is specified in the request
- **THEN** the service SHALL use `minimax/minimax-m2.7`

#### Scenario: Custom model
- **WHEN** model is set to `google/gemini-2.0-flash-001`
- **THEN** the service SHALL pass that model to the OpenRouter API
