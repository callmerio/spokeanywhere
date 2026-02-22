# SpokenAnyWhere 质量与排障手册

本手册用于统一本地验证与 CI 质量门禁的执行方式，并提供失败时的标准排障路径。

## 1. 本地验证命令

### 1.1 本地可执行命令

在仓库根目录执行：

```bash
cd spoke
swift package resolve
swift build
swift test --parallel
./Tests/run-concurrency-check.sh
```

说明：

- `swift build`: 基础构建门禁，验证编译是否通过。
- `swift test --parallel`: 基础测试门禁，覆盖回归测试集。
- `./Tests/run-concurrency-check.sh`: 并发诊断入口，开启 `-warn-concurrency` 与 `-strict-concurrency=complete`。

### 1.2 CI 专属命令（本地不可执行）

以下命令因 macOS dyld 平台策略限制，仅能在 CI 环境执行：

```bash
# 本地执行会失败：Sanitizer load violates platform policy
cd spoke
swift test --sanitize=thread --parallel   # 线程竞态诊断
swift test --sanitize=address --parallel  # 内存访问诊断
```

**原因说明**：macOS SIP/Hardened Runtime 阻止本地开发环境加载 Sanitizer 动态库（`libclang_rt.tsan_osx_dynamic.dylib` / `libclang_rt.asan_osx_dynamic.dylib`），这是环境约束，非代码问题。CI 环境（GitHub Actions macos-14 runner）具备必要的签名与权限配置，可正常执行。

## 2. CI 与本地命令映射

### 2.1 本地可复现的 CI 门禁

- `test.yml / build-gate` -> `cd spoke && swift build`
- `test.yml / test-gate` -> `cd spoke && swift test --parallel`
- `test.yml / concurrency-gate` -> `cd spoke && ./Tests/run-concurrency-check.sh`

### 2.2 CI 专属门禁（本地不可复现）

- `sanitizer.yml / sanitizer-thread` -> `cd spoke && swift test --sanitize=thread --parallel` (CI-only)
- `sanitizer.yml / sanitizer-address` -> `cd spoke && swift test --sanitize=address --parallel` (CI-only)
- `release.yml / pre-release-sanitizer` -> 复用 `sanitizer.yml`（发布前强制，CI-only）
- `release.yml / build` -> `cd spoke && swift build -c release`

### 2.3 策略说明

- **本地验证**：开发者在提交前执行 build + test + concurrency-check 三项本地门禁。
- **CI 专属验证**：Sanitizer 门禁仅在 CI 环境执行，因本地环境受 macOS dyld 平台策略限制。
- **发布流程**：`release.yml` 在构建发布产物前强依赖 `pre-release-sanitizer`，确保 Sanitizer 通过后才允许发布。
- **定时检查**：`sanitizer.yml` 提供夜间定时（nightly UTC 3:00）与手动触发（workflow_dispatch），用于持续监控内存与线程安全。

## 3. 标准排障流程

### 3.1 Build 失败（`swift build`）

1. 先看 CI 的 `build-logs` artifact 或 `ci-logs/build.log` 尾部 200 行。
2. 若是依赖解析问题，执行 `cd spoke && swift package resolve` 后重试。
3. 若是类型错误，按首个报错文件优先修复，避免连锁噪声。
4. 本地复现通过后，再推送触发 CI。

### 3.2 Test 失败（`swift test --parallel`）

1. 查看 CI 的 `test-logs` artifact 或 `ci-logs/test.log`。
2. 先单测最小复现，再回到 `--parallel` 验证是否有并发不稳定。
3. 若失败与共享状态相关，参考 `spoke/Tests/TEST_ISOLATION.md` 检查隔离策略。

### 3.3 Concurrency 失败（`run-concurrency-check.sh`）

1. 关注 `-warn-concurrency` 的首个高优先级告警，按调用链回溯到共享状态入口。
2. 优先收敛隔离边界：`@MainActor`、actor 封装、生命周期归属。
3. 修复后至少重复执行两次并发检查，确认无随机波动。

### 3.4 Sanitizer 失败（Thread/Address，CI-only）

**重要提示**：Sanitizer 门禁仅在 CI 环境执行，本地无法复现（受 macOS dyld 平台策略限制）。

**排障流程**：

1. **查看 CI 日志**：下载 CI artifact（`sanitizer-thread-logs` / `sanitizer-address-logs`）或查看 workflow 输出。
2. **线程 Sanitizer 失败**：优先检查共享可变状态、回调跨线程读写、异步生命周期竞态。
3. **Address Sanitizer 失败**：优先检查越界访问、悬垂引用、对象释放后访问。
4. **修复验证**：提交修复后，通过 CI 重新验证（本地无法直接测试 Sanitizer）。
5. **发布阻塞**：若 `release.yml / pre-release-sanitizer` 失败，必须先修复并通过 Sanitizer 门禁，才允许继续发布。

**本地替代验证**：虽然无法运行 Sanitizer，但可通过以下方式提前发现潜在问题：
- 执行 `./Tests/run-concurrency-check.sh` 检查并发隔离问题。
- 执行 `swift test --parallel` 多次，观察是否有随机失败（可能暗示竞态）。
- Code Review 时重点关注共享状态、异步回调、生命周期管理。

## 4. 提交前最小检查清单

### 4.1 本地必执行项

- `cd spoke && swift build`
- `cd spoke && swift test --parallel`

### 4.2 本地条件执行项

- 涉及并发变更时执行：`cd spoke && ./Tests/run-concurrency-check.sh`

### 4.3 CI 自动执行项（本地不可执行）

- Thread Sanitizer：`sanitizer.yml / sanitizer-thread`（夜间定时 + 发布前强制）
- Address Sanitizer：`sanitizer.yml / sanitizer-address`（夜间定时 + 发布前强制）

**说明**：Sanitizer 门禁因环境约束仅在 CI 执行，开发者无需本地运行。CI 会在夜间定时检查与发布前强制验证。

