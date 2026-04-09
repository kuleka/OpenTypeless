## Why

现有 E2E 测试（EngineE2ETests）仅覆盖"启动 venv python → 单次请求 → 终止"的 happy path。Engine 生命周期的关键行为——崩溃自动重启、bundled binary 优先发现、EngineProcessManager 驱动的完整主链路（spawn → health polling → config push → polish）——完全没有 E2E 级别的验证。随着 bundled binary 刚加入，这些路径需要真实进程级测试来保障。

## What Changes

- 新增 E2E 测试：Engine 进程崩溃后 EngineProcessManager 自动重启并恢复 healthy
- 新增 E2E 测试：使用 bundled binary（`engine/dist/open-typeless`）替代 venv python 跑 E2E，验证打包产物可用
- 新增 E2E 测试：EngineProcessManager 驱动完整主链路——启动 → health polling → config push → polish 请求成功
- 重构现有 E2E 测试基础设施，支持 bundled binary 和 venv 两种 Engine 发现路径

## Capabilities

### New Capabilities

_无新增 capability——本变更扩展已有测试覆盖，不引入新的用户可见功能。_

### Modified Capabilities

- `e2e-engine-testing`: 扩展 E2E 测试要求，新增 bundled binary 路径测试和进程生命周期测试场景
- `engine-lifecycle`: 新增 bundled binary Priority 0 发现场景的测试要求

## Impact

- `clients/macos/OpenTypelessTests/EngineE2ETests.swift` — 大幅扩展，新增测试用例和 helper
- `clients/macos/OpenTypelessTests/EngineProcessManagerTests.swift` — 可能新增真实进程级测试
- 测试依赖 `engine/dist/open-typeless` 存在（bundled binary 测试），不存在时应 skip
- 测试依赖 `engine/.venv` 存在（venv 测试），不存在时应 skip
