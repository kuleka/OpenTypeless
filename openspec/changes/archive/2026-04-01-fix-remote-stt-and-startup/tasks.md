## 1. Fix remote STT startup flow

- [x] 1.1 In `AppCoordinator.startNormalOperation()`, add sttMode check before model loading — when `.remote`, skip WhisperKit model discovery/loading and initialize `EngineTranscriptionEngine` via `TranscriptionService`
- [x] 1.2 Verify that `TranscriptionService.loadModel()` with `.remote` mode correctly creates `EngineTranscriptionEngine` and sets engine to non-nil state

## 2. Fix EngineProcessManager startup arguments

- [x] 2.1 In `EngineProcessManager.resolveEngineBinary()`, remove `--host` and `configuration.host` from all argument arrays — only pass `serve --port <port>`

## 3. Fix Dock icon visibility

- [x] 3.1 Add `NSApp.setActivationPolicy(.regular)` when settings/main window opens and `.accessory` when all windows close — find the appropriate window lifecycle hook in the app

## 4. Verification

- [x] 4.1 Build the project and verify no compiler errors
- [x] 4.2 Test remote STT mode: app starts without "no model" error, recording transcribes via Engine
