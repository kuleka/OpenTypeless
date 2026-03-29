# OpenTypeless — Project Context for Claude Code

> 本文件供 Claude Code session 自动读取，快速了解项目状态和关键决策。
> 最后更新：2026-03-28

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
├── engine/               ← （待开发）Python Engine
└── openspec/             ← OpenSpec 规格文件（在 phase1-core-engine 分支上）
```

## 分支策略

| 分支 | 用途 | 当前状态 |
|------|------|----------|
| `main` | 共享基础（文档、LICENSE、Pindrop 代码） | 稳定 |
| `phase1-core-engine` | Python Engine 开发 | 未开始写代码，spec 已就绪 |
| `phase1-macos-client` | macOS 客户端改造 | 未开始，待创建 spec |

两个开发分支基于 main 的最新状态 rebase，共享 `docs/api-contract.md`。

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

### 3. /polish 是唯一核心端点，通过 task 参数扩展功能
- `task: "polish"`（默认）→ 润色
- `task: "translate"` + `output_language: "en"` → 翻译
- **不拆分为多个端点**（`/transcribe`、`/refine` 等）
- **原因**：所有功能共享同一管线（音频 → STT → prompt → LLM），只是 prompt 不同。逻辑应在 Engine 内，Client 只是壳，不做编排

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
- `POST /config` 中 `stt` 和 `llm` 各有独立的 api_base / api_key / model
- 可以 STT 用 Groq、LLM 用 OpenRouter，也可以全用 OpenAI，也可以 LLM 用本地 Ollama

## 接口端点一览

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |
| POST | `/config` | 推送 API 配置（STT + LLM 连接信息） |
| GET | `/config` | 查看当前配置（key 脱敏） |
| POST | `/polish` | 核心管线：音频 → 润色/翻译文本 |
| GET | `/contexts` | 查看场景匹配规则 |
| POST | `/contexts` | 更新场景匹配规则 |

详细字段定义见 `docs/api-contract.md`。

## 当前进度

### 已完成
- [x] 项目初始化（README、MIT LICENSE）
- [x] Pindrop 源码导入到 `clients/macos/`
- [x] Engine ↔ Client API 接口契约文档（v1.3）
- [x] Engine 的 OpenSpec 规格文件（proposal、design、tasks、5 个 spec）
- [x] 所有 spec 已更新为 provider-agnostic 设计
- [x] 分支创建和同步

### 未完成
- [ ] **Engine 开发**（phase1-core-engine 分支）— spec 和 tasks 已就绪，代码未开始
- [ ] **Client spec 创建**（phase1-macos-client 分支）— 还没有改造计划文档
- [ ] **Client 开发**（phase1-macos-client 分支）— 代码未开始

## 开发指引

### Engine Session
1. 切到 `phase1-core-engine` 分支
2. 读 `openspec/changes/phase1-core-engine/tasks.md` 获取任务列表
3. 读 `docs/api-contract.md` 了解接口契约
4. 按 tasks.md 中的顺序开发

### Client Session
1. 切到 `phase1-macos-client` 分支
2. 读 `docs/api-contract.md` 了解要对接的接口
3. 读 `clients/macos/` 下的 Pindrop 源码，了解现有架构
4. 需要先创建 client 的改造计划（proposal + tasks）

## 用户偏好

- 包管理器：**pnpm**（所有 npm 相关操作使用 pnpm）
- 语言偏好：中文交流
- Git：gitstatusd 经常抢 index.lock，需要循环 `rm -f .git/index.lock` 再执行 git 命令
