## Context

Phase 1 completed the technical Engine integration for the macOS client's main dictation flow, but the runtime experience still reflects an engineer-oriented workflow. The app can already talk to Engine, push config, and recover in some degraded paths, yet users still have to infer too much from a binary connected/disconnected status and a few toasts.

The main gaps are cross-cutting:

- `AppCoordinator` owns startup sync and some fallback behavior
- `EngineClient` owns health/config calls
- settings UI owns host/port and provider editing
- output behavior differs between local STT mode and remote STT mode

This change needs a coherent runtime model across those pieces, not just more copy in one view.

## Goals / Non-Goals

**Goals:**
- Introduce a clear Engine runtime state model that distinguishes offline, configuration-incomplete, syncing, and ready states.
- Make Engine & AI settings the primary onboarding and recovery surface for first-run and reconnection scenarios.
- Add explicit recheck / reconnect behavior so users can recover after starting Engine or changing settings without restarting the app.
- Preserve Phase 1 behavior where local STT can continue to function when Engine is unavailable.
- Improve contributor and maintainer documentation for local runtime setup and debugging.

**Non-Goals:**
- Automatically installing, downloading, or bundling Engine in the macOS app.
- Auto-launching Engine as a managed subprocess or launch agent.
- Removing legacy auxiliary flows such as quick capture note.
- Changing the Engine HTTP API contract.
- Adding user-customizable scene rules or prompt editing in this change.

## Decisions

### 1. Introduce an explicit Engine runtime state model

**Choice**: Represent runtime onboarding with a richer state model such as `checking`, `offline`, `needsConfiguration`, `syncing`, `ready`, and `error`.

**Why**: The current connected/disconnected framing is not enough to explain whether the next user action should be “start Engine”, “fill in keys”, “retry sync”, or “dictate locally”.

**Alternatives considered**:
- Keep a simple boolean connection state and add more copy in the UI. Rejected because it still forces views to infer too much state from partial signals.
- Let each view derive its own status from raw health/config calls. Rejected because it would duplicate logic and drift over time.

### 2. Use settings as the onboarding hub, not a separate first-run wizard

**Choice**: Put the primary setup guidance, state display, and recovery actions inside Engine & AI settings.

**Why**: The relevant controls already live there: host/port, STT mode, provider presets, API keys, and connection status. Users need one coherent place to understand and fix runtime issues.

**Alternatives considered**:
- Add a standalone first-run modal or wizard. Rejected for now because it adds more UI flow complexity and another state machine before the product has stable packaging and distribution.
- Use only transient toasts. Rejected because toasts are not sufficient for multi-step recovery.

### 3. Recheck is explicit and deterministic

**Choice**: Re-run runtime evaluation on startup, on relevant settings changes, and when the user explicitly taps a recheck/reconnect action.

**Why**: This keeps the behavior predictable and easy to test. It also avoids background polling that could create noisy state flapping or duplicate config pushes.

**Alternatives considered**:
- Continuous background polling. Rejected because it increases complexity, network chatter, and UI noise for limited product value at this stage.
- App restart as the only recovery path. Rejected because it is poor UX and unnecessary.

### 4. Configuration readiness is mode-aware

**Choice**: Runtime readiness must be evaluated against the active STT mode.

**Why**:
- In local STT mode, Engine can still be useful for `/polish` with only LLM configuration.
- In remote STT mode, Engine must also have valid STT configuration before the product is truly ready.

This means “Engine is reachable” is not equivalent to “Engine is ready”.

**Alternatives considered**:
- Treat any successful `GET /health` as ready. Rejected because it hides the most common broken state: Engine is online but missing required config.

### 5. Do not auto-launch Engine in this change

**Choice**: Show actionable instructions and recovery actions, but keep Engine startup as a manual step for now.

**Why**: Packaging, process supervision, log routing, and crash recovery are a larger product/distribution concern. This change should clarify the runtime flow first without coupling the app to a process-management design we may later replace.

**Alternatives considered**:
- Launch Engine as a subprocess from the app. Rejected for now because it complicates packaging and process lifecycle.
- Use a launch agent. Rejected because it is a distribution/deployment decision, not just a UI change.

## Risks / Trade-offs

- **[Richer state model increases UI logic]** → Mitigation: centralize state evaluation in one runtime owner instead of deriving it ad hoc in multiple views.
- **[Users may still expect one-click startup]** → Mitigation: make manual startup instructions and recheck actions explicit now, and keep auto-start for a future packaging-focused change.
- **[Mode-aware readiness can confuse contributors]** → Mitigation: document local-vs-remote readiness clearly in the settings copy and contributor docs.
- **[Startup sync may feel noisy]** → Mitigation: keep rechecks deterministic and bounded to startup, settings changes, and explicit user actions.

## Migration Plan

1. Add the runtime state model and evaluation path around existing health/config sync behavior.
2. Update Engine & AI settings to display richer states, required next actions, and manual recheck.
3. Update startup and dictation fallback behavior to use the shared runtime state.
4. Add app-level tests for state evaluation and recovery transitions.
5. Update contributor-facing docs to describe the intended local runtime flow.

Rollback is straightforward because this change sits on top of the current API contract and Phase 1 implementation. Reverting would restore the simpler Phase 1 connection behavior without data migration.

## Open Questions

- Should a future release bundle Engine with the macOS app, or keep them as separately launched components?
- Should runtime logs or recent sync errors be visible directly in the settings UI, or remain developer-facing only for now?
- Should app activation or menu-bar interaction also trigger a lightweight recheck, or is startup + settings change + explicit recheck enough?
