## Context

OpenTypeless 由 Engine（Python FastAPI）和 Client（macOS Swift）组成，通过 localhost HTTP 通信。当前用户需手动在终端启动 Engine，然后在客户端配置 API 密钥——这对非技术用户不可接受。

目标：用户安装后打开 App，走完引导流程，即可使用。Engine 对用户完全透明。

现有代码基础：
- `EngineClient` 已实现 `/health`、`/config`、`/polish` 调用
- `SettingsStore` 已有 Engine endpoint/API key 持久化
- `PermissionManager` 已有麦克风权限检查
- `AppCoordinator` 管理 App 生命周期

## Goals / Non-Goals

**Goals:**
- App 自动管理 Engine 进程生命周期（启动、监控、重启、退出）
- 首次启动引导用户完成所有必要配置（权限 + API + STT 模式）
- 状态栏 UI 反映 Engine 状态，用户始终知道系统是否就绪
- 支持重新运行引导流程

**Non-Goals:**
- Engine 安装器/打包器（用户需预先安装 Engine）
- 流式音频传输（Phase 3）
- 多 Engine 实例管理
- Engine 自动更新

## Decisions

### 1. Engine 进程管理：Foundation `Process` + health polling

使用 `Process`（NSTask）spawn Engine 子进程，通过定时 `GET /health` 监控存活。

**替代方案**：XPC Service — 更 Apple 原生，但 Engine 是 Python 进程无法作为 XPC bundle；launchd plist — 复杂且不适合 app-scoped 生命周期。

**理由**：`Process` 简单直接，适合管理外部可执行文件。Health polling 复用已有 EngineClient 逻辑。

### 2. Engine 二进制发现：三级优先级链

1. `SettingsStore.enginePath`（用户手动设置）
2. `which open_typeless` 等效的 PATH 查找
3. 相对于 App bundle 的 repo venv 路径

**理由**：覆盖开发者（venv）、普通安装（PATH）、高级用户（自定义路径）三种场景。

### 3. Onboarding 架构：独立 SwiftUI Window + step state machine

Onboarding 作为独立 `Window` 呈现（非 sheet），内部用 enum state machine 驱动步骤流转。每个步骤是独立 View。

**替代方案**：NavigationStack — 步骤间有条件跳转（如本地 STT 跳过 STT 配置），NavigationPath 管理会复杂。TabView — 无法控制前进/后退逻辑。

**理由**：State machine 明确控制流转条件，每个步骤的 View 独立简洁。

### 4. Onboarding 步骤

```
Welcome → Permissions (mic + accessibility) → STT Mode → LLM Config [→ STT Config if remote] → Hotkey (optional) → Complete
```

Engine spawn 在 App 启动时立即开始（与 onboarding 并行），Complete 步骤只是验证 Engine 状态。

### 5. Accessibility 权限：必需，非可选

Accessibility 用于获取当前 app 的 bundle ID 和窗口标题（场景检测）。没有它 Engine 无法区分场景，润色质量大打折扣。

**理由**：场景检测是核心差异化功能，降级为 default 场景的体验不值得作为 "可选" 呈现。

### 6. EngineProcessManager 作为独立服务

新建 `EngineProcessManager` 服务，注入 `AppCoordinator`。职责：spawn、monitor、restart、terminate。暴露 `@Published engineStatus` 供 UI 绑定。

**理由**：遵循现有 service 模式（DI、protocol boundary），不污染 AppCoordinator 逻辑。

### 7. Engine 状态模型

```swift
enum EngineStatus {
    case stopped          // 未启动
    case starting         // 已 spawn，等待 health
    case connected        // health OK，已 push config
    case unconfigured     // health OK，但无 API credentials
    case error(String)    // 启动失败或多次重启失败
}
```

## Risks / Trade-offs

- **Engine 启动延迟** → Onboarding 期间并行启动 Engine，到 Complete 步骤时通常已就绪。如果仍未就绪，显示 spinner 等待。
- **Accessibility 权限 UX** → macOS 要求用户手动在 System Settings 添加 App，无法 programmatic 授予。需清晰的说明文案和 "打开设置" 按钮。
- **Engine binary 不存在** → 发现链全部失败时，显示安装指引。未来可考虑 bundled Engine（但 Python 打包复杂，不在此 scope）。
- **子进程孤儿** → App 异常退出时 Engine 可能变孤儿。Engine 侧可加 parent PID 监控（best-effort），但不在 Phase 1 scope 强制要求。
- **端口冲突** → 默认端口 19823 被占用时，需要提示用户或自动选择端口。当前 scope 仅报错，不做自动端口选择。

## Open Questions

- Engine 是否需要支持 bundled distribution（包含在 .app bundle 内）？→ 暂不支持，留给后续迭代
- 是否需要 Engine 版本兼容性检查（Client 要求最低 Engine 版本）？→ 有价值但不在此 scope
