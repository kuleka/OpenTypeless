## ADDED Requirements

### Requirement: PolishResult SHALL carry timing metadata
`PolishResult` SHALL include `llmMs: Int?` and `totalMs: Int?` fields mapped from the Engine `PolishResponse`. In fallback or error cases, these fields SHALL be nil.

#### Scenario: Successful polish
- **WHEN** `PolishService.polish()` receives a successful `PolishResponse` with `llm_ms: 280` and `total_ms: 320`
- **THEN** the returned `PolishResult` SHALL have `llmMs: 280` and `totalMs: 320`

#### Scenario: Fallback polish
- **WHEN** `PolishService.polish()` encounters an LLM failure and falls back
- **THEN** the returned `PolishResult` SHALL have `llmMs: nil` and `totalMs: nil`

### Requirement: TranscriptionRecord SHALL persist polish metadata
`TranscriptionRecord` SHALL include `polishMs: Int?` (mapped from `totalMs`) and `contextDetected: String?` as persistent optional fields. A SwiftData schema migration (V5 → V6) SHALL add these fields using lightweight migration.

#### Scenario: Save polished transcription
- **WHEN** a batch transcription is polished with `totalMs: 320` and `contextDetected: "email"`
- **THEN** the saved `TranscriptionRecord` SHALL have `polishMs: 320` and `contextDetected: "email"`

#### Scenario: Save unpolished transcription
- **WHEN** a streaming transcription is saved without polish
- **THEN** `polishMs` and `contextDetected` SHALL be nil

#### Scenario: Schema migration from V5
- **WHEN** the app launches with an existing V5 database
- **THEN** the lightweight migration to V6 SHALL succeed and existing records SHALL have `polishMs: nil` and `contextDetected: nil`

### Requirement: HistoryView SHALL display polish timing
When a `TranscriptionRecord` has a non-nil `polishMs`, the HistoryView metadata row SHALL append the timing in milliseconds to the LLM model label.

#### Scenario: Record with polish timing
- **WHEN** a history row displays a record with `enhancedWith: "llama-3.3-70b"` and `polishMs: 320`
- **THEN** the sparkles metadata item SHALL display "via llama-3.3-70b (320ms)"

#### Scenario: Record without polish timing
- **WHEN** a history row displays a record with `enhancedWith: "llama-3.3-70b"` and `polishMs: nil`
- **THEN** the sparkles metadata item SHALL display "via llama-3.3-70b" (no timing suffix)

### Requirement: HistoryView SHALL display detected context
When a `TranscriptionRecord` has a non-nil `contextDetected` that is not `"default"`, the HistoryView metadata row SHALL display a context icon and label.

#### Scenario: Email context detected
- **WHEN** a history row displays a record with `contextDetected: "email"`
- **THEN** an envelope icon with text "email" SHALL be displayed in the metadata row

#### Scenario: Default context
- **WHEN** a history row displays a record with `contextDetected: "default"`
- **THEN** no context metadata item SHALL be displayed

#### Scenario: No context data
- **WHEN** a history row displays a record with `contextDetected: nil`
- **THEN** no context metadata item SHALL be displayed
