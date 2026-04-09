## Context

当前 Engine 通过 3 级 fallback 发现（custom path → PATH → repo venv），要求用户自行安装 Python + Engine。这阻碍了面向普通用户的分发。

Engine 是一个 Python FastAPI 应用（依赖：fastapi, uvicorn, httpx, pyyaml, pydantic, python-multipart），入口为 `open_typeless.cli:main`，通过 `serve --port <port>` 启动 Uvicorn HTTP server。

## Goals / Non-Goals

**Goals:**

- 将 Engine 打包为 macOS standalone binary（无需系统 Python）
- 嵌入 .app bundle，用户安装即可用
- 保留现有 3 级 fallback，新增 Priority 0 从 bundle 查找
- 提供开发者构建脚本，一条命令生成 binary

**Non-Goals:**

- 不做 Windows/Linux 打包（仅 macOS）
- 不做 Universal Binary（暂只 arm64，Intel 可后续加）
- 不做自动更新机制（Engine binary 随 app 版本更新）
- 不做代码签名/公证（需要 Apple Developer 证书，后续单独处理）
- 不改变 Engine API 或行为

## Decisions

### 1. PyInstaller onefile 模式

使用 PyInstaller `--onefile` 生成单个可执行文件。

**理由**：产物简单（一个文件），易于嵌入 .app bundle，不需要管理 dist 目录结构。
**替代方案**：`--onedir` 模式产物更快启动（无需解压），但要管理整个目录树 → 先用 onefile，如果启动速度成为问题再切换。
**替代方案**：Nuitka 编译为原生代码 → 配置更复杂、编译时间长、收益不明显。

### 2. Bundle 路径: `Contents/Resources/engine/open-typeless`

嵌入位置为 `Contents/Resources/engine/open-typeless`。

**理由**：`Contents/Resources/` 是 macOS bundle 标准资源目录，子目录 `engine/` 隔离 Engine 文件，方便将来扩展（如加入配置文件）。
**查找方式**：`Bundle.main.resourceURL?.appendingPathComponent("engine/open-typeless")`

### 3. 构建脚本而非 Xcode Build Phase 自动构建

PyInstaller 打包耗时较长（30-60 秒），不适合每次 Xcode build 都跑。采用独立构建脚本 `scripts/build-engine.sh`，开发者手动执行。Xcode 只负责 Copy Files Phase 将已构建的 binary 复制到 bundle。

**构建流程**：
1. 开发者跑 `scripts/build-engine.sh` → 产出 `engine/dist/open-typeless`
2. Xcode Copy Files Phase 从 `engine/dist/open-typeless` 复制到 `Contents/Resources/engine/`
3. 如果 binary 不存在，Copy Phase 静默跳过（开发模式用 venv fallback 即可）

### 4. PyInstaller spec 文件

使用 `.spec` 文件（而非命令行参数）管理 PyInstaller 配置，便于维护 hidden imports 和排除规则。文件放在 `engine/open-typeless.spec`。

### 5. EngineProcessManager Priority 0

在现有 `resolveEngineBinary()` 的 Priority 1 之前插入 Priority 0：从 `Bundle.main.resourceURL/engine/open-typeless` 查找。只有当 bundled binary 存在且可执行时才使用，否则 fallthrough 到现有链。

**理由**：bundled binary 是用户最可能有的（安装即带），应最高优先级。custom path 用于高级用户覆盖。

## Risks / Trade-offs

- [PyInstaller onefile 启动慢] → 首次启动需要解压（约 1-3 秒），后续有缓存。可通过 `--onefile` 的 `--runtime-tmpdir` 指定缓存目录缓解。如果体验不可接受，切换到 `--onedir` 模式。
- [App 体积增大 50-80MB] → Python 运行时 + 依赖。桌面应用可接受（VSCode ~350MB、Cursor ~500MB）。
- [Hidden imports 可能遗漏] → Uvicorn 和 FastAPI 有动态 import。需要在 spec 文件中显式列出。测试时验证 `GET /health` 和 `POST /polish` 能正常工作。
- [arm64 only] → 当前仅构建 arm64。Intel Mac 用户需通过 Rosetta 2 运行或自行安装 Engine。后续可加 Universal Binary 支持。
- [Binary 不存在时 Copy Phase 不能硬失败] → 开发模式下不需要 bundled binary（venv fallback 够用），所以 Copy Phase 要容错。
