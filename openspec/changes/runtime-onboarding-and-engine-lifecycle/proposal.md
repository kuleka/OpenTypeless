## Why

OpenTypeless 的核心体验依赖 Engine 做场景润色，但当前用户必须手动在终端启动 Engine，Onboarding 向导完全不涉及 Engine 配置，Accessibility 权限被标为可选（实际上场景检测必需）。用户走完向导后核心功能不可用，只会在录音后看到 "Engine is offline" toast。Engine 应该对用户透明，app 应该自己管理 Engine 生命周期，onboarding 应该引导用户完成真正必要的配置。

## What Changes

- **新增 Engine 进程生命周期管理**：app 启动时自动 spawn Engine 进程，退出时终止，异常退出时自动重启。用户不需要知道 Engine 的存在。需要解决 Engine 二进制的分发方式（打包进 app bundle 或作为前置依赖）。
- **重新设计 Onboarding 向导**：围绕 OpenTypeless 实际需求重构步骤——麦克风权限（必需）、Accessibility 权限（必需，场景检测依赖）、STT 模式选择（本地/远程）、LLM Provider 配置（API key + model）。Engine 连接在后台自动完成，完成页确认一切就绪。
- **BREAKING** Accessibility 权限从可选变为必需引导项，不授权时明确告知场景检测降级。
- 状态栏图标反映 Engine 运行状态。
- Engine 离线/未配置时的引导文案适配「Engine 由 app 管理」的新模型，移除所有「手动启动 Engine」的提示。

## Capabilities

### New Capabilities
- `engine-lifecycle`: app 如何管理 Engine 进程的启动、监控、重启、退出和二进制分发
- `onboarding-v2`: 面向 OpenTypeless 核心体验的首次启动向导流程设计

### Modified Capabilities
- `runtime-onboarding`: 运行时状态机需要适配 app-managed Engine 语义（移除用户手动启动场景，新增进程管理相关状态）
- `client-settings`: Engine 设置页移除手动启动引导文案，适配自动管理模型

## Impact

- 新增代码：Engine 进程管理服务（Client 侧，`Process` spawn + 健康监控）、Onboarding 向导 UI 重构
- 修改代码：`AppCoordinator`（Engine 启动集成）、`OnboardingWindow`（步骤重设计）、`AIEnhancementSettingsView`（状态展示）、`StatusBarController`（状态图标）
- 分发：需要确定 Engine 二进制打包方案，影响 app 体积和构建流程
- Engine 侧：无 HTTP 契约变更，可能需要 CLI 参数调整（如 `--managed` 模式标志、日志输出方式）
