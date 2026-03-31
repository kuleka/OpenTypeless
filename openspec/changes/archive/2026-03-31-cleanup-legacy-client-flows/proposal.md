## Why

Phase 1 and Phase 2 made the Engine-backed dictation path the product baseline, but the macOS client still carries a few provider-specific legacy flows from the old Pindrop architecture. The biggest leftovers are `quick capture note` and the remaining runtime dependencies on `AIEnhancementService`, which keep duplicate settings, hotkeys, and orchestration paths alive after the main app has already standardized on Engine-backed transcription and polish.

This cleanup is needed now because the current baseline is finally stable enough to remove the old paths instead of carrying them forward into later releases and future client ports.

## What Changes

- **BREAKING** Retire the `quick capture note` workflow from the active product surface, including its hotkeys, recording state, and note-editor launch path.
- Remove runtime use of `AIEnhancementService` from active macOS client flows so the app no longer depends on provider-specific AI enhancement code for current dictation behavior.
- Simplify settings and stored configuration by removing retired quick-capture controls and legacy AI-only configuration from the active UI.
- Preserve the existing notes data model and manual note editing/store behavior, but stop treating note capture and note metadata enhancement as part of the supported dictation product flow.
- Update tests and contributor docs so the cleaned-up baseline is explicit.

## Capabilities

### New Capabilities
- `legacy-client-flows`: Defines which legacy client-only flows are retired and what behavior replaces them in the supported product baseline.

### Modified Capabilities
- `client-settings`: Active settings must stop surfacing retired quick-capture and legacy AI-only controls, while preserving the Engine-backed configuration used by current flows.

## Impact

- Affected code: `clients/macos/Pindrop/AppCoordinator.swift`, `clients/macos/Pindrop/Services/SettingsStore.swift`, `clients/macos/Pindrop/UI/Settings/*`, `clients/macos/Pindrop/Services/NotesStore.swift`, `clients/macos/Pindrop/Services/AIEnhancementService.swift`
- Affected UX: hotkeys settings, Engine & AI settings, notes-related entry points, contributor documentation
- APIs: no Engine HTTP contract changes
- Dependencies: no new dependencies; expected result is less runtime dependence on legacy provider-specific code
