## Context

AppCoordinator.swift is a 3,900-line `@MainActor @Observable final class` that acts as the central nervous system of the macOS client. It holds 100+ properties, 130+ private methods, and 23 service/UI controller dependencies. Every feature touches this file.

The codebase is inherited from Pindrop and has been incrementally modified for OpenTypeless. The coordinator pattern was reasonable at smaller scale but has grown past maintainability. The class cannot be unit-tested in isolation because its responsibilities are entangled.

All extracted types must remain `@MainActor` since they interact with AppKit/SwiftUI. The existing `@Observable` macro on AppCoordinator provides SwiftUI reactivity — extracted types that own observable state will also need `@Observable`.

## Goals / Non-Goals

**Goals:**
- Reduce AppCoordinator to a thin orchestrator (~800-1000 lines) that wires sub-coordinators
- Each extracted type owns a single responsibility with explicit dependencies via init injection
- Preserve all existing behavior — zero user-facing changes
- Make extracted types independently testable
- Follow SOLID principles: each type has one reason to change
- Follow macOS/Swift conventions: `@MainActor`, protocol-based injection, value types for snapshots

**Non-Goals:**
- Changing any user-facing behavior or API
- Introducing new protocols/abstractions beyond what extraction requires
- Refactoring services that AppCoordinator depends on (e.g., SettingsStore, TranscriptionService)
- Adding new tests (that's a follow-up; this change focuses on extraction)
- Changing the `@Observable` observation pattern or SwiftUI integration
- Extracting the 310-line `init()` — it's the wiring glue and belongs in the orchestrator

## Decisions

### 1. Extract 6 focused types, keep AppCoordinator as orchestrator

**Decision**: Extract RecordingCoordinator, HotkeyCoordinator, EventTapManager, FloatingIndicatorCoordinator, ContextSessionCoordinator, EngineRuntimeCoordinator. AppCoordinator retains init/wiring, lifecycle (start/onboarding), settings observation, and small action handlers.

**Why not fewer extractions?** Recording + EventTap are deeply coupled (Escape cancels recording), but they have different lifecycles and can communicate via a delegate/closure. Merging them would create another 1200-line class.

**Why not more?** Small handlers (toggle output mode, export transcript, open history) are 5-20 lines each. Extracting them adds file overhead without meaningful benefit. They stay in AppCoordinator.

### 2. Communication via closures, not protocols

**Decision**: Sub-coordinators call back to AppCoordinator via closures injected at init time, not via formal delegate protocols.

**Alternative considered**: Delegate protocols (e.g., `RecordingCoordinatorDelegate`). Rejected because:
- These types have 1 consumer (AppCoordinator) — protocol abstraction adds ceremony without value
- Closures are simpler, more Swifty for single-consumer callbacks
- Easier to set up in the existing init() wiring

**Exception**: If a sub-coordinator needs to expose observable state to SwiftUI views, it uses `@Observable` directly (e.g., `RecordingCoordinator.isRecording`).

### 3. Shared state via explicit parameters, not shared mutable state

**Decision**: When sub-coordinators need state from each other, they receive it as method parameters or read-only properties, not by sharing mutable references.

**Example**: RecordingCoordinator needs to know `pendingTranslateTask` and `settingsStore.translateOutputLanguage` at the time of processing. These are passed when the recording completes, not stored as shared mutable state.

### 4. File organization: flat in Pindrop/ directory

**Decision**: New files go in `clients/macos/Pindrop/Coordinators/` directory.

**Why not nested deeper?** The existing codebase uses `Services/`, `UI/`, `Mocks/` — a single `Coordinators/` directory follows the same pattern and avoids over-nesting.

### 5. Extraction order: bottom-up by dependency

**Decision**: Extract in this order:
1. **EventTapManager** — no dependencies on other extracted types, purely low-level
2. **FloatingIndicatorCoordinator** — depends only on existing UI controllers
3. **HotkeyCoordinator** — depends only on HotkeyManager + SettingsStore
4. **EngineRuntimeCoordinator** — depends on SettingsStore + engine handlers
5. **ContextSessionCoordinator** — depends on ContextEngineService + SettingsStore
6. **RecordingCoordinator** — depends on most other extracted types (called last)

Each extraction is a compilable step — build verification after each.

### 6. Observable state ownership

**Decision**: Observable properties move to the type that owns the responsibility:
- `isRecording`, `isProcessing` → RecordingCoordinator (marked `@Observable`)
- `activeModelName` → stays in AppCoordinator (model management is small, stays)
- `error` → stays in AppCoordinator (set from multiple sources)

SwiftUI views that read `coordinator.isRecording` will read `coordinator.recordingCoordinator.isRecording` instead. This is a minor access path change.

## Risks / Trade-offs

**[Risk] Large mechanical diff** → Mitigate by extracting one type at a time with build verification. Each step is independently revertible.

**[Risk] Accidental behavior change during move** → Mitigate by doing pure cut-paste first, then adjusting access modifiers. No logic changes in the extraction PR.

**[Risk] SwiftUI observation breakage** → `@Observable` propagates through reference types. If AppCoordinator holds `let recordingCoordinator: RecordingCoordinator` and views access `coordinator.recordingCoordinator.isRecording`, SwiftUI observation still works. Verify with manual UI testing.

**[Risk] Increased init() complexity** → AppCoordinator's init already constructs 23 services. Adding 6 more sub-coordinators is manageable since they mostly wrap existing properties.

**[Trade-off] More files** → 6 new files is a net readability win. 7 files averaging 400-600 lines each vs 1 file at 3,900 lines.

**[Trade-off] Slight indirection** → `coordinator.handleToggleRecording()` becomes `coordinator.recordingCoordinator.handleToggle()`. Acceptable for the separation of concerns gained.
