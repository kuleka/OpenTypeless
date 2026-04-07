## Context

Onboarding flow 由 `OnboardingWindowController`（NSWindow 管理）和 `OnboardingWindow`（SwiftUI 容器）组成，内含 7 个步骤视图。当前实现在窗口缩放、表单滚动、指示器逻辑、输入校验、权限检查等方面有多处 UI 问题。

核心约束：
- macOS 原生 NSWindow + SwiftUI hosting，窗口大小通过 `setFrame(animate:)` 控制
- 步骤间使用 `.transition(.asymmetric(insertion:removal:))` + `.animation(.spring)` 切换
- 窗口 resize 通过 `onPreferredContentSizeChange` 回调从 SwiftUI 传回 NSWindow

## Goals / Non-Goals

**Goals:**

- 窗口在步骤切换时双向平滑缩放（涨到 700px 后能缩回 600px）
- LLMConfig/STTConfig 表单在小屏幕上可滚动
- STTConfig 步骤在指示器中有正确的视觉反馈
- API Base URL 输入有基本格式校验
- 权限检查不产生 UI 闪烁
- 各步骤按钮宽度和间距一致

**Non-Goals:**

- 不重构 onboarding 步骤导航架构
- 不添加新的 onboarding 步骤
- 不改变 NSWindow ↔ SwiftUI 的通信机制
- 不添加 URL 可达性验证（只做格式检查）

## Decisions

### 1. 窗口双向 resize

移除 `ensureWindowCanFitContentSize()` 中阻止缩小的 guard，改为始终按目标大小 resize。方法名改为 `resizeWindowToFitContentSize()` 以反映新语义。

**替代方案**：固定窗口为最大尺寸 (800×700) 不做 resize → 简单但浪费空间，体验差。

### 2. 窗口 resize 与动画同步

在 `resizeWindowToFitContentSize()` 中使用 `NSAnimationContext.runAnimationGroup` 配合与 SwiftUI spring 动画相近的时长 (0.4s)，使窗口 resize 与内容切换视觉同步。

### 3. 配置表单 ScrollView

在 `LLMConfigStepView` 和 `STTConfigStepView` 的 `configFields` 区域外层包裹 `ScrollView(.vertical, showsIndicators: false)`，保持现有 `maxHeight: .infinity` frame，让内容超出时可滚动。

### 4. STTConfig 步骤指示器

将 `sttConfig` 加入 `indicatorSteps` 数组，使其在 dot indicator 中有独立的点。这样在 remote STT 模式下多显示一个 dot，local 模式下仍然隐藏。`indicatorSteps` 改为计算属性，根据 sttMode 动态返回。

**替代方案**：让 sttConfig 与 llmConfig 共享同一个 dot → 导致回退时 dot 状态混淆，不采用。

### 5. URL 格式校验

在 `canContinue` 计算属性中增加 URL 校验：trimmed apiBase 必须以 `http://` 或 `https://` 开头，且能通过 `URL(string:)` 初始化。不满足时 Save 按钮 disabled。

### 6. 权限检查防闪烁

`PermissionsStepView.requestAccessibility()` 中，移除同步返回值立即赋值的逻辑，改为在 Task 内统一延迟 check 后赋值一次，避免状态翻转。

## Risks / Trade-offs

- [动态 indicator dots 数量变化] → sttMode 切换时 dot 数量变化可能让用户感到突兀。缓解：dot 数量变化时加 animation。
- [ScrollView 嵌套] → 如果外层已有 ScrollView 可能冲突。确认：当前外层无 ScrollView，安全。
- [URL 校验可能过严] → 某些用户可能用非标准 URL（如 `localhost:8080`）。缓解：校验只要求 `http(s)://` 前缀 + URL 可解析，不检查 host 格式。
