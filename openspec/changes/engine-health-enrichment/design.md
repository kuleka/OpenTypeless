## Context

Engine `/health` 当前返回 `{status: "ok", version: "0.1.0"}`。客户端每 5 秒轮询一次 health，但要判断配置状态需要额外调 `GET /config`，且没有任何运行统计信息。用户在 Settings Engine Connection 卡片中只能看到连接状态和版本号。

Engine 是单进程 FastAPI 服务（单 asyncio event loop），内存计数器无需加锁。桌面应用场景下 stats 重启归零完全可接受。

## Goals / Non-Goals

**Goals:**
- `/health` 一次调用返回配置状态 + 运行时间 + 请求统计
- 客户端 Settings 页展示 uptime 和请求统计，帮助用户确认管线是否正常
- 向后兼容：新字段有默认值，旧客户端忽略新字段，新客户端兼容旧 Engine

**Non-Goals:**
- 不做 provider 连通性检测（深度健康检查）
- 不持久化统计数据（内存级，随 Engine 重启归零）
- 不用 health 中的 `configured` 字段替代客户端现有的配置检查逻辑（留作后续优化）
- 不改变轮询频率或 EngineProcessManager 的重启策略

## Decisions

### 1. 在 `/health` 中内联统计，而非新建 `/stats` 端点
- **选择**: 扩展 `/health` 响应
- **替代方案**: 新增 `GET /stats` 端点
- **理由**: 客户端已有 5 秒 health 轮询，复用这个通道零额外开销。桌面应用不需要独立的 metrics 端点。统计数据量小（几个数字），不会影响 health 响应延迟。

### 2. 内存级计数器，使用模块变量
- **选择**: `server.py` 中使用 `dataclass` 实例存储 stats，lifespan 中初始化
- **替代方案**: 使用 Prometheus metrics / SQLite / 文件
- **理由**: 单进程桌面应用，无需分布式 metrics。dataclass 比 dict 更类型安全。重启归零符合预期——用户关心的是"这次启动以来"的情况。

### 3. 新字段全部 optional（带默认值）
- **选择**: `configured: bool = False`, `uptime_seconds: int = 0`, `stats: Optional[RequestStats] = None`
- **理由**: 保证向后兼容。Swift 端用 `let configured: Bool?` 解码，旧 Engine 响应缺少该字段时解码为 nil。

### 4. stats 只计 /polish 和 /transcribe
- **选择**: 只统计业务端点的请求
- **替代方案**: 统计所有端点（含 /health、/config、/contexts）
- **理由**: 用户关心的是"语音处理了几次"，不是内部管理调用。health 轮询每 5 秒一次，计入会严重膨胀计数。

### 5. 客户端 UI 只加一行文字
- **选择**: 在 Engine Connection 卡片的状态标签下方加一行 `Uptime: Xh Xm · Requests: N (M failed)`
- **替代方案**: 新建独立 Engine Stats 卡片
- **理由**: 信息量不大，不值得单独卡片。一行文字紧凑且和状态自然关联。

## Risks / Trade-offs

- **Stats 精度**: 内存计数器在 Engine 异常退出时丢失 → 可接受，桌面应用无 SLA 要求
- **Response 体积增大**: 从 ~50 bytes 到 ~200 bytes → 可忽略，每 5 秒一次
- **时钟漂移**: `uptime_seconds` 用 `time.time()` 计算 → 精度足够，不需要 monotonic clock（秒级）
