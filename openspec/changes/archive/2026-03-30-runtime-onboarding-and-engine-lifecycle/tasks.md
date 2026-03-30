## 1. Engine Process Manager

- [x] 1.1 Create `EngineProcessManager` service with `EngineProcessManaging` protocol (reuse existing `EngineRuntimeState` for status)
- [x] 1.2 Implement binary discovery (custom path > PATH > repo venv)
- [x] 1.3 Implement Engine spawn via `Process` with stdout/stderr capture
- [x] 1.4 Implement health polling loop (GET /health via EngineClient, 3 consecutive failures → restart)
- [x] 1.5 Implement auto-restart with rate limiting (max 5 restarts per 60s)
- [x] 1.6 Implement graceful shutdown (SIGTERM → 5s timeout → SIGKILL)
- [x] 1.7 Implement config push (POST /config) after first successful health check
- [x] 1.8 Add `engineBinaryPath` setting to SettingsStore
- [x] 1.9 Add EngineProcessManager unit tests

## 2. Onboarding Redesign

- [x] 2.1 Redesign `OnboardingStep` enum: welcome → permissions → sttMode → llmConfig → [sttConfig] → hotkey → complete
- [x] 2.2 Update `OnboardingWindow` step flow, remove legacy model selection/download/aiEnhancement steps
- [x] 2.3 Update `PermissionsStepView`: make Accessibility REQUIRED (not optional)
- [x] 2.4 Create `STTModeStepView` (local WhisperKit vs remote Engine STT)
- [x] 2.5 Create `LLMConfigStepView` (Engine LLM provider presets, endpoint/key/model)
- [x] 2.6 Create `STTConfigStepView` (Engine STT provider presets, shown only for remote STT)
- [x] 2.7 Update `CompleteStepView` (verify Engine health + config, show ready confirmation)
- [x] 2.8 Update `WelcomeStepView` messaging for OpenTypeless
- [x] 2.9 Delete legacy `ModelSelectionStepView`, `ModelDownloadStepView` (kept `AIEnhancementStepView` — its enums are used across SettingsStore, StatusBarController, AIModelService)

## 3. Engine Status Indicator

- [x] 3.1 Add Engine status line to StatusBarController menu dropdown
- [x] 3.2 Engine status text in menu reflects connection state (icon change deferred — existing icon set doesn't have Engine-specific variants)
- [x] 3.3 Add "Configure..." action when Engine is unconfigured (opens Settings → Engine & AI tab)

## 4. Integration

- [x] 4.1 Wire EngineProcessManager into AppCoordinator (DI, start on launch, stop on quit)
- [x] 4.2 Update onboarding completion flow: Engine config push → transition to normal operation
- [x] 4.3 Add "Re-run Setup" button in Settings window
- [x] 4.4 Add EngineProcessManager unit tests (6 tests, all passing)
- [x] 4.5 Update CLAUDE.md progress section
