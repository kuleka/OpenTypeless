## ADDED Requirements

### Requirement: Provider-agnostic STT transcription
The engine SHALL transcribe audio to text using any OpenAI Whisper-compatible API. The API connection info (`api_base`, `api_key`, `model`) SHALL be provided by the client via `POST /config`.

#### Scenario: Successful transcription
- **WHEN** valid audio bytes (WAV or M4A) are sent to the STT service
- **THEN** the service SHALL call `{stt.api_base}/audio/transcriptions` with the configured `stt.api_key` and `stt.model`, and return the raw transcript text string

#### Scenario: Not configured
- **WHEN** STT config has not been provided via `POST /config` and transcription is requested
- **THEN** the service SHALL raise a clear error indicating that STT is not configured

#### Scenario: API error
- **WHEN** the STT API returns an error response
- **THEN** the service SHALL raise an `STTError` with the error details

#### Scenario: Request timeout
- **WHEN** the STT API does not respond within 30 seconds
- **THEN** the service SHALL raise an `STTError` indicating timeout

### Requirement: Auto language detection
The STT service SHALL support automatic language detection by default, with an option to specify a language code.

#### Scenario: Auto-detect language
- **WHEN** language is set to `"auto"` or not specified
- **THEN** the service SHALL omit the language parameter, letting the STT provider auto-detect the spoken language

#### Scenario: Specified language
- **WHEN** language is set to `"zh"`
- **THEN** the service SHALL pass the language hint to the STT API
