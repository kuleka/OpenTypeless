## 1. Engine Stub Mode

- [x] 1.1 给 CLI `serve` 命令添加 `--stub` flag，设置环境变量 `OPEN_TYPELESS_STUB=1`
- [x] 1.2 在 server.py lifespan 中检测 stub 模式，替换 `llm.polish` 为返回 `"[stub] {text}"` 的函数
- [x] 1.3 在 server.py lifespan 中检测 stub 模式，替换 `stt.transcribe` 为返回 `"stub transcription"` 的函数
- [x] 1.4 验证 stub 模式下现有 Engine 单元测试仍通过

## 2. Swift E2E Test Infrastructure

- [x] 2.1 创建 `EngineE2ETests.swift`，实现 Engine 子进程启动（`engine/.venv/bin/python -m open_typeless.cli serve --port 29823 --stub`）
- [x] 2.2 实现 health check 轮询等待（最多 10s），Engine 就绪后才运行测试
- [x] 2.3 实现 teardown 逻辑（terminate 进程），venv 不存在时 skip 所有测试
- [x] 2.4 将测试文件添加到 Xcode project

## 3. E2E Test Cases

- [x] 3.1 测试 health check：EngineClient.health() 返回 status "ok" + version
- [x] 3.2 测试 config push：EngineClient.pushConfig() 成功 + fetchConfig() 返回脱敏 key
- [x] 3.3 测试 polish 主链路：pushConfig → polish(text + context) 返回润色结果 + 场景检测 + timing 字段
- [x] 3.4 测试未配置错误：不 push config 直接调 polish，验证抛出 NOT_CONFIGURED 错误
- [x] 3.5 运行完整测试套件确认无回归
