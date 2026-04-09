#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_DIR="$REPO_ROOT/engine"
VENV_DIR="$ENGINE_DIR/.venv"
SPEC_FILE="$ENGINE_DIR/open-typeless.spec"
DIST_DIR="$ENGINE_DIR/dist"
OUTPUT="$DIST_DIR/open-typeless"

echo "==> Building OpenTypeless Engine standalone binary"

# Check venv exists
if [ ! -d "$VENV_DIR" ]; then
    echo "ERROR: Engine venv not found at $VENV_DIR"
    echo "Run: cd $ENGINE_DIR && uv venv && uv pip install -e '.[dev]'"
    exit 1
fi

PYTHON="$VENV_DIR/bin/python"

# Ensure PyInstaller is installed
if ! "$PYTHON" -c "import PyInstaller" 2>/dev/null; then
    echo "==> Installing PyInstaller..."
    uv pip install --python "$PYTHON" pyinstaller
fi

# Clean previous build
rm -rf "$ENGINE_DIR/build" "$DIST_DIR"

# Run PyInstaller
echo "==> Running PyInstaller..."
"$PYTHON" -m PyInstaller \
    "$SPEC_FILE" \
    --distpath "$DIST_DIR" \
    --workpath "$ENGINE_DIR/build" \
    --noconfirm

# Verify output
if [ -x "$OUTPUT" ]; then
    SIZE=$(du -sh "$OUTPUT" | cut -f1)
    echo "==> Build successful: $OUTPUT ($SIZE)"
else
    echo "ERROR: Build failed — $OUTPUT not found or not executable"
    exit 1
fi
