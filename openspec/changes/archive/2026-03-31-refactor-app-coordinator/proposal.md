## Why

AppCoordinator is a 3,900-line God Object handling 11+ distinct responsibilities: recording flow, hotkey management, event tap lifecycle, floating indicator state, live context sessions, engine runtime management, settings observation, media transcription, and various UI action handlers. This violates the Single Responsibility Principle, makes the code hard to navigate, test, and modify safely. Every feature change risks unintended side effects across unrelated subsystems. Refactoring now reduces risk for upcoming features (E2E tests, distribution, custom context rules).

## What Changes

- Extract **RecordingCoordinator**: recording start/stop, push-to-talk, streaming transcription, audio processing, polish orchestration (~720 lines, lines 2146-2864)
- Extract **HotkeyCoordinator**: hotkey registration, validation, conflict detection, translate hotkey handling (~200 lines, lines 1347-1546)
- Extract **EventTapManager**: Escape/modifier key event tap setup, teardown, recovery, global monitor fallbacks (~490 lines, lines 2865-3354)
- Extract **FloatingIndicatorCoordinator**: indicator visibility, type management, recording/processing state transitions, temporary hide (~250 lines, lines 1676-1789 + 3355-3401)
- Extract **ContextSessionCoordinator**: live context capture, polling, workspace detection, app focus observation (~360 lines, lines 1790-2145)
- Extract **EngineRuntimeCoordinator**: engine config readiness, health evaluation, runtime state updates, config sync scheduling (~300 lines, scattered in Lifecycle section)
- AppCoordinator becomes a **thin orchestrator** that wires extracted coordinators together and delegates to them
- No behavioral changes — pure structural refactor, all existing functionality preserved

## Capabilities

### New Capabilities
- `coordinator-decomposition`: Extraction of 6 focused coordinator/manager types from AppCoordinator, each with a single responsibility and clear interface boundary

### Modified Capabilities

(none — this is a pure internal refactor with no requirement-level changes)

## Impact

- **Code**: `clients/macos/Pindrop/AppCoordinator.swift` split into 7 files (slimmed coordinator + 6 extracted types)
- **New files**: `RecordingCoordinator.swift`, `HotkeyCoordinator.swift`, `EventTapManager.swift`, `FloatingIndicatorCoordinator.swift`, `ContextSessionCoordinator.swift`, `EngineRuntimeCoordinator.swift`
- **Tests**: Existing tests should pass unchanged; extracted types become independently testable
- **Dependencies**: No new external dependencies. Internal dependency graph becomes explicit via init injection
- **Risk**: Medium — large mechanical refactor, but no logic changes. Build verification at each step mitigates regression risk
