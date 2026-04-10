# OpenTypeless

[中文文档](docs/README_zh-CN.md)

> *$20/month for an AI voice input app? I'm not rich like that. Just bring your own API key and a cheap model.*

Open-source AI voice input for your desktop. Speak naturally, get polished text at your cursor.

OpenTypeless captures your voice, transcribes it, and uses LLM to clean up filler words, fix grammar, and adapt tone based on the app you're typing in — all running locally on your machine.

## Features

- **Scene-aware polishing** — detects email apps vs general context, adjusts output style automatically
- **Local-first STT** — on-device transcription via WhisperKit (Apple Neural Engine), no audio leaves your machine
- **Provider-agnostic** — bring your own LLM (OpenAI, Anthropic, Groq, Ollama, or any OpenAI-compatible API)
- **Hotkey-driven** — hold to speak, release to paste. No windows, no clicks
- **Bundled Engine** — self-contained Python backend ships inside the app, zero setup required

## How It Works

```
Hold hotkey -> Speak -> Release
                          |
              Local STT (WhisperKit) or Remote STT
                          |
              Engine /polish (LLM scene-aware cleanup)
                          |
              Paste polished text at cursor
```

## Install (macOS)

Currently install from source only. Pre-built releases are planned.

```bash
# Clone
git clone https://github.com/YisuWang/OpenTypeless.git
cd OpenTypeless

# Set up Engine (pick one)

# Option A: Build standalone binary (recommended, bundles into app automatically)
scripts/build-engine.sh

# Option B: Dev mode with venv (app falls back to this if no binary)
cd engine && uv venv && uv pip install -e . && cd ..

# Build and run macOS client
open clients/macos/OpenTypeless.xcodeproj
# In Xcode: Cmd+R to build and run
```

On first launch, follow the onboarding wizard to grant permissions and configure your LLM provider.

## Requirements

| Component | Minimum | Recommended |
| --------- | ------- | ----------- |
| macOS | 14.0 (Sonoma) | 15.0+ |
| Xcode | 16.0 | 16.0+ |
| Python | 3.11 | 3.13+ |
| LLM API | Any OpenAI-compatible endpoint | — |

## Architecture

```
┌─────────────────────────┐                    ┌─────────────────────────┐
│   macOS Client (Swift)  │   HTTP localhost   │   Engine (Python)       │
│                         │ ◄────────────────► │                         │
│  - Audio recording      │    port 19823      │  - FastAPI server       │
│  - WhisperKit local STT │                    │  - Remote STT proxy     │
│  - Hotkey management    │                    │  - LLM polish pipeline  │
│  - App context capture  │                    │  - Scene detection      │
│  - Clipboard output     │                    │  - Stub mode (testing)  │
└─────────────────────────┘                    └─────────────────────────┘
```

### Engine (Python)

Local HTTP service handling STT and LLM. Provider-agnostic — any OpenAI-compatible API works.

| Endpoint | Method | Description |
| -------- | ------ | ----------- |
| `/health` | GET | Health check |
| `/config` | POST | Push API keys and model config |
| `/config` | GET | View current config (keys masked) |
| `/transcribe` | POST | Remote STT (audio -> text) |
| `/polish` | POST | Core pipeline (text -> polished text) |
| `/contexts` | GET/POST | Scene detection rules |

Full API spec: [docs/api-contract.md](docs/api-contract.md)

### macOS Client (Swift)

Native menu bar app. Manages recording, hotkeys, context detection, and output. Communicates with Engine over localhost HTTP.

**Scene Detection:**

| Scene | Apps | Style |
| ----- | ---- | ----- |
| Email | Mail, Outlook, Gmail, ProtonMail | Formal, structured email formatting |
| Default | Everything else | General cleanup, preserves meaning and tone |

## Dependencies

### Engine Python Packages

