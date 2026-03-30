## Why

用户首次启动 Pindrop 时需要完成多项配置（权限授予、API 密钥、STT 模式选择），且 Engine 进程需要在后台运行才能工作。当前没有引导流程，用户必须手动启动 Engine 并自行配置，体验割裂。我们需要一个 onboarding 流程来引导用户完成必要配置，并让 App 自动管理 Engine 生命周期，使用户完全无感知 Engine 的存在。

## What Changes

- App 启动时自动 spawn Engine 进程（`Process`），健康监控并自动重启，退出时 kill
- Engine 二进制发现策略：自定义路径 > `$PATH` > 仓库 venv
- 新增 Onboarding 流程窗口，引导用户完成：
  - 欢迎页
  - 权限授予（麦克风 + Accessibility，均为必需）
  - STT 模式选择（本地 WhisperKit vs 远程）
  - LLM Provider 配置（API key、endpoint、model）
  - 快捷键设置（可选，有默认值）
  - 完成页（后台已验证 Engine 连接就绪）
- Onboarding 完成条件：所有必需权限已授予 + API 配置已填写 + Engine health check 通过
- App 状态栏图标反映 Engine 连接状态

## Capabilities

### New Capabilities
- `engine-lifecycle`: App 自动管理 Engine 进程的启动、监控、重启和退出
- `onboarding-flow`: 首次启动引导流程，收集权限和配置，验证 Engine 就绪
- `engine-status-indicator`: 状态栏 UI 反映 Engine 连接和配置状态

### Modified Capabilities
<!-- 无现有 spec 需要修改 -->

## Impact

- **Client 代码**：新增 `EngineProcessManager` 服务、Onboarding SwiftUI 窗口、状态指示 UI
- **AppCoordinator**：启动流程改造，集成 Engine 生命周期管理和 onboarding 检测
- **SettingsStore**：新增 `hasCompletedOnboarding`、Engine 路径配置等持久化字段
- **现有 EngineClient**：复用 `/health` 和 `/config` 端点，无 API 变更
- **Engine 侧**：无代码变更，仅被 Client 以子进程方式管理
