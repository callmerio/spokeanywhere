# 启动性能基准与回归门禁

本文档定义 SpokenAnyWhere 启动性能的自动化验证流程，目标是把“体感卡顿”转为可复算的数字门禁。

## 1. 产物

- 基准脚本：`scripts/perf/run_startup_bench.sh`
- 门禁脚本：`scripts/perf/check_startup_regression.sh`
- 基线配置：`perf/baseline-startup.json`
- 默认报告：`docs/perf-startup-report.json`

## 2. 采集指标

脚本采集以下指标（按 item_count 分组）：

- `launch_total_ms`: 启动到 `applicationDidFinishLaunching` 完成耗时
- `restore_decode_ms`: 截图恢复中的读盘+JSON 解码耗时
- `restore_ui_ms`: 截图恢复中的 UI 重建耗时
- `restored_count`: 实际恢复数量是否与夹具一致

每组输出 `samples / p50 / p95 / max / mean`。

## 3. 运行基准

在仓库根目录执行：

```bash
cd spoke
chmod +x scripts/perf/run_startup_bench.sh scripts/perf/check_startup_regression.sh
scripts/perf/run_startup_bench.sh
```

可选参数（环境变量）：

```bash
RUNS=20 ITEM_COUNTS="10 20 50" TIMEOUT_SECONDS=25 BUILD_CONFIG=release \
  scripts/perf/run_startup_bench.sh
```

## 4. 回归门禁

使用基准报告与基线阈值进行比较：

```bash
cd spoke
scripts/perf/check_startup_regression.sh \
  docs/perf-startup-report.json \
  perf/baseline-startup.json
```

门禁失败时会列出具体超阈值项（例如 `launch_total_ms.p95`）。

## 5. 实施说明

- 当前脚本通过 `SPOKE_SCREENSHOT_BASE_DIR` 指向隔离目录构造截图夹具，不污染真实用户数据。
- 基线阈值是初始值，建议在稳定环境（固定机型、固定系统负载）跑 3 轮后再收紧。
- `restoreAll()` 含 UI 重建，CI 结果可能受运行环境影响；建议把该门禁先设为手动触发或 nightly。
