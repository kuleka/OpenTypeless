# OpenTypeless macOS Client

> Native macOS client for OpenTypeless, based on the upstream OpenTypeless app.

This directory contains the Swift macOS client used by OpenTypeless. The codebase started from [OpenTypeless](https://github.com/kuleka/OpenTypeless) and is being adapted into a thin client for the local OpenTypeless Engine.

This README describes the current OpenTypeless client state. It is not a mirror of upstream OpenTypeless product docs.

## Origin And Scope

- Upstream foundation: OpenTypeless
- Current product direction: OpenTypeless
- Current goal: keep the native macOS shell while moving STT and polish responsibilities behind the local Engine HTTP boundary

Useful references:

- [OpenTypeless root README](../../README.md)
- [Engine ↔ Client API contract](../../docs/api-contract.md)
- [macOS client Phase 1 summary](../../docs/macos-client-phase1.md)
- [Contribution guide](./CONTRIBUTING.md)

## Current Status

As of the completed Phase 1 migration:

- local transcription remains available
- remote STT is wired into the main dictation flow
- Engine-based polish is wired into the main dictation flow
- `AppCoordinator` startup sync and output pipeline are connected
- Engine settings UI and config persistence are implemented
- Engine runtime onboarding now distinguishes checking, offline, setup-needed, syncing, ready, and recoverable error states
- Settings includes a manual `Recheck` / `Reconnect` action for local Engine recovery
- UI smoke tests cover the settings fixture surfaces

The primary dictation path is now running through the `Client + Engine` split. A few auxiliary legacy flows still remain.

## Current Architecture

The current main dictation pipeline is:

```text
record audio
  -> TranscriptionService
  -> local engine OR EngineTranscriptionEngine
  -> transcript text
  -> PolishService
  -> Engine /polish
  -> output
```

Important components already in the repo:

- `OpenTypeless/Services/EngineSupport/EngineClient.swift`
- `OpenTypeless/Services/Transcription/EngineTranscriptionEngine.swift`
- `OpenTypeless/Services/TranscriptionService.swift`
- `OpenTypeless/Services/PolishService.swift`

Important migration note:

- `AIEnhancementService` and the Notes subsystem have been fully removed in the legacy cleanup pass.
- Xcode targets and many path names still use `OpenTypeless` for continuity.

## Engine Runtime Readiness

Engine runtime state is shared across startup sync, dictation fallback behavior, and the `Engine & AI` settings surface.

- `Checking` and `Syncing` mean the app is actively evaluating or pushing the current Engine configuration.
- `Offline` means `GET /health` could not reach the configured host and port.
- `Setup Needed` means Engine is reachable, but the active mode is still missing required provider settings.
- `Ready` means the current mode has what it needs for the next dictation request.
- `Needs Attention` is a recoverable runtime error such as a failed config sync or later Engine request failure.

Readiness is mode-aware:

- In `Local` STT mode, Engine only needs valid LLM settings because dictation can still run locally and use Engine for `/polish`.
- In `Remote` STT mode, Engine needs both remote STT and LLM settings before dictation is actually ready.

Recovery is also mode-aware:

- If Engine is unavailable in `Local` STT mode, the app still outputs the local transcript and shows guidance to start Engine and press `Recheck`.
- If Engine is unavailable in `Remote` STT mode, the app stops the remote dictation attempt and tells the user to start Engine or switch back to `Local`.

## Requirements

- macOS 14.0 or later
- Xcode 15+
- Apple Silicon recommended
- Microphone access for recording
- Accessibility permission if you want direct text insertion instead of clipboard-only output

## Build From Source

Clone your fork or local checkout of OpenTypeless, then work inside the macOS client directory:

```bash
cd OpenTypeless/clients/macos
open OpenTypeless.xcodeproj
```

You can also build from the command line:

```bash
xcodebuild -project OpenTypeless.xcodeproj -scheme OpenTypeless -destination 'platform=macOS' build
```

The app target is still named `OpenTypeless`.

## Recommended Test Commands

Fast isolated Engine-core tests:

```bash
cd clients/macos
swift test
```

This runs the lightweight `EngineCore` package tests for the shared Engine support layer.

Full macOS app tests:

```bash
cd clients/macos
xcodebuild test \
  -project OpenTypeless.xcodeproj \
  -scheme OpenTypeless \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/OpenTypelessDerivedData \
  -clonedSourcePackagesDirPath /tmp/OpenTypelessSourcePackages \
  -only-testing:OpenTypelessTests \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM=''
```

This is the most reliable full-app test command for the current local setup.

UI smoke tests:

```bash
cd clients/macos
xcodebuild test \
  -project OpenTypeless.xcodeproj \
  -scheme OpenTypeless \
  -testPlan UI \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/OpenTypelessUISignedDerivedData \
  -clonedSourcePackagesDirPath /tmp/OpenTypelessSourcePackages \
  CODE_SIGN_IDENTITY=- \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=''
```

## Build System

This directory includes a `justfile` for common developer tasks:

```bash
brew install just
```

Common commands:

```bash
just build
just build-release
just test
just clean
just --list
```

Maintainer-oriented release helpers still exist because the client inherited OpenTypeless's packaging flow:

```bash
just export-app
just dmg
just release-notes 1.9.0
just release 1.9.0
```

Treat these as OpenTypeless maintainer workflows for inherited packaging infrastructure, not as evidence that upstream OpenTypeless releases are current OpenTypeless releases.

## First Launch Notes

On a fresh local build, expect to:

1. grant microphone permission
2. grant accessibility permission if you want direct insertion
3. download or prepare local models if using local STT
4. use the menu bar app and hotkeys for recording

The main dictation path is Engine-backed now. A few legacy auxiliary flows still remain and are being cleaned up separately.

## Repository Layout

```text
clients/macos/
├── OpenTypeless/                     # Main app sources
├── OpenTypelessTests/                # App-level tests
├── OpenTypelessUITests/              # UI tests
├── Tests/EngineCoreTests/       # Lightweight Engine support tests
├── OpenTypeless.xcodeproj            # Xcode project
├── Package.swift                # Local package for Engine-core test isolation
├── justfile                     # Developer task runner
└── BUILD.md / CONTRIBUTING.md   # Local build and contribution docs
```

## License And Attribution

The macOS client is based on upstream OpenTypeless and remains MIT licensed.

- See [LICENSE](./LICENSE)
- Keep upstream attribution intact when changing this directory
- Prefer documenting current OpenTypeless behavior over preserving outdated upstream marketing text
