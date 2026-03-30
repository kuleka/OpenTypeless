## Why

Pindrop（macOS 客户端基座）目前直接集成本地 STT 引擎和 Claude API，所有逻辑耦合在客户端内部。OpenTypeless 的架构要求 Client 作为薄壳，将 STT 和 LLM 润色逻辑委托给独立的 Engine 服务（`docs/api-contract.md` v1.4.0）。改造后 Client 支持本地 STT + 远程润色、全远程两种模式，获得 provider-agnostic 的灵活性和跨平台一致性。

## What Changes

- 新增 `EngineClient`：HTTP 客户端封装，负责与 Engine 的 `/health`、`/config`、`/transcribe`、`/polish` 端点通信
- 新增 `PolishService`：调用 Engine `/polish` 端点做场景感知润色，替代现有的 `AIEnhancementService`（直接调 Claude API）
- 改造 `TranscriptionService`：支持双模式——本地 WhisperKit/Parakeet（保留现有引擎）或远程 Engine `/transcribe`
- 改造 `AppCoordinator` 管线：录音结束后根据 STT 模式选择本地或远程转写，然后统一走 Engine `/polish` 润色
- 改造设置 UI：新增 Engine 连接配置、STT 模式选择（本地/远程）、STT 和 LLM 的 provider 配置（api_base / api_key / model）
- 改造启动流程：启动时 `GET /health` 检查 Engine → `POST /config` 推送用户配置
- **BREAKING**：移除直接调用 Claude API 的 `AIEnhancementService`，所有 LLM 润色通过 Engine 完成

## Capabilities

### New Capabilities

- `engine-client`: HTTP 客户端，封装与 Engine 所有端点的通信（health、config、transcribe、polish），包含连接管理、错误处理、重试逻辑
- `dual-mode-transcription`: 转写双模式支持——本地引擎（WhisperKit/Parakeet）和远程 Engine `/transcribe`，用户可在设置中切换
- `engine-polish`: 通过 Engine `/polish` 端点实现场景感知润色，替代直接 LLM API 调用；Phase 1 统一使用 text 输入模式
- `client-settings`: 设置 UI 改造——Engine 连接配置、STT 模式选择、STT/LLM provider 配置、启动时自动推送配置

### Modified Capabilities

## Impact

- **代码**：主要改动集中在 `clients/macos/Pindrop/Services/` 和 `clients/macos/Pindrop/UI/Settings/`
- **核心文件**：`AppCoordinator.swift`（管线改造）、`TranscriptionService.swift`（双模式）、`AIEnhancementService.swift`（替换为 PolishService）、`SettingsStore.swift`（新配置项）
- **依赖**：无新外部依赖（使用 Foundation URLSession 做 HTTP 调用）
- **API 契约**：遵循 `docs/api-contract.md` v1.4.0，Engine 必须先运行才能使用远程功能
- **保留不变**：HotkeyManager、AudioRecorder、OutputManager、ContextEngineService、浮动指示器、菜单栏 UI 框架
