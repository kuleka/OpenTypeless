## Why

Engine 有 68 个 pytest 单元测试，Client 有 452 个 Swift Testing 单元测试，但 Client 的所有 Engine 交互都是 mock 的（MockURLSession），从未验证过 Client 真的能和 Engine 通信。需要端到端集成测试：在 Swift 测试中启动真实 Engine 进程，用真实的 EngineClient 走完整链路。

## What Changes

- 新增 Swift 集成测试文件，在测试中启动真实 Engine 子进程（`python -m open_typeless.cli serve`）
- 验证完整主链路：health check → config push → polish（text 模式）
- 验证错误路径：未配置时调用 polish、无效输入
- 可能需要在 Engine 端添加 mock/stub 模式，让 Engine 在不调用真实 LLM/STT API 的情况下返回预设响应

## Capabilities

### New Capabilities
- `e2e-client-engine-integration`: Client ↔ Engine 端到端集成测试，Swift 测试中启动真实 Engine 进程并验证完整通信链路

### Modified Capabilities

## Impact

- `clients/macos/PindropTests/` — 新增 E2E 测试文件
- `engine/` — 可能新增 test/stub 模式支持（`--stub` flag 或类似机制）
- Xcode project — 添加新测试文件引用
- 测试运行时间增加（需要启动/等待 Engine 进程）
