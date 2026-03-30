## Context

macOS Client（Pindrop 基座）当前的启动流程假设用户是一个"本地语音输入工具"的使用者：Onboarding 引导下载本地 Whisper 模型、请求麦克风权限、配置快捷键。Engine 完全不在这个流程里——用户需要自己在终端启动 `open-typeless serve`，自己在 Settings 里配置 LLM provider。

但 OpenTypeless 的核心卖点是场景感知润色，这完全依赖 Engine。当前体验等于把最重要的功能藏在了最难找的地方。

另外，场景检测（通过 app bundle ID 和 window title 匹配不同润色策略）依赖 macOS Accessibility API。当前 Onboarding 把 Accessibility 权限标为"可选"，但没有这个权限，Engine 拿不到上下文，润色质量会退化到 default 场景。

约束条件：
- Engine 是 Python FastAPI 应用，macOS Client 是 Swift 原生应用
- Engine 和 Client 通过 localhost HTTP 通信，协议已稳定（v1.4）
- 当前 Engine 通过 `uv` 管理的 venv 运行，没有独立二进制分发
- app 目前不做 App Store 分发（开发者自签或 ad-hoc）

## Goals / Non-Goals

**Goals:**
- 用户打开 app 后，Engine 自动在后台启动和管理，用户无需感知
- Onboarding 引导用户完成真正必要的配置：权限（麦克风 + Accessibility）、LLM provider（API key）、STT 模式选择
- 完成 Onboarding 时后台已确认 Engine 连接就绪，用户只看到"一切就绪"
- Engine 进程异常退出时自动重启，app 退出时自动清理
- 状态栏图标反映 Engine 运行状态

**Non-Goals:**
- 跨平台 Engine 分发（Windows / Linux 客户端启动 Engine）——这是未来各端自己的问题
- Engine 的 Docker / 容器化部署
- 重新设计 Engine HTTP 契约
- Pindrop 品牌重命名（target name、bundle ID 等）
- 流式传输 / WebSocket

## Decisions

### 1. Engine 进程管理：app 内 spawn + 健康监控

**选择**：Client 启动时通过 `Process`（Foundation）在后台 spawn Engine 进程，使用现有的 `open-typeless serve` 命令。通过周期性 `GET /health` 监控存活状态，进程异常退出时自动重启（带退避策略）。app 退出时 `SIGTERM` 终止子进程。

**替代方案**：
- LaunchAgent / launchd 托管。否决——增加安装复杂度，用户需要手动注册 plist，且与 app 生命周期脱钩。
- 将 Engine 编译为独立二进制打包进 app bundle。否决——Python 生态的冻结打包（PyInstaller / Nuitka）体积大（200MB+）、构建复杂、调试困难，且 Engine 仍在快速迭代。
- 在 app 内嵌入 Python 运行时。否决——Swift-Python 桥接复杂度高，线程模型冲突。

**前提**：用户机器上已安装 Engine（通过 `uv` 或 `pip`）。首次启动时如果找不到 `open-typeless` 命令，引导用户安装。未来可以在 Distribution 阶段改为 Homebrew formula 一键安装。

### 2. Engine 二进制发现策略

**选择**：按优先级查找 Engine 可执行文件：
1. 用户在 Settings 中手动指定的路径（高级用户场景）
2. `$PATH` 中的 `open-typeless` 命令
3. 项目仓库内的已知路径（开发者场景：`../../engine/.venv/bin/open-typeless`）

找不到时在 Onboarding 或 Settings 中展示安装引导。

**替代方案**：
- 只支持 $PATH 查找。否决——开发者从源码跑时 venv 里的命令不一定在 PATH 里。
- 打包 Engine 到 app bundle。否决——同决策 1。

### 3. Onboarding 向导步骤重设计

**选择**：新的步骤序列：

```
1. 欢迎（品牌定位介绍）
2. 权限（麦克风 + Accessibility，都标记为必需，Accessibility 不授权则警告场景检测降级）
3. STT 模式选择（本地 / 远程）
   → 如果本地：选择并下载 Whisper 模型
   → 如果远程：配置 STT provider（API base + key + model）
4. LLM Provider 配置（API base + key + model，必填，这是润色的核心依赖）
5. 快捷键确认（可选，展示默认配置，允许自定义）
6. 完成（后台已验证 Engine 连接 + config push 成功，展示"一切就绪"）
```

