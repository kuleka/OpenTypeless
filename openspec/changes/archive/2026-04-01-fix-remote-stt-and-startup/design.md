## Context

App 启动时 `AppCoordinator.startNormalOperation()` 无条件走本地 WhisperKit 模型加载流程（查找已下载模型 → 加载 → 激活）。当用户在 onboarding 选择 remote STT 时，没有本地模型可加载，transcription engine 为 nil，录音结束后抛出 `modelNotLoaded`。

另外 `EngineProcessManager.resolveEngineBinary()` 在构造启动参数时传了 `--host`，但 Engine CLI 只支持 `--port` 和 `--stub`，导致从 repo venv 自动启动时失败。

Dock 图标问题：app 配置了 `LSUIElement = YES`（纯菜单栏应用），窗口打开时不显示 Dock 图标。

## Goals / Non-Goals

**Goals:**
- remote STT 模式下 app 正常启动，跳过本地模型加载，直接初始化远程 transcription engine
- 修正 EngineProcessManager 启动参数
- 窗口可见时显示 Dock 图标

**Non-Goals:**
- 不改 Engine 端代码
- 不改 onboarding 流程
- 不重构 TranscriptionService 架构

## Decisions

### 1. startNormalOperation() 根据 sttMode 分支

在模型加载逻辑前检查 `settingsStore.sttMode`：
- `.local`：走现有 WhisperKit 加载流程（不变）
- `.remote`：跳过模型加载，调用 `transcriptionService.loadModel()` 并传 `.remote` 模式，初始化 `EngineTranscriptionEngine`，然后继续后续初始化（statusbar、floating indicator 等）

**为什么不在 TranscriptionService 层做**：问题在 AppCoordinator 层——它在调 `loadModel` 之前先查本地模型列表，remote 模式下这些逻辑根本不该执行。

### 2. 移除 --host 参数

`resolveEngineBinary()` 返回的 arguments 中去掉 `--host` 和对应的值，只保留 `serve --port <port>`。Engine CLI 默认绑定 127.0.0.1，不需要 host 参数。

### 3. Dock 图标：NSApp.setActivationPolicy 动态切换

窗口打开时切换到 `.regular`（显示 Dock 图标），所有窗口关闭后切回 `.accessory`（隐藏）。这是 macOS 菜单栏应用的标准做法。

## Risks / Trade-offs

- **[Risk] remote 模式启动后切换回 local**：用户可能在 Settings 里切换 sttMode。切换后需要触发 loadModel 加载本地模型。→ 现有 Settings 变更监听应该已处理，需验证。
- **[Risk] Dock 图标切换闪烁**：频繁切换 activationPolicy 可能有视觉闪烁。→ 只在窗口 show/close 时切换，频率低，可接受。