| Package | Version | Purpose |
| ------- | ------- | ------- |
| [FastAPI](https://fastapi.tiangolo.com/) | >= 0.110 | HTTP framework |
| [Uvicorn](https://www.uvicorn.org/) | >= 0.29 | ASGI server |
| [httpx](https://www.python-httpx.org/) | >= 0.27 | HTTP client for LLM/STT providers |
| [Pydantic](https://docs.pydantic.dev/) | >= 2.7 | Data validation |
| [PyYAML](https://pyyaml.org/) | >= 6.0 | Config file parsing |
| [python-multipart](https://github.com/Kludex/python-multipart) | >= 0.0.9 | File upload (audio) |

Dev: pytest >= 8.0, pytest-asyncio >= 0.23, PyInstaller >= 6.0

### macOS Client Swift Packages

| Package | Version | Purpose |
| ------- | ------- | ------- |
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | >= 0.9.0 | On-device speech-to-text (CoreML/ANE) |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | 0.13.4 | Audio recording and processing |
| [Sparkle](https://sparkle-project.org/) | >= 2.6.0 | Auto-update framework |

## Development

### Prerequisites

- macOS 14.0+, Xcode 16.0+
- Python 3.11+ with [uv](https://docs.astral.sh/uv/) (package manager)

### Engine

```bash
cd engine

# Create venv and install dependencies
uv venv && uv pip install -e ".[dev]"

# Run server (stub mode for testing)
uv run open-typeless serve --stub

# Run tests
uv run pytest tests/ -v
```

### macOS Client

```bash
# Open in Xcode
open clients/macos/OpenTypeless.xcodeproj

# Build and run (Cmd+R)
# Engine will auto-start if bundled binary or venv is available
```

### Build Bundled Engine Binary

```bash
# Build standalone binary (~17MB, arm64)
scripts/build-engine.sh

# Output: engine/dist/open-typeless
# Xcode build phase auto-copies it into the app bundle
```

### Run Tests

```bash
# Engine unit tests
cd engine && uv run pytest tests/ -v

# macOS client tests (from clients/macos/)
xcodebuild test -project OpenTypeless.xcodeproj -scheme OpenTypeless -destination 'platform=macOS'
```

## Project Structure

```
OpenTypeless/
├── engine/                  # Python Engine
│   ├── open_typeless/       #   Source code
│   │   ├── cli.py           #   CLI entry point
│   │   ├── server.py        #   FastAPI app
│   │   ├── pipeline.py      #   Polish pipeline
│   │   └── scene.py         #   Scene detection
│   ├── tests/               #   68 unit tests
│   └── dist/                #   Built binary (gitignored)
├── clients/
│   └── macos/               # macOS Client (Swift)
│       ├── OpenTypeless/    #   Source code
│       └── OpenTypelessTests/  # Unit + E2E tests
├── docs/
│   └── api-contract.md      # Engine <-> Client API spec
├── scripts/
│   └── build-engine.sh      # PyInstaller build script
└── openspec/                # Design specs and change tracking
```

## Roadmap

- [x] Phase 1 — Engine + Client integration
- [x] Legacy cleanup (retired quick-capture and AI-only flows)
- [x] Engine lifecycle management (auto-discovery, health polling, crash recovery)
- [x] Bundled Engine binary (PyInstaller, ships inside .app)
- [x] i18n (English + Simplified Chinese)
- [ ] DMG / Homebrew distribution
- [ ] Custom context rules and prompt templates
- [ ] Windows / Linux clients

## Contributing

Contributions welcome!

- Engine tests: `cd engine && uv run pytest tests/ -v`
- Client tests: open Xcode, Cmd+U
- See [clients/macos/CONTRIBUTING.md](clients/macos/CONTRIBUTING.md) for client-specific guidelines

## Credits

macOS client is based on [Pindrop](https://github.com/watzon/pindrop) by [@watzon](https://github.com/watzon), MIT licensed.

## Star History

<a href="https://www.star-history.com/?repos=kuleka%2FOpenTypeless&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=kuleka/OpenTypeless&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=kuleka/OpenTypeless&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=kuleka/OpenTypeless&type=date&legend=top-left" />
 </picture>
</a>

## License

[MIT](LICENSE)
