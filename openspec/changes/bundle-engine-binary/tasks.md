## 1. PyInstaller Setup

- [x] 1.1 Add `pyinstaller` to `engine/pyproject.toml` dev dependency group
- [x] 1.2 Create `engine/open-typeless.spec` PyInstaller spec file targeting `open_typeless.cli:main`, onefile mode, arm64, with hidden imports for uvicorn, fastapi, httpx, pydantic, python-multipart

## 2. Build Script

- [x] 2.1 Create `scripts/build-engine.sh`: check Python venv, install PyInstaller if needed, run `pyinstaller engine/open-typeless.spec --distpath engine/dist --workpath engine/build --noconfirm`, verify output exists
- [x] 2.2 Add `engine/dist/` and `engine/build/` to `.gitignore`

## 3. Verify Standalone Binary

- [x] 3.1 Run `scripts/build-engine.sh` and verify `engine/dist/open-typeless` is produced
- [x] 3.2 Test: `engine/dist/open-typeless serve --port 19999` starts server, `GET /health` returns 200

## 4. EngineProcessManager Priority 0

- [x] 4.1 In `EngineProcessManager.resolveEngineBinary()`, add Priority 0 before Priority 1: check `Bundle.main.resourceURL?.appendingPathComponent("engine/open-typeless")`, use if executable exists
- [x] 4.2 Add log line for bundled binary discovery

## 5. Xcode Build Phase

- [x] 5.1 Add a Run Script Build Phase to the OpenTypeless target that conditionally copies `engine/dist/open-typeless` to `$BUILT_PRODUCTS_DIR/OpenTypeless.app/Contents/Resources/engine/open-typeless` (skip if source doesn't exist)
- [x] 5.2 Build app and verify: with bundled binary → app uses it (check logs); without → falls through to venv (existing behavior)

## 6. Documentation

- [x] 6.1 Update CLAUDE.md with build instructions (run `scripts/build-engine.sh` before Xcode build for distribution)
- [x] 6.2 Update CLAUDE.md — mark Distribution as in-progress
