# OpenTypeless

[English](../README.md)

> *AI 语音输入法一个月 $20？我都穷疯了哪有钱。用自己 API key 配个便宜模型不就行了。*

开源 AI 语音输入工具。自然说话，光标处获得润色后的文本。

OpenTypeless 捕获你的语音，转写后通过 LLM 去除语气词、修正语法，并根据你当前使用的应用自动调整语气风格 — 全程在本地运行。

## 特性

- **场景感知润色** — 自动检测邮件应用和通用场景，调整输出风格
- **本地优先 STT** — 通过 WhisperKit（Apple Neural Engine）在设备上转写，音频不离开你的电脑
- **不绑定服务商** — 自带 LLM（OpenAI、Anthropic、Groq、Ollama，或任何 OpenAI 兼容 API）
- **快捷键驱动** — 按住说话，松开粘贴。无窗口、无点击
- **内置 Engine** — 自包含的 Python 后端打包在应用内，零配置即可使用

## 工作原理

```
按住快捷键 -> 说话 -> 松开
                        |
            本地 STT (WhisperKit) 或 远程 STT
                        |
            Engine /polish (LLM 场景感知润色)
                        |
            润色后的文本粘贴到光标位置
```

## 安装 (macOS)

目前仅支持从源码构建。预编译版本计划中。

```bash
# 克隆仓库
git clone https://github.com/YisuWang/OpenTypeless.git
cd OpenTypeless

# 设置 Engine（二选一）

# 方式 A：构建独立二进制（推荐，自动打包进 app）
scripts/build-engine.sh

# 方式 B：开发模式，使用 venv（没有 binary 时 app 会自动 fallback 到这个）
cd engine && uv venv && uv pip install -e . && cd ..

# 构建并运行 macOS 客户端
open clients/macos/OpenTypeless.xcodeproj
# 在 Xcode 中按 Cmd+R 构建运行
```

首次启动时，按照引导向导授权权限并配置你的 LLM 服务商。

## 环境要求

| 组件 | 最低版本 | 推荐版本 |
| ---- | -------- | -------- |
| macOS | 14.0 (Sonoma) | 15.0+ |
| Xcode | 16.0 | 16.0+ |
| Python | 3.11 | 3.13+ |
| LLM API | 任何 OpenAI 兼容端点 | — |

## 架构

```
┌─────────────────────────┐                    ┌─────────────────────────┐
│  macOS 客户端 (Swift)    │   HTTP localhost   │   Engine (Python)       │
│                         │ ◄────────────────► │                         │
│  - 音频录制              │    port 19823      │  - FastAPI 服务          │
│  - WhisperKit 本地 STT  │                    │  - 远程 STT 代理         │
│  - 快捷键管理            │                    │  - LLM 润色管线          │
│  - 应用上下文采集        │                    │  - 场景检测              │
│  - 剪贴板输出            │                    │  - Stub 模式 (测试用)    │
└─────────────────────────┘                    └─────────────────────────┘
```

### Engine (Python)

本地 HTTP 服务，负责 STT 和 LLM 调用。不绑定服务商 — 任何 OpenAI 兼容 API 都可以。

| 端点 | 方法 | 说明 |
| ---- | ---- | ---- |
| `/health` | GET | 健康检查 |
| `/config` | POST | 推送 API 密钥和模型配置 |
| `/config` | GET | 查看当前配置（密钥脱敏） |
| `/transcribe` | POST | 远程 STT（音频 -> 文本） |
| `/polish` | POST | 核心管线（文本 -> 润色文本） |
| `/contexts` | GET/POST | 场景检测规则 |

完整 API 规格：[docs/api-contract.md](api-contract.md)

### macOS 客户端 (Swift)

原生菜单栏应用。管理录音、快捷键、上下文检测和输出。通过 localhost HTTP 与 Engine 通信。

**场景检测：**

| 场景 | 应用 | 风格 |
| ---- | ---- | ---- |
| 邮件 | Mail、Outlook、Gmail、ProtonMail | 正式、结构化的邮件格式 |
| 默认 | 其他所有应用 | 通用清理，保留原意和语气 |

## 依赖

### Engine Python 包

