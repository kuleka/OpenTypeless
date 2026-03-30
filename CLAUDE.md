# OpenTypeless — Project Context for Claude Code

> 本文件供 Claude Code session 自动读取，快速了解项目状态和关键决策。
> 最后更新：2026-03-29

## 项目概述

OpenTypeless 是一个**开源语音输入法**，核心功能：用户按快捷键说话 → 语音转文字 → AI 根据场景润色 → 粘贴到光标位置。

架构分两部分：
- **Engine**（Python FastAPI）：本地 HTTP 服务，处理 STT + LLM 管线
- **Client**（macOS Swift，基于 Pindrop）：录音、获取 app 上下文、调用 Engine、粘贴结果

## 仓库结构

```
OpenTypeless/
├── CLAUDE.md              ← 你正在读的文件
├── README.md
├── LICENSE                ← MIT
├── docs/
│   └── api-contract.md   ← Engine ↔ Client 接口契约（核心文档）
├── clients/
│   └── macos/            ← Pindrop 源码（macOS 客户端基座）
├── engine/               ← Python Engine（Phase 1 已完成）
└── openspec/             ← OpenSpec 规格文件
```

## 分支策略

| 分支 | 用途 | 当前状态 |
|------|------|----------|
| `main` | 稳定主线，包含所有已合并的 Phase 1 代码 | Phase 1 已完成 |
| `phase1-core-engine` | Python Engine 开发 | ✅ 已合并到 main (PR #2) |
| `phase1-macos-client` | macOS 客户端改造 | ✅ 已合并到 main (PR #1) |

## 关键设计决策（及原因）

### 1. Engine 是 provider-agnostic 的
- Engine **不绑定任何特定 STT/LLM 服务商**（不写死 Groq、OpenRouter）
- 只要求目标 API 兼容 OpenAI 格式（Whisper API / Chat Completions API）
- 连接信息（api_base, api_key, model）由 Client 通过 `POST /config` 推送
- **原因**：用户在客户端 UI 选择 provider（下拉预设或手动输入），Engine 不关心背后是谁

### 2. API Key 只通过 POST /config 传入
- **不使用环境变量**作为 fallback
- Client 启动时：`GET /health` → `POST /config` → 然后才能调 `/polish`
- 未配置时调 `/polish` 返回 `503 NOT_CONFIGURED`
- **原因**：用户通过客户端 UI 配置一切，不需要接触命令行或环境变量

### 3. /polish 支持双模式输入 + /transcribe 独立端点
- `/polish` 接受 `text`（本地 STT 模式）或 `audio_base64`（远程 STT 模式），二选一
- `task: "polish"`（默认）→ 润色；`task: "translate"` + `output_language` → 翻译
- `/transcribe` 是独立的 STT 端点（multipart/form-data），用于调试或只需转写的场景
- **原因**：Client 可能用本地 WhisperKit 做 STT，只需 Engine 做润色；也可以把 STT 全交给 Engine

### 4. 场景检测（Scene Detection）
- 6 种场景：email, chat, ai_chat, document, code, default
- 通过 app bundle ID 或 window title 匹配
- 不同场景使用不同的润色 prompt 风格
- 匹配规则可通过 `POST /contexts` 动态更新（内存中，重启丢失）

### 5. 音频传输方式：录完再发（非流式）
- Client 录完整段音频后 base64 编码，通过 JSON body 发送
- Phase 1 不做流式传输（WebSocket 是 Phase 3）
- **原因**：语音输入通常 5-30 秒，文件小，batch 模式足够

### 6. STT 和 LLM 分别独立配置
- `POST /config` 中 `stt`（可选）和 `llm`（必填）各有独立的 api_base / api_key / model
- 可以 STT 用 Groq、LLM 用 OpenRouter，也可以全用 OpenAI，也可以 LLM 用本地 Ollama
- 本地 STT 模式下可以不配置 `stt`，只配 `llm` 即可

## 接口端点一览

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |
| POST | `/config` | 推送 API 配置（STT + LLM 连接信息） |
| GET | `/config` | 查看当前配置（key 脱敏） |
| POST | `/transcribe` | 独立 STT：音频 → 转写文本 |
| POST | `/polish` | 核心管线：文本或音频 → 润色/翻译文本 |
| GET | `/contexts` | 查看场景匹配规则 |
| POST | `/contexts` | 更新场景匹配规则 |

详细字段定义见 `docs/api-contract.md`。

## 当前进度

### Phase 1 — ✅ 已完成
- [x] 项目初始化（README、MIT LICENSE）
- [x] Pindrop 源码导入到 `clients/macos/`
- [x] Engine ↔ Client API 接口契约文档（v1.4）
- [x] Engine 开发（FastAPI，6 个端点，68 个测试）— PR #2
- [x] Engine 升级到 API v1.4（/transcribe、双模式 /polish、stt 可选）
- [x] Client 改造（EngineClient、SettingsStore、双模式 STT、Settings UI）— PR #1
- [x] OpenSpec 全部归档（phase1-core-engine、phase1-macos-client、engine-api-v14-upgrade）

### Legacy Client Cleanup — ✅ 已完成

- [x] 退役 quick capture note 工作流（快捷键、录音状态、笔记编辑器启动）
- [x] 从 AppCoordinator 移除 AIEnhancementService 运行时依赖
- [x] 合并设置到 Engine-backed 配置（legacy AI 迁移 + 移除旧 UI）
- [x] 简化 NotesStore（保留 CRUD，移除 AI 元数据生成）
- [x] 更新测试覆盖退役功能

### 待规划
- [ ] **端到端集成测试** — 启动 Engine + Client 跑完整流程
- [ ] **Phase 2 规划** — 参考 `open-typeless-project-plan.md`

## 开发指引

代码现在全在 `main` 分支上。新功能开发时从 main 切新分支。

### Engine 开发
- 代码在 `engine/open_typeless/`，测试在 `engine/tests/`
- 运行测试：`cd engine && .venv/bin/python -m pytest tests/ -v`
- 启动服务：`cd engine && .venv/bin/python -m open_typeless.cli serve`

### Client 开发
- 代码在 `clients/macos/Pindrop/`
- 用 Xcode 打开 `clients/macos/Pindrop.xcodeproj`

## 用户偏好

- 包管理器：**pnpm**（所有 npm 相关操作使用 pnpm）
- Python 包管理器：**uv**（不用 pip，venv 由 uv 创建）
- 语言偏好：中文交流
- Git：gitstatusd 经常抢 index.lock，需要循环 `rm -f .git/index.lock` 再执行 git 命令
