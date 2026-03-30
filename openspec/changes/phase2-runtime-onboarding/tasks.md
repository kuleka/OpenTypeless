## 1. Runtime State Model

- [ ] 1.1 Define a shared Engine runtime state model covering checking, offline, configuration-incomplete, syncing, ready, and recoverable error states
- [ ] 1.2 Update the Engine connectivity layer to evaluate runtime state from `GET /health`, local settings, and config sync results
- [ ] 1.3 Add an explicit recheck entry point that can be triggered from startup and user actions without restarting the app

## 2. Settings Surface

- [ ] 2.1 Update Engine & AI settings to display the richer runtime state instead of a simple connected/disconnected indicator
- [ ] 2.2 Add actionable setup guidance for offline and configuration-incomplete states in the settings surface
- [ ] 2.3 Add a recheck/reconnect action in settings and prevent duplicate checks while evaluation is already running
- [ ] 2.4 Ensure host/port and provider changes refresh the visible runtime state against the updated configuration

## 3. App Runtime Behavior

- [ ] 3.1 Update startup sync flow to populate the shared runtime state and surface deterministic results
- [ ] 3.2 Preserve local-STT dictation output when Engine runtime is unavailable while showing actionable recovery guidance
- [ ] 3.3 Stop remote-STT dictation attempts early when Engine runtime is not ready and surface the correct next action
- [ ] 3.4 Update runtime error messaging so later Engine failures transition the app back into a recoverable non-ready state

## 4. Verification And Docs

- [ ] 4.1 Add app-level tests for runtime state evaluation, explicit recheck, and mode-aware readiness
- [ ] 4.2 Add UI or view-model coverage for the settings runtime states and manual recheck action
- [ ] 4.3 Update contributor-facing docs to describe local Engine startup, recheck behavior, and mode-aware readiness expectations
