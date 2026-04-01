## Why

Remote STT 模式下录音后报 "No model loaded" 错误，因为 `AppCoordinator.startNormalOperation()` 无条件加载本地 WhisperKit 模型，不区分 sttMode。这是用户选择 remote STT 后完全无法使用核心录音功能的 blocker。同时 Dock 图标在设置页面打开时不显示，影响用户体验。

## What Changes

- **修复 remote STT 启动流程**：`startNormalOperation()` 根据 `sttMode` 跳过本地模型加载，改为初始化远程 transcription engine
- **修复 Dock 图标显示**：确保 app 窗口可见时 Dock 图标正常显示
- **修复 EngineProcessManager 启动参数**：移除 CLI 不支持的 `--host` 参数

## Capabilities

### New Capabilities

（无新能力）

### Modified Capabilities

- `engine-lifecycle`: EngineProcessManager 的 `resolveEngineBinary()` 传了 CLI 不支持的 `--host` 参数，需修正
- `dual-mode-transcription`: remote STT 模式下 app 启动流程需要跳过本地模型加载，正确初始化远程 engine

## Impact

- `clients/macos/OpenTypeless/AppCoordinator.swift` — `startNormalOperation()` 主要改动点
- `clients/macos/OpenTypeless/Services/EngineSupport/EngineProcessManager.swift` — 移除 `--host` 参数
- `clients/macos/OpenTypeless/Info.plist` 或 `OpenTypelessApp.swift` — Dock 图标显示逻辑
