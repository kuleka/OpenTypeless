## Context

The macOS client now has a clear Engine-backed baseline for runtime evaluation, transcription, polish, and settings. The main dictation path no longer needs the old provider-specific enhancement architecture, but a few legacy paths still remain:

- `AppCoordinator` still owns a `quick capture note` branch with dedicated recording state, hotkeys, and note-editor launch behavior.
- `AIEnhancementService` still exists in active runtime wiring for quick capture note and note metadata generation.
- settings still carry quick-capture hotkeys and legacy AI-only configuration alongside the current Engine configuration.

These leftovers are not just code smell. They keep duplicate user-facing controls and provider-specific assumptions alive after the product baseline has already moved to `Client + Engine`.

## Goals / Non-Goals

**Goals:**
- Retire the unsupported `quick capture note` product flow from the active macOS client.
- Remove active runtime dependence on `AIEnhancementService` from the supported client experience.
- Consolidate settings around the Engine-backed configuration that the product actually uses.
- Preserve notes storage and manual note editing without requiring legacy AI-specific configuration.
- Leave the codebase and docs in a state where future work starts from the Engine-backed baseline, not from parallel legacy paths.

**Non-Goals:**
- Designing a new Engine-backed note capture product flow in this change.
- Adding new Engine HTTP endpoints for notes or metadata generation.
- Redesigning the notes UI or data model.
- Renaming `Pindrop` targets, bundle identifiers, or broad project branding leftovers.

## Decisions

### 1. Retire quick capture note instead of migrating it

**Choice**: Remove `quick capture note` from the active product surface instead of porting it to the Engine architecture in this cleanup.

**Why**: The current product baseline is dictation to cursor, not note capture. Migrating the feature now would keep an unsupported branch alive and expand the scope into product design rather than cleanup.

**Alternatives considered**:
- Keep the feature but hide it. Rejected because hidden code paths still create runtime and maintenance cost.
- Rebuild quick capture note on top of Engine now. Rejected because it would require new UX, new prompt semantics, and possibly new Engine capability decisions.

### 2. Remove AIEnhancementService from active runtime wiring

**Choice**: Stop using `AIEnhancementService` in `AppCoordinator`, `NotesStore`, and settings-backed current flows.

**Why**: The supported client experience should no longer depend on provider-specific endpoint/key/model logic after Engine-backed polish is the baseline. Leaving the service wired in keeps duplicate config and contradictory mental models alive.

**Alternatives considered**:
- Keep `AIEnhancementService` as an isolated note-only helper. Rejected because it still keeps legacy configuration alive and turns note behavior into a special case.
- Re-implement note enhancement on top of Engine in this cleanup. Rejected because it is a future product feature, not cleanup.

### 3. Consolidate settings on the Engine-backed configuration and migrate only when needed

**Choice**: Remove retired settings from the active UI and perform a one-time migration only when legacy AI values are the only available LLM configuration.

**Why**: Users should not lose a working provider configuration just because the app removes the old surface, but the app also should not keep showing two overlapping LLM setup models.

**Alternatives considered**:
- Delete legacy values without migration. Rejected because it risks silently breaking existing local setups.
- Keep both old and new settings indefinitely. Rejected because it undermines the cleanup.

### 4. Keep notes CRUD, remove note-capture coupling

**Choice**: Preserve notes persistence and editor functionality, but decouple it from dictation hotkeys and automatic AI metadata generation.

**Why**: Existing note data should remain intact, and the app can still support manual note management without keeping the legacy dictation-to-note path alive.

**Alternatives considered**:
- Remove the notes subsystem entirely. Rejected because it is a larger product decision and not required to eliminate the legacy dictation flow.
- Keep note metadata generation as a hidden helper. Rejected because it would still depend on the legacy provider-specific stack.

## Risks / Trade-offs

- **[Feature removal surprises existing users]** → Mitigation: document the removal clearly in contributor docs and release-facing notes, and keep standard dictation behavior unchanged.
- **[Legacy config migration may be ambiguous]** → Mitigation: only migrate into Engine LLM settings when Engine LLM fields are still empty, and prefer deterministic field mapping over heuristic merging.
- **[Residual dead code remains after runtime cleanup]** → Mitigation: remove hotkeys, coordinator branches, settings UI, and runtime injection together; use search-based verification and app-level tests.
- **[Future note intelligence may need a new design]** → Mitigation: treat that as a separate Engine-backed feature change rather than preserving the old implementation.

## Migration Plan

1. Add a targeted settings migration path for legacy AI-only values into the Engine LLM configuration when appropriate.
2. Remove quick capture note hotkeys, state, and note-launch behavior from the active app coordinator and settings UI.
3. Remove `AIEnhancementService` from active runtime wiring and simplify notes behavior so manual note storage still works.
4. Update tests and docs to describe the cleaned-up baseline.
5. Verify no supported runtime path still depends on the retired legacy flow.

Rollback is straightforward because the change is client-local and does not alter persisted notes data or the Engine API contract. Reverting the commit restores the legacy paths if needed.

## Open Questions

- Should `AIEnhancementService.swift` be deleted entirely in this change, or retained temporarily if only tests/reference code remain?
- Should a future Engine-backed note capture flow reuse the notes subsystem, or should note capture return as a separate feature with its own UX?
