# macOS Client Phase 1 Summary

This document summarizes the completed Phase 1 migration of the OpenTypeless macOS client.

## Scope

The macOS client has been migrated for its main dictation flow from the original Pindrop architecture to an `OpenTypeless Client + Engine` architecture.

Phase 1 goals were:

- Keep existing local transcription support in the macOS app
- Add remote STT support through Engine `POST /transcribe`
- Route text polishing through Engine `POST /polish`
- Keep the existing UI shell, hotkeys, recording, and output flow stable during migration

The source of truth is now:

- [OpenSpec specs](../openspec/specs/)
- [Archived Phase 1 change](../openspec/changes/archive/2026-03-30-phase1-macos-client/)
- [API contract](./api-contract.md)

## Current Architecture

Today the macOS client has three relevant layers:

1. Recording and UI orchestration
2. Transcription selection and execution
3. Engine HTTP integration

The implemented Phase 1 pipeline is:

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
- `4.x AppCoordinator` integration
- `5.x Settings UI` for Engine configuration
- `6.x End-to-end acceptance coverage`

This means the main user-facing Engine flow is wired into the app and covered by tests.

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

### Main Dictation Flow

The default dictation path now works as:

```text
record audio
  -> local STT or Engine /transcribe
  -> client-side replacements and mention rewrite
  -> Engine /polish
  -> output manager
  -> history
```

### Remaining Legacy Areas

Phase 1 did not remove every older client-only path. A subsequent cleanup pass addressed the major items:

- `AIEnhancementService` has been deleted; `LiveSessionContext` was extracted to its own file
- quick capture note workflow has been fully retired
- Notes subsystem has been entirely removed
- the app target and many file paths still use the `Pindrop` name

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

### UI smoke tests

For deterministic settings-window automation:

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

## Notes for Contributors

- The app target is still named `Pindrop`
- Some legacy classes such as `AIEnhancementService` still exist for non-primary flows
- The current behavior baseline lives in `openspec/specs/`
- The Phase 1 implementation history lives in the archived change if you need design context
