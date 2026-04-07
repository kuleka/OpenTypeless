## Why

Onboarding 是用户首次使用 OpenTypeless 的入口，当前存在多个布局和交互问题影响体验：窗口从 LLMConfig/STTConfig 步骤返回后不会缩回原始大小，配置表单在小屏幕上溢出裁切，步骤指示器在 STTConfig 步骤显示错误高亮，各步骤按钮宽度和间距不一致，权限检查 UI 闪烁，URL 输入缺乏格式校验。

## What Changes

### 高优先级
- 修复 `OnboardingWindowController.ensureWindowCanFitContentSize()` 使窗口支持双向缩放（涨 + 缩），回退步骤时窗口恢复原始大小
- 为 `LLMConfigStepView` 和 `STTConfigStepView` 的配置表单区域添加 `ScrollView`，防止小屏溢出

### 中优先级
- 为 `LLMConfigStepView` 和 `STTConfigStepView` 的 API Base URL 输入添加基本 URL 格式校验（http/https 前缀检查）
- 修正 `OnboardingWindow` 步骤指示器逻辑，让 STTConfig 步骤有独立的 dot 或正确的高亮状态
- 修复 `PermissionsStepView` 权限检查时 UI 状态闪烁（同步调用 + 异步复查导致状态翻转）
- 修复窗口 resize 与内容动画不同步问题（resize 先于动画完成导致内容"跳"）

### 低优先级
- 统一所有步骤的按钮宽度为 200px（HotkeySetupStepView 180→200、CompleteStepView 240→200）
- 修复 `CompleteStepView` 的 padding 不对称问题（`.padding(40)` → `.padding(.horizontal, 40)`）

## Capabilities

### New Capabilities

_(无新增能力)_

### Modified Capabilities

- `onboarding-flow`: 窗口缩放行为变更（双向 resize）、步骤指示器逻辑修正、表单滚动支持、URL 校验、权限检查防闪烁、样式统一

## Impact

- 仅影响 macOS 客户端 Onboarding UI 层，7 个 Swift 文件
- 无 API 变更、无数据模型变更、无依赖变更
- 涉及文件：`OnboardingWindowController.swift`、`OnboardingWindow.swift`、`LLMConfigStepView.swift`、`STTConfigStepView.swift`、`CompleteStepView.swift`、`HotkeySetupStepView.swift`、`PermissionsStepView.swift`
