# macOS Client Phase 1 Status

This document explains the current state of the OpenTypeless macOS client migration.

## Scope

The macOS client is being migrated from the original Pindrop architecture to an `OpenTypeless Client + Engine` architecture.

Current Phase 1 goals:

- Keep existing local transcription support in the macOS app
- Add remote STT support through Engine `POST /transcribe`
- Route text polishing through Engine `POST /polish`
- Keep the existing UI shell, hotkeys, recording, and output flow stable during migration

The source of truth for the change plan is:

- [OpenSpec change](../openspec/changes/phase1-macos-client/)
- [API contract](./api-contract.md)

## Current Architecture

Today the macOS client has three relevant layers:

1. Recording and UI orchestration
2. Transcription selection and execution
3. Engine HTTP integration

The intended Phase 1 pipeline is:

```text
record audio
  -> TranscriptionService
  -> local engine OR EngineTranscriptionEngine
  -> transcript text
  -> PolishService
  -> Engine /polish
  -> final output
```

### Important components

- `EngineClient`
  Thin HTTP client for `GET /health`, `POST /config`, `POST /transcribe`, and `POST /polish`.
- `EngineTranscriptionEngine`
  Adapter that makes remote STT look like a local `TranscriptionEngine`.
- `TranscriptionService`
  Chooses between local and remote transcription based on `SettingsStore.sttMode`.
- `PolishService`
  Sends transcript text and app context to Engine `/polish`, including translate options and fallback handling.

## What Is Implemented

As of this snapshot:

- `1.x EngineClient` is implemented and tested
- `2.x Dual-Mode Transcription` is implemented and tested
- `3.x PolishService` is implemented and tested

Still pending:

- `4.x AppCoordinator` integration
- `5.x Settings UI` for Engine configuration
- `6.x End-to-end acceptance coverage`

This means the service layer exists, but the full user-facing Engine flow is not fully wired into the app yet.

## Current Behavior

### Local STT

Existing local transcription remains intact:

- WhisperKit local transcription
- Parakeet local transcription
- Existing recording and output path

### Remote STT

Remote STT is now available at the service layer:

- `SettingsStore.sttMode = .remote`
- `TranscriptionService` uses `EngineTranscriptionEngine`
- `EngineTranscriptionEngine` calls Engine `/transcribe`

### Polish

Polishing is now available at the service layer:

- `PolishService.polish(text:appContext:task:outputLanguage:)`
- scene-aware context forwarding via `app_id` and `window_title`
- translate support with `task=translate` and `output_language`
- fallback to raw transcript on `LLM_FAILURE`

## Testing

There are now two useful test layers for the macOS client.

### Fast Engine-core tests

For the isolated Engine support package:

```bash
cd clients/macos
swift test
```

This validates the lightweight `EngineCore` package under:

- `Pindrop/Services/EngineSupport`
- `Tests/EngineCoreTests`

### App-level tests

For the full macOS app target:

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

This is the most reliable command for local verification in the current repo state.

## Notes for Contributors

- The app target is still named `Pindrop`
- Some legacy classes such as `AIEnhancementService` still exist and may still be used by unfinished app flows
- Engine integration is being introduced incrementally to keep regressions contained
- When in doubt, check the OpenSpec tasks before assuming a path is already fully migrated
