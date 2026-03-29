# OpenTypeless macOS Client

> Native macOS client for OpenTypeless, based on the upstream Pindrop app.

This directory contains the Swift macOS client used by OpenTypeless. The codebase started from [Pindrop](https://github.com/watzon/pindrop) and is being adapted into a thin client for the local OpenTypeless Engine.

This README describes the current OpenTypeless client state. It is not a mirror of upstream Pindrop product docs.

## Origin And Scope

- Upstream foundation: Pindrop
- Current product direction: OpenTypeless
- Current goal: keep the native macOS shell while moving STT and polish responsibilities behind the local Engine HTTP boundary

Useful references:

- [OpenTypeless root README](../../README.md)
- [Engine ↔ Client API contract](../../docs/api-contract.md)
- [macOS client Phase 1 status](../../docs/macos-client-phase1.md)
- [Contribution guide](./CONTRIBUTING.md)

## Current Status

As of the current Phase 1 migration:

- local transcription remains available
- remote STT exists at the service layer
- Engine-based polish exists at the service layer
- full `AppCoordinator` wiring and Engine settings UI are still in progress

That means the core Engine integration pieces exist, but not every end-user flow has been migrated yet.

## Current Architecture

The current Phase 1 target pipeline is:

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

- `Pindrop/Services/EngineSupport/EngineClient.swift`
- `Pindrop/Services/Transcription/EngineTranscriptionEngine.swift`
- `Pindrop/Services/TranscriptionService.swift`
- `Pindrop/Services/PolishService.swift`

Important migration note:

- `AIEnhancementService` still exists because some higher-level app flows have not been migrated yet.
- Xcode targets and many path names still use `Pindrop` for continuity.

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
open Pindrop.xcodeproj
```

You can also build from the command line:

```bash
xcodebuild -project Pindrop.xcodeproj -scheme Pindrop -destination 'platform=macOS' build
```

The app target is still named `Pindrop`.

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
  -project Pindrop.xcodeproj \
  -scheme Pindrop \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/OpenTypelessDerivedData \
  -clonedSourcePackagesDirPath /tmp/OpenTypelessSourcePackages \
  -only-testing:PindropTests \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM=''
```

This is the most reliable full-app test command for the current local setup.

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

Maintainer-oriented release helpers still exist because the client inherited Pindrop's packaging flow:

```bash
just export-app
just dmg
just release-notes 1.9.0
just release 1.9.0
```

Treat these as maintainer workflows, not as evidence that upstream Pindrop releases are OpenTypeless releases.

## First Launch Notes

On a fresh local build, expect to:

1. grant microphone permission
2. grant accessibility permission if you want direct insertion
3. download or prepare local models if using local STT
4. use the menu bar app and hotkeys for recording

Some Engine-backed flows are still in progress, so local-first behavior is still present in parts of the app.

## Repository Layout

```text
clients/macos/
├── Pindrop/                     # Main app sources
├── PindropTests/                # App-level tests
├── PindropUITests/              # UI tests
├── Tests/EngineCoreTests/       # Lightweight Engine support tests
├── Pindrop.xcodeproj            # Xcode project
├── Package.swift                # Local package for Engine-core test isolation
├── justfile                     # Developer task runner
└── BUILD.md / CONTRIBUTING.md   # Local build and contribution docs
```

## License And Attribution

The macOS client is based on upstream Pindrop and remains MIT licensed.

- See [LICENSE](./LICENSE)
- Keep upstream attribution intact when changing this directory
- Prefer documenting current OpenTypeless behavior over preserving outdated upstream marketing text
