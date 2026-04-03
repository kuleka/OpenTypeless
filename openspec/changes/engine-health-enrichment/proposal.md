## Why

Engine `/health` 目前只返回 `{status, version}`，客户端无法从健康检查中得知配置状态或运行情况。要判断 Engine 是否 ready，客户端需要额外调用 `GET /config`，且完全没有请求统计信息。扩展 `/health` 响应是业界标准做法（类似 Kubernetes readiness probe），让客户端用一次轮询就能获得完整的 Engine 运行状况。

## What Changes

- Engine `/health` 响应新增字段：`configured`、`stt_configured`、`uptime_seconds`、`stats`（含 `requests_total`、`requests_failed`、`last_request_at`）
- Engine 内部新增内存级请求计数器，在 `/polish` 和 `/transcribe` 处理时累加
- 客户端 `HealthResponse` 解码扩展，新字段均为 optional 以保持向后兼容
- 客户端 `EngineRuntimeState` 携带 uptime 和统计数据
- Settings Engine Connection 卡片在状态标签下方新增一行展示 uptime 和请求统计
- 更新 `docs/api-contract.md` Section 2

## Capabilities

### New Capabilities
- `engine-health-stats`: Engine `/health` 端点的配置状态与请求统计扩展，以及客户端对这些数据的消费和展示

### Modified Capabilities
- `engine-lifecycle`: 客户端 EngineRuntimeState 新增 uptime/stats 字段，EngineRuntimeCoordinator 传递 health 新数据

## Impact

- **Engine API**: `/health` 响应 schema 变更（向后兼容，新字段有默认值）
- **Engine 代码**: `models.py`、`server.py`（新增 `RequestStats` 模型和内存计数器）
- **客户端代码**: `EngineClient.swift`、`SettingsStore.swift`、`EngineRuntimeCoordinator.swift`、`AIEnhancementSettingsView.swift`
- **文档**: `docs/api-contract.md`
- **测试**: Engine 端新增/更新 health 测试，客户端更新 HealthResponse 解码测试
