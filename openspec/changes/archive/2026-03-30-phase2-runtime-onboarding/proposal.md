## Why

Phase 1 made the Engine and macOS client technically usable, but the product still assumes a contributor-level setup experience. New users can still end up in ambiguous states such as “Engine not running”, “Engine reachable but not configured”, or “settings saved locally but not yet pushed”, without clear recovery steps. This is the next bottleneck before broader dogfooding or release hardening.

## What Changes

- Add a user-facing runtime onboarding flow for the macOS client that explains Engine requirements, current setup state, and next actions.
- Introduce richer Engine runtime states beyond a simple connected/disconnected indicator, including actionable guidance for offline, unconfigured, and ready states.
- Add explicit reconnect / recheck behavior so users can recover after starting Engine or changing connection settings without restarting the app.
- Improve startup and settings behavior so Engine configuration sync and validation are visible, deterministic, and easier to debug.
- Document the intended local runtime flow for contributors and future release packaging work.

## Capabilities

### New Capabilities
- `runtime-onboarding`: Guide users through first-run Engine setup, explain runtime state, and provide actionable recovery steps when Engine is offline or not configured.

### Modified Capabilities
- `client-settings`: Expand Engine settings from raw connection fields into a runtime setup surface with clearer status states, validation, and recovery actions.
- `engine-client`: Extend Engine connectivity behavior from one-time health checks into explicit recheck / reconnect flows with surfaced setup-state results.

## Impact

- Affected code: macOS settings UI, AppCoordinator startup flow, Engine connectivity state handling, contributor-facing docs.
- Affected systems: `SettingsStore`, `AppCoordinator`, `EngineClient`, Engine & AI settings views, onboarding/status copy.
- No API contract break is required; this change builds on the existing `/health`, `/config`, and `/config` readback behavior.