| 包 | 版本 | 用途 |
| -- | ---- | ---- |
| [FastAPI](https://fastapi.tiangolo.com/) | >= 0.110 | HTTP 框架 |
| [Uvicorn](https://www.uvicorn.org/) | >= 0.29 | ASGI 服务器 |
| [httpx](https://www.python-httpx.org/) | >= 0.27 | LLM/STT 服务商 HTTP 客户端 |
| [Pydantic](https://docs.pydantic.dev/) | >= 2.7 | 数据校验 |
| [PyYAML](https://pyyaml.org/) | >= 6.0 | 配置文件解析 |
| [python-multipart](https://github.com/Kludex/python-multipart) | >= 0.0.9 | 文件上传（音频） |

开发依赖：pytest >= 8.0、pytest-asyncio >= 0.23、PyInstaller >= 6.0

### macOS 客户端 Swift 包

| 包 | 版本 | 用途 |
| -- | ---- | ---- |
| [WhisperKit](https://github.com/argmaxinc/WhisperKit) | >= 0.9.0 | 设备端语音转文字（CoreML/ANE） |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | 0.13.4 | 音频录制与处理 |
| [Sparkle](https://sparkle-project.org/) | >= 2.6.0 | 自动更新框架 |

## 开发

### 前置条件

- macOS 14.0+、Xcode 16.0+
- Python 3.11+，安装 [uv](https://docs.astral.sh/uv/)（包管理器）

### Engine

```bash
cd engine

# 创建 venv 并安装依赖
uv venv && uv pip install -e ".[dev]"

# 启动服务（stub 模式用于测试）
uv run open-typeless serve --stub

# 运行测试
uv run pytest tests/ -v
```

### macOS 客户端

```bash
# 用 Xcode 打开
open clients/macos/OpenTypeless.xcodeproj

# 构建运行 (Cmd+R)
# 如果有打包好的 binary 或 venv，Engine 会自动启动
```

### 构建 Engine 独立二进制

```bash
# 构建独立二进制（~17MB，arm64）
scripts/build-engine.sh

# 输出：engine/dist/open-typeless
# Xcode 构建时会自动复制到 app bundle 中
```

### 运行测试

```bash
# Engine 单元测试
cd engine && uv run pytest tests/ -v

# macOS 客户端测试（在 clients/macos/ 目录下）
xcodebuild test -project OpenTypeless.xcodeproj -scheme OpenTypeless -destination 'platform=macOS'
```

## 项目结构

```
OpenTypeless/
├── engine/                  # Python Engine
│   ├── open_typeless/       #   源代码
│   │   ├── cli.py           #   CLI 入口
│   │   ├── server.py        #   FastAPI 应用
│   │   ├── pipeline.py      #   润色管线
│   │   └── scene.py         #   场景检测
│   ├── tests/               #   68 个单元测试
│   └── dist/                #   构建产物（gitignored）
├── clients/
│   └── macos/               # macOS 客户端 (Swift)
│       ├── OpenTypeless/    #   源代码
│       └── OpenTypelessTests/  # 单元测试 + E2E 测试
├── docs/
│   └── api-contract.md      # Engine <-> Client API 规格
├── scripts/
│   └── build-engine.sh      # PyInstaller 构建脚本
└── openspec/                # 设计规格与变更追踪
```

## 路线图

- [x] Phase 1 — Engine + Client 集成
- [x] 遗留代码清理（退役 quick-capture 和 AI-only 流程）
- [x] Engine 生命周期管理（自动发现、健康轮询、崩溃恢复）
- [x] 内置 Engine 二进制（PyInstaller，打包在 .app 内）
- [x] i18n（英文 + 简体中文）
- [ ] DMG / Homebrew 分发
- [ ] 自定义场景规则和 prompt 模板
- [ ] Windows / Linux 客户端

## 贡献

欢迎贡献！

- Engine 测试：`cd engine && uv run pytest tests/ -v`
- Client 测试：打开 Xcode，Cmd+U
- 参见 [clients/macos/CONTRIBUTING.md](../clients/macos/CONTRIBUTING.md) 了解客户端开发指南

## 致谢

macOS 客户端基于 [@watzon](https://github.com/watzon) 的 [Pindrop](https://github.com/watzon/pindrop)，MIT 许可。

## 许可证

[MIT](../LICENSE)
