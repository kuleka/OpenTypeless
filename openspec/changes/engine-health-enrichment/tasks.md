## 1. Engine 模型与统计基础

- [x] 1.1 在 `engine/open_typeless/models.py` 中添加 `RequestStats` 模型（`requests_total: int`, `requests_failed: int`, `last_request_at: Optional[str]`）并扩展 `HealthResponse`（新增 `configured: bool = False`, `stt_configured: bool = False`, `uptime_seconds: int = 0`, `stats: Optional[RequestStats] = None`）
- [x] 1.2 在 `engine/open_typeless/server.py` 中添加 `_EngineStats` dataclass 和 `_start_time` 模块变量，在 `lifespan` 中初始化 `_start_time`

## 2. Engine 端点改造

- [x] 2.1 在 `server.py` 的 `/polish` 和 `/transcribe` handler 中添加计数逻辑：入口处 `requests_total += 1`，错误返回时 `requests_failed += 1`，每次请求更新 `last_request_at`
- [x] 2.2 更新 `server.py` 的 `/health` handler：构造完整 `HealthResponse`，包含 `is_configured()`、`is_stt_configured()`、uptime 计算、stats 数据

## 3. Engine 测试

- [x] 3.1 更新 `engine/tests/test_server.py` 中现有 health 测试：断言新字段 `configured`、`stt_configured`、`uptime_seconds`、`stats` 的存在和默认值
- [x] 3.2 新增测试：配置后 health 返回 `configured: true`；请求后 stats 计数正确；失败请求计入 `requests_failed`

## 4. 客户端模型扩展

- [x] 4.1 在 `EngineClient.swift` 中添加 `HealthStatsResponse` 结构体并扩展 `HealthResponse`（新增 `configured: Bool?`, `sttConfigured: Bool?`, `uptimeSeconds: Int?`, `stats: HealthStatsResponse?`，均为 optional）
- [x] 4.2 在 `SettingsStore.swift` 的 `EngineRuntimeState` 中添加 `uptimeSeconds: Int?`、`requestsTotal: Int?`、`requestsFailed: Int?` 字段，更新 `.ready()` 工厂方法

## 5. 客户端数据传递与展示

- [x] 5.1 在 `EngineRuntimeCoordinator.swift` 的 `evaluateEngineRuntime` 中将 `healthResponse` 的新字段传入 `EngineRuntimeState.ready()`
- [x] 5.2 在 `AIEnhancementSettingsView.swift` 的 Engine Connection 卡片中，状态标签下方添加一行展示 uptime 和请求统计（仅 ready 状态且有数据时显示）

## 6. 文档与验证

- [x] 6.1 更新 `docs/api-contract.md` Section 2（GET /health）的响应 schema 和字段说明
- [x] 6.2 运行 Engine 测试 (`cd engine && .venv/bin/python -m pytest tests/ -v`) 确认全部通过
- [x] 6.3 构建客户端 (`xcodebuild`) 确认编译通过
