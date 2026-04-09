## ADDED Requirements

### Requirement: E2E tests SHALL support bundled binary as Engine source

E2E tests SHALL be able to launch the Engine using the standalone binary at `engine/dist/open-typeless` in addition to the venv Python path. The test infrastructure SHALL auto-detect which Engine sources are available and run applicable tests for each.

#### Scenario: Bundled binary available

- **WHEN** `engine/dist/open-typeless` exists and is executable
- **THEN** E2E tests SHALL launch Engine using the bundled binary with `serve --port <port> --stub`

#### Scenario: Bundled binary not available

- **WHEN** `engine/dist/open-typeless` does not exist
- **THEN** E2E tests using the bundled binary path SHALL be skipped with a diagnostic message

#### Scenario: Bundled binary health check succeeds

- **WHEN** Engine is launched via bundled binary with `--stub`
- **THEN** GET /health SHALL return 200 with status "ok" within 15 seconds (bundled binary has longer cold start due to PyInstaller extraction)

### Requirement: E2E tests SHALL verify Engine crash recovery

E2E tests SHALL verify that EngineProcessManager detects Engine process termination and successfully restarts the Engine, restoring it to a healthy state.

#### Scenario: Engine process killed and auto-restarted

- **WHEN** an Engine process managed by EngineProcessManager is killed (SIGKILL)
- **THEN** EngineProcessManager SHALL detect the termination and spawn a new Engine process
- **AND** the new Engine process SHALL become healthy (GET /health returns 200) within 15 seconds

#### Scenario: Restarted Engine accepts requests

- **WHEN** Engine has been auto-restarted after a crash
- **THEN** POST /config and POST /polish SHALL succeed against the restarted Engine

### Requirement: E2E tests SHALL verify full managed lifecycle

E2E tests SHALL exercise EngineProcessManager driving the complete Engine lifecycle: binary discovery → process spawn → health polling → config push → polish request → graceful shutdown.

#### Scenario: Managed lifecycle happy path

- **WHEN** EngineProcessManager is started with a real Engine binary (venv or bundled)
- **THEN** the manager SHALL discover the binary, spawn the process, detect healthy status via polling, push configuration, and the Engine SHALL successfully handle a POST /polish request

#### Scenario: Managed lifecycle graceful shutdown

- **WHEN** EngineProcessManager.stop() is called
- **THEN** the Engine process SHALL be terminated and no orphan process SHALL remain

## MODIFIED Requirements

### Requirement: E2E test process management

Swift E2E tests SHALL start a real Engine process using the repo venv Python or bundled binary, wait for it to become healthy, and terminate it after tests complete.

#### Scenario: Engine starts and becomes reachable (venv)

- **WHEN** the test suite launches Engine via `engine/.venv/bin/python -m open_typeless.cli serve --port 29823 --stub`
- **THEN** GET /health returns 200 within 10 seconds

#### Scenario: Engine starts and becomes reachable (bundled binary)

- **WHEN** the test suite launches Engine via `engine/dist/open-typeless serve --port 29824 --stub`
- **THEN** GET /health returns 200 within 15 seconds

#### Scenario: Engine is terminated after tests

- **WHEN** all E2E tests have completed
- **THEN** the Engine process is terminated and no orphan process remains

#### Scenario: Missing venv skips venv tests

- **WHEN** `engine/.venv/bin/python` does not exist
- **THEN** venv-based E2E tests are skipped with a diagnostic message

#### Scenario: Missing bundled binary skips bundled tests

- **WHEN** `engine/dist/open-typeless` does not exist
- **THEN** bundled binary E2E tests are skipped with a diagnostic message
