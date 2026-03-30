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
- [macOS client Phase 1 summary](../../docs/macos-client-phase1.md)
- [Contribution guide](./CONTRIBUTING.md)

## Current Status

As of the completed Phase 1 migration:

- local transcription remains available
- remote STT is wired into the main dictation flow
- Engine-based polish is wired into the main dictation flow
- `AppCoordinator` startup sync and output pipeline are connected
- Engine settings UI and config persistence are implemented
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

- `Pindrop/Services/EngineSupport/EngineClient.swift`
- `Pindrop/Services/Transcription/EngineTranscriptionEngine.swift`
- `Pindrop/Services/TranscriptionService.swift`
- `Pindrop/Services/PolishService.swift`

Important migration note:

- `AIEnhancementService` still exists because a few auxiliary legacy app flows have not been migrated yet.
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

UI smoke tests:

```bash
cd clients/macos
xcodebuild test \
  -project Pindrop.xcodeproj \
  -scheme Pindrop \
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

Maintainer-oriented release helpers still exist because the client inherited Pindrop's packaging flow:

```bash
just export-app
just dmg
just release-notes 1.9.0
just release 1.9.0
```

Treat these as OpenTypeless maintainer workflows for inherited packaging infrastructure, not as evidence that upstream Pindrop releases are current OpenTypeless releases.

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
