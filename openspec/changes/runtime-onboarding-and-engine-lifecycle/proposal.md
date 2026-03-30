## Why

OpenTypeless 的核心体验是「说话 → 场景润色 → 粘贴」，但当前用户首次打开 app 后完全不知道 Engine 的存在。Onboarding 向导是 Pindrop 遗留的，只覆盖本地模型下载和权限，不涉及 Engine 连接、LLM provider 配置、或 Accessibility 权限的必要性说明。用户走完向导后，如果没有手动在终端启动 Engine 并配置 provider，核心润色功能完全不可用——而 app 只会在录音后弹一个 toast 说 "Engine is offline"。

这不是一个可以接受的产品体验。Engine 应该对用户透明，app 应该自己管理 Engine 生命周期，onboarding 应该引导用户完成真正必要的配置（权限 + API key），最后确认一切就绪。

## What Changes

### 1. Engine 进程生命周期管理

- app 启动时自动在后台 spawn Engine 进程（`open-typeless serve`）
- app 退出时自动终止 Engine 进程
- Engine 进程异常退出时自动重启
- 用户不需要知道 Engine 的存在，不需要打开终端

这要求解决 Engine 的分发问题：Engine 要么打包进 app bundle，要么作为前置依赖安装（例如 Homebrew）。具体方案在 design 阶段确定。

### 2. Onboarding 向导重新设计

当前 7 步向导需要围绕 OpenTypeless 的实际需求重新设计：

**必须覆盖：**
- 麦克风权限（录音必需）
- Accessibility 权限（获取当前 app/window 上下文，场景检测必需，不是可选的）
- LLM Provider 配置（API key + model，润色功能的核心依赖）
- STT 模式选择（本地 vs 远程），如果选本地则需要下载模型

**不需要用户感知：**
- Engine 连接（后台自动完成）
- Engine health check / config push（后台自动完成）
- 完成页只需确认「一切就绪」，Engine 连接状态在后台验证通过即可

**可选：**
- 快捷键自定义
- 远程 STT provider 配置（仅在选择远程 STT 模式时）

### 3. Engine 连接状态改进

- 状态栏图标应反映 Engine 状态（正常 / 离线 / 配置缺失）
- Engine 离线时的用户引导应更具体、更可操作
- Settings 中 Engine 状态展示保持现有基础，但措辞和引导需要适配「Engine 由 app 管理」的新模型

## Capabilities

### New Capabilities
- `engine-lifecycle`: 定义 app 如何管理 Engine 进程的启动、监控、重启和退出
- `onboarding-v2`: 定义面向 OpenTypeless 核心体验的首次启动向导

### Modified Capabilities
- `engine-runtime`: Engine 运行时状态机需要适配 app-managed Engine 的新语义（不再有"用户手动启动"的场景）
- `client-settings`: Engine 设置页需要移除"手动启动 Engine"的引导文案

## Impact

- **新增代码**：Engine 进程管理服务（Client 侧）、Onboarding 向导改造
- **修改代码**：AppCoordinator（Engine 启动集成）、OnboardingWindow（步骤重设计）、AIEnhancementSettingsView（状态展示适配）、StatusBarController（状态图标）
- **分发**：需要确定 Engine 二进制如何随 app 交付（打包 / 安装依赖）
- **Engine 侧**：无 HTTP 契约变更，可能需要 CLI 参数调整以支持被 app spawn
- **风险**：Engine 打包方案影响 app 体积和分发流程，需要在 design 阶段明确取舍
