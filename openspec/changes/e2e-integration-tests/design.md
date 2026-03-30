## Context

Client 的 EngineClient 有完整的 HTTP 调用实现（health、pushConfig、fetchConfig、polish、transcribe），但测试中全部注入 MockURLSession。Engine 有 68 个 pytest 测试用 TestClient 验证端点逻辑。两边从未真正通过网络通信过。

EngineClient 初始化接受 host/port/session，默认 127.0.0.1:19823。Engine CLI `serve` 命令接受 `--port` 参数，host 硬编码为 127.0.0.1。Engine 没有内置 stub/test 模式。

## Goals / Non-Goals

**Goals:**
- 在 Swift 测试中启动真实 Engine 子进程，用真实 EngineClient（URLSession.shared）走完整链路
- 验证主链路：health → pushConfig → polish（text 模式）
- 验证错误路径：未配置调 polish、无效请求
- Engine 端添加 `--stub` 模式，让 LLM/STT 返回预设响应，不依赖外部 API

**Non-Goals:**
- 不测试音频录制、系统权限、UI 交互
- 不测试 transcribe 端点（需要真实音频文件，复杂度高，价值低）
- 不做性能测试

## Decisions

### 1. Engine 添加 `--stub` 模式

**选择**：给 `serve` 命令加 `--stub` flag。启用后，LLM polish 返回固定文本 `"[stub] {original_text}"`，STT transcribe 返回固定文本 `"stub transcription"`。其他所有逻辑（路由、配置、场景检测）正常运行。

**原因**：E2E 测试不应依赖外部 API key，但又需要 Engine 完整运行。stub 模式让 Engine 走完所有内部逻辑但跳过真实 API 调用。比在 Swift 端 mock 更真实。

**实现**：在 server.py 的 lifespan 中检查环境变量 `OPEN_TYPELESS_STUB=1`，如果启用则替换 `llm.polish` 和 `stt.transcribe` 为 stub 函数。CLI `--stub` 设置这个环境变量。

### 2. Swift 测试中用 Process 启动 Engine

**选择**：在 Swift 测试的 setup 中用 `Foundation.Process` 启动 `python -m open_typeless.cli serve --port {random} --stub`，等待 health check 通过后运行测试，teardown 时 terminate。

**原因**：和 EngineProcessManager 的生产代码逻辑一致（也是用 Process 启动），测试更贴近真实场景。

**端口**：使用固定的测试端口（如 29823）避免和生产实例冲突。不用随机端口是因为 Swift 测试中管理端口分配比较麻烦。

### 3. 测试放在现有 PindropTests target

**选择**：新建 `EngineE2ETests.swift` 放在 PindropTests 下，不创建独立 test target。

**原因**：复用现有的测试基础设施和 Xcode 配置。E2E 测试数量少（预计 5-8 个），不值得新建 target。

### 4. 使用 repo venv 中的 Python

**选择**：测试中通过 `engine/.venv/bin/python` 路径启动 Engine，和 EngineProcessManager 的 venv fallback 逻辑一致。

**原因**：测试环境不保证 `open_typeless` 在 PATH 上，但 repo 的 venv 一定存在（开发者已经 setup 过）。

## Risks / Trade-offs

- **[风险] Engine 启动慢** → 设置合理的 health check 超时（10s），第一次启动可能需要几秒
- **[风险] Python venv 不存在** → 测试前置检查，找不到 venv 则 skip 并提示
- **[风险] 端口被占用** → 使用非标准端口 29823，冲突概率低；失败时报清晰错误
- **[取舍] 不测 transcribe** → 需要构造合法音频数据且 stub STT 返回值简单，收益不对等。主链路是 polish
