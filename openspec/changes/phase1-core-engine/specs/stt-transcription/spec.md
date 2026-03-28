## ADDED Requirements

### Requirement: Groq Whisper STT transcription
The engine SHALL transcribe audio to text using the Groq Whisper API. The API key SHALL be read from `GROQ_API_KEY` environment variable.

#### Scenario: Successful transcription
- **WHEN** valid audio bytes (WAV or M4A) are sent to the STT service
- **THEN** the service SHALL return the raw transcript text string

#### Scenario: Missing API key
- **WHEN** `GROQ_API_KEY` is not set and transcription is requested
- **THEN** the service SHALL raise a clear error indicating the missing API key

#### Scenario: API error
- **WHEN** the Groq API returns an error response
- **THEN** the service SHALL raise an `STTError` with the error details

#### Scenario: Request timeout
- **WHEN** the Groq API does not respond within 30 seconds
- **THEN** the service SHALL raise an `STTError` indicating timeout

### Requirement: Auto language detection
The STT service SHALL support automatic language detection by default, with an option to specify a language code.

#### Scenario: Auto-detect language
- **WHEN** language is set to `"auto"` or not specified
- **THEN** the service SHALL let Groq auto-detect the spoken language

#### Scenario: Specified language
- **WHEN** language is set to `"zh"`
- **THEN** the service SHALL pass the language hint to the Groq API