Engine 连接在步骤 1-5 的过程中后台异步完成（spawn 进程 → health check → 等待 ready）。到步骤 6 时，如果 Engine 还没 ready，等待并展示进度；如果 Engine 启动失败，展示故障排除引导。

**替代方案**：
- 保留现有步骤顺序只加 Engine 步骤。否决——现有顺序是为纯本地 Pindrop 设计的，不符合 OpenTypeless 的优先级。
- 把 Engine 配置放在最前面。否决——用户还没给权限就启动 Engine 没有意义，且权限对话框是 OS 级的，应该尽早处理。

### 4. Accessibility 权限：从可选提升为必需引导

**选择**：Onboarding 中 Accessibility 与麦克风一起引导，明确告知用途（"获取当前应用和窗口信息，让润色风格匹配你的使用场景"）。如果用户拒绝，不阻止继续，但显示明确警告："场景检测将不可用，所有润色将使用默认风格"。

**替代方案**：
- 强制要求，不授权不能继续。否决——Accessibility 权限需要用户手动到系统设置中开启，强制阻断体验太差。
- 保持现状标为可选。否决——这是核心功能的基础，"可选"的表述误导用户。

### 5. Engine 管理模式标志

**选择**：给 Engine CLI 加一个 `--managed` 标志（或等效机制），表示该进程由 Client 管理。在 managed 模式下：
- 日志输出到 stdout（Client 可以捕获和转发到 `Log` 系统）
- 不绑定到终端 TTY
- 健康检查失败时不自行重试（由 Client 管理重启）

**替代方案**：
- 不加标志，直接用现有 `serve` 命令。可行但会失去管理信号和日志集成的能力。如果实现成本太高可以先用 `serve`，后续再加 `--managed`。

## Risks / Trade-offs

- **[用户机器没有安装 Engine]** → 首次启动时检测，展示安装引导（`pip install` 或 `uv pip install`）。未来 Distribution 阶段通过 Homebrew formula 解决。
- **[Engine spawn 失败（权限、路径、依赖缺失）]** → 捕获 `Process` 错误，展示具体原因和修复步骤，不阻断 app 启动（降级为无润色模式）。
- **[Engine 启动慢导致 Onboarding 完成页等待]** → Engine 健康检查通常 <1s。设置合理超时（5s），超时后允许用户继续但标记为"Engine 正在启动"。
- **[多个 app 实例 spawn 多个 Engine]** → 启动前先 health check 现有端口，如果已有 Engine 在运行则复用，不重复 spawn。
- **[Python 版本或依赖冲突]** → 建议用户使用 `uv` 管理独立 venv，安装引导中明确这一点。
- **[Accessibility 权限引导可能让用户不安]** → 明确解释只读取 app 名称和窗口标题，不读取任何输入内容或屏幕内容。

## Migration Plan

1. 新增 `EngineProcessManager` 服务，实现 spawn / monitor / restart / terminate
2. 改造 `AppCoordinator` 启动流程，在 `start()` 中先启动 Engine 再进入 Onboarding 或正常流程
3. 重构 `OnboardingWindow` 步骤定义和各步骤 View
4. 修改 `AIEnhancementSettingsView` 中 Engine 状态展示的文案和逻辑
5. 修改 `StatusBarController` 增加 Engine 状态图标
6. Engine 侧：评估是否需要 `--managed` 标志，如果需要则添加 CLI 参数
7. 更新测试覆盖新增的进程管理和 Onboarding 流程

回滚策略：所有改动在 Client 侧，不涉及 Engine HTTP 契约变更或持久化数据结构变更。revert commit 即可恢复到现有行为。

## Open Questions

- Engine 二进制的长期分发方案（打包进 app bundle vs Homebrew vs 其他）应该在本 change 中确定，还是留给独立的 Distribution change？
- `--managed` 模式是否值得在本 change 中实现，还是先用 `serve` 命令走通主流程？
- 是否需要支持用户连接到远程 Engine（非 localhost）？如果需要，进程管理逻辑应该只在 localhost 模式下生效。
