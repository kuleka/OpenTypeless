## 1. Legacy Settings Consolidation

- [x] 1.1 Add a targeted migration path from legacy AI-only configuration into Engine LLM settings when Engine LLM fields are still empty
- [x] 1.2 Retire stored quick-capture hotkey values from the active supported configuration model
- [x] 1.3 Remove legacy AI-only settings from active settings persistence and runtime reads where they are no longer needed

## 2. Runtime Flow Cleanup

- [x] 2.1 Remove quick capture note state, hotkey handling, and note-editor launch flow from `AppCoordinator`
- [x] 2.2 Ensure standard dictation remains on the existing Engine-backed `transcribe/polish/output` path after quick capture removal
- [x] 2.3 Remove active `AIEnhancementService` runtime wiring from `AppCoordinator` and simplify notes-related flows so they no longer depend on legacy provider-specific enhancement
- [x] 2.4 Delete or isolate any now-unused legacy helper code that would otherwise keep the retired flow reachable

## 3. Settings And UI Cleanup

- [x] 3.1 Remove retired note-capture hotkey controls from Hotkeys settings
- [x] 3.2 Remove legacy AI-only configuration controls from the active Engine & AI settings surface
- [x] 3.3 Update settings copy to reflect the supported Engine-backed baseline only

## 4. Verification And Docs

- [x] 4.1 Add tests covering quick-capture retirement, legacy settings migration, and the absence of retired hotkey registration
- [x] 4.2 Add tests covering the cleaned-up notes/runtime behavior without `AIEnhancementService`
- [x] 4.3 Update contributor-facing docs and planning docs to describe the cleaned-up baseline and removed legacy flows
