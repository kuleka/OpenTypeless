## 1. Test Infrastructure Refactor

- [x] 1.1 Extract shared helpers in `EngineE2ETests.swift`: add `bundledBinaryPath()` alongside existing `venvPythonPath()`, add `launchEngineFromBinary(path:port:)` that accepts any executable path
- [x] 1.2 Add port constants for new tests: `bundledBinaryPort = 29824`, `crashRecoveryPort = 29825`, `lifecyclePort = 29826`

## 2. Bundled Binary E2E Tests

- [x] 2.1 Add `bundledBinaryHealthCheck()` test: skip if `engine/dist/open-typeless` missing, launch bundled binary on port 29824 with `--stub`, wait up to 15s for healthy, verify GET /health returns 200
- [x] 2.2 Add `bundledBinaryPolishPipeline()` test: launch bundled binary, push config, POST /polish with text + app context, verify stub response with scene detection

## 3. Crash Recovery E2E Test

- [x] 3.1 Add `engineCrashRecovery()` test: create real EngineProcessManager with `customBinaryPath` pointing to available Engine binary, `start()`, wait for healthy, `kill(pid, SIGKILL)` the Engine process, verify manager detects crash and respawns, new process becomes healthy within 15s
- [x] 3.2 Verify restarted Engine accepts POST /polish after recovery

## 4. Full Managed Lifecycle E2E Test

- [x] 4.1 Add `managedLifecycleHappyPath()` test: create EngineProcessManager with real binary, inject configProvider returning valid stub config, call `start()`, wait for ready state, send POST /polish via EngineClient, verify response, call `stop()`, verify process terminated
- [x] 4.2 Verify no orphan Engine process remains after `stop()` (check `kill(pid, 0)` returns error)

## 5. Verification

- [x] 5.1 Run full E2E test suite, verify all new tests pass (with both venv and bundled binary available)
- [x] 5.2 Verify tests skip gracefully when bundled binary is absent (delete `engine/dist/open-typeless` temporarily, run tests, confirm skip messages)
