# SpokenAnyWhere 质量与排障手册

本手册用于统一本地验证与 CI 质量门禁的执行方式，并提供失败时的标准排障路径。

## 1. 本地验证命令

在仓库根目录执行：

```bash
cd spoke
swift package resolve
swift build
swift test --parallel
./Tests/run-concurrency-check.sh
swift test --sanitize=thread --parallel
swift test --sanitize=address --parallel
```

说明：

- `swift build`: 基础构建门禁，验证编译是否通过。
- `swift test --parallel`: 基础测试门禁，覆盖回归测试集。
- `./Tests/run-concurrency-check.sh`: 并发诊断入口，开启 `-warn-concurrency` 与 `-strict-concurrency=complete`。
- `swift test --sanitize=thread --parallel`: 线程竞态诊断。
- `swift test --sanitize=address --parallel`: 内存访问诊断。

## 2. CI 与本地命令映射

- `test.yml / build-gate` -> `cd spoke && swift build`
- `test.yml / test-gate` -> `cd spoke && swift test --parallel`
- `sanitizer.yml / sanitizer-thread` -> `cd spoke && swift test --sanitize=thread --parallel`
- `sanitizer.yml / sanitizer-address` -> `cd spoke && swift test --sanitize=address --parallel`
- `release.yml / pre-release-sanitizer` -> 复用 `sanitizer.yml`（发布前强制）
- `release.yml / build` -> `cd spoke && swift build -c release`

策略说明：

- `sanitizer.yml` 提供夜间定时（nightly）与手动触发（workflow_dispatch）。
- `release.yml` 在构建发布产物前，强依赖 `pre-release-sanitizer`，因此 Sanitizer 是发布前必跑项。

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

### 3.4 Sanitizer 失败（Thread/Address）

1. 在线程 Sanitizer 失败时，优先检查共享可变状态、回调跨线程读写、异步生命周期竞态。
2. 在 Address Sanitizer 失败时，优先检查越界访问、悬垂引用、对象释放后访问。
3. 先在本地用同一命令复现，再提交修复。
4. 若发生发布流程失败，必须先让 `pre-release-sanitizer` 通过，才允许继续发布。

## 4. 提交前最小检查清单

- `cd spoke && swift build`
- `cd spoke && swift test --parallel`
- 涉及并发变更时执行：`cd spoke && ./Tests/run-concurrency-check.sh`
- 涉及高风险链路或发布前执行：`cd spoke && swift test --sanitize=thread --parallel` 与 `cd spoke && swift test --sanitize=address --parallel`

