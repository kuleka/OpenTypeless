## Why

当前用户必须手动安装 Python 和 Engine 才能使用 OpenTypeless，这对普通用户来说门槛太高。将 Engine 打包为独立 binary 并嵌入 .app bundle，可以实现"下载即用"的体验。

## What Changes

- 新增 PyInstaller 构建脚本，将 Engine 打包为 macOS standalone binary（`open-typeless`）
- 在 .app bundle 的 `Contents/Resources/engine/` 目录嵌入打包后的 binary
- EngineProcessManager 新增 Priority 0：从 app bundle 内查找 Engine binary，优先于现有的 custom/PATH/venv fallback
- 新增 Xcode Build Phase 将打包好的 Engine binary 复制到 app bundle
- Engine pyproject.toml 新增 PyInstaller 开发依赖

## Capabilities

### New Capabilities

- `engine-bundling`: PyInstaller 打包配置、构建脚本、app bundle 嵌入

### Modified Capabilities

- `engine-lifecycle`: EngineProcessManager binary 发现逻辑变更——新增从 app bundle 查找的最高优先级路径

## Impact

- **新增文件**: `engine/open-typeless.spec`（PyInstaller spec）、`scripts/build-engine.sh`（构建脚本）
- **修改文件**: `EngineProcessManager.swift`（binary 发现逻辑）、`engine/pyproject.toml`（PyInstaller 依赖）
- **Xcode 项目**: 新增 Copy Files Build Phase
- **App 体积增加**: 约 50-80MB（Python 运行时 + 依赖库）
- **构建流程**: 开发者需先跑 `scripts/build-engine.sh` 生成 binary，再 Xcode build
