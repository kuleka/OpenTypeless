## ADDED Requirements

### Requirement: Engine SHALL be packaged as a standalone macOS binary

The build system SHALL produce a standalone macOS executable from the Python Engine source using PyInstaller. The binary SHALL include the Python runtime and all dependencies, requiring no external Python installation.

#### Scenario: Build produces executable

- **WHEN** the developer runs `scripts/build-engine.sh`
- **THEN** a standalone executable is produced at `engine/dist/open-typeless`

#### Scenario: Binary runs without system Python

- **WHEN** the produced binary is executed on a macOS system without Python installed
- **THEN** `open-typeless serve --port 19823` SHALL start the Engine HTTP server successfully

#### Scenario: Health check on bundled Engine

- **WHEN** the bundled binary is running
- **THEN** `GET /health` SHALL return status 200 with `status: "ok"`

### Requirement: Engine binary SHALL be embedded in the app bundle

The Xcode project SHALL include a Copy Files Build Phase that places the Engine binary at `Contents/Resources/engine/open-typeless` in the app bundle.

#### Scenario: App bundle contains Engine

- **WHEN** the app is built with the Engine binary present at `engine/dist/open-typeless`
- **THEN** the built .app bundle SHALL contain the binary at `Contents/Resources/engine/open-typeless`

#### Scenario: App builds without Engine binary

- **WHEN** the developer builds the app without first running `scripts/build-engine.sh`
- **THEN** the Xcode build SHALL succeed (Copy Phase skips gracefully), and EngineProcessManager falls through to lower-priority discovery methods

### Requirement: Build script SHALL manage the PyInstaller workflow

The build script `scripts/build-engine.sh` SHALL handle the full PyInstaller build lifecycle: verify Python environment, install PyInstaller if missing, run PyInstaller with the spec file, and report success or failure.

#### Scenario: First-time build

- **WHEN** the developer runs `scripts/build-engine.sh` for the first time
- **THEN** PyInstaller is installed into the Engine venv and the binary is produced

#### Scenario: Rebuild after Engine changes

- **WHEN** the developer modifies Engine source and re-runs `scripts/build-engine.sh`
- **THEN** a fresh binary is produced reflecting the changes
