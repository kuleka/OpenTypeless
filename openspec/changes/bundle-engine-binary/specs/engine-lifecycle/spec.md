## MODIFIED Requirements

### Requirement: App SHALL discover Engine binary via priority chain

The App SHALL locate the Engine executable using the following priority: (0) bundled binary in app bundle Resources, (1) user-configured custom path, (2) `$PATH` lookup, (3) repository venv fallback path. If no executable is found, the App SHALL surface an error to the user. The App SHALL pass only CLI-supported arguments (`serve`, `--port`, `--stub`) when spawning the Engine.

#### Scenario: Bundled binary in app bundle

- **WHEN** the app bundle contains an executable at `Contents/Resources/engine/open-typeless`
- **THEN** the App SHALL use that binary with `serve --port <port>` as the highest priority

#### Scenario: Bundled binary missing, custom path configured

- **WHEN** no bundled binary exists and the user has set a custom Engine path in settings
- **THEN** the App SHALL use that path to spawn the Engine with `serve --port <port>`

#### Scenario: Fallback to PATH

- **WHEN** no bundled binary, no custom path, and `open_typeless` is on `$PATH`
- **THEN** the App SHALL use the PATH-resolved binary with `serve --port <port>`

#### Scenario: Fallback to venv

- **WHEN** no bundled binary, no custom path, not on `$PATH`, but repo venv exists
- **THEN** the App SHALL use the venv Python to run the Engine module with `-m open_typeless.cli serve --port <port>`

#### Scenario: No Engine found

- **WHEN** no Engine binary can be resolved through any strategy
- **THEN** the App SHALL display an error with instructions to install the Engine
