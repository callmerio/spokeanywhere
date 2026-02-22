# R2-2: 截图/图像增强链路主线程占用验证 - Interpretation

> 状态: **Conditional GO**
> 更新时间: 2026-02-23
> Commit: b0ba0c1f7186db77e29cb056ce390edca8d0c16c

---

## 执行摘要

**结论**: R2-2: Conditional GO — code-level fixes validated; runtime screenshot interaction evidence pending user pin action.

**已验证** ✅:
- Build gate: PASS (0 errors, 2.20s)
- Test gate: PASS (129/129 tests, 0.254s)
- Concurrency gate: PASS (0 warnings, 7.93s)
- Code fixes: 2 个运行时阻塞已修复并通过静态验证
- Script syntax: PASS

**待补证** ⏳:
- Runtime evidence: 需 1 次用户手动 pin 交互
- Log verification: `Screenshot created` 命中且 6 字段可解析（无 `<private>`）
- Coverage: `coverage_saveall=1`, `coverage_blur=1`

---

## 背景与目标

### 验证目标
验证截图/图像增强链路的主线程占用是否在可接受范围内，确保 UI 响应性不受影响。

### 关键指标
1. **capture_latency_ms**: 截图捕获延迟（基线 50-150ms）
2. **save_all_write_p95_ms**: saveAll 写入 P95 延迟（基线 1-10ms）
3. **blur_main_dispatch_p95_ms**: blur 主线程派发 P95 延迟（基线 1-5ms）
4. **enhancement_path**: 图像增强路径（none/basic/ai-fallback）
5. **coverage_saveall**: saveAll 路径覆盖标志（0/1）
6. **coverage_blur**: blur 路径覆盖标志（0/1）

### 告警阈值
- **P0 (critical)**: capture_latency_ms>500 OR save_all_write_p95_ms>50 OR blur_main_dispatch_p95_ms>20
- **P1 (warning)**: capture_latency_ms>300 OR save_all_write_p95_ms>30 OR blur_main_dispatch_p95_ms>10
- **P2 (attention)**: capture_latency_ms>200 OR save_all_write_p95_ms>20 OR blur_main_dispatch_p95_ms>8

---

## 三轮门禁复核过程

### 第一轮：初始验证（BLOCKED）
**发现问题**:
- 回归脚本执行返回 SKIP（无截图活动）
- 日志文件为空（仅表头）

**根因分析**:
- 脚本需要手动用户交互（触发截图 + 选择区域 + 点击 pin）
- 无法自动化完整截图确认流程

### 第二轮：运行时阻塞识别（2 个 High Priority）

**Blocker #1**: 脚本日志采集缺失 `--info` 标志
- **位置**: `screenshot-mainthread-test.sh:87-90`
- **现象**: `log show` 命令未捕获 info 级别事件，导致日志文件为空
- **证据**: codex-1 提供对照日志（无 --info vs 有 --info）
- **修复**: 添加 `--info` 标志到 log show 命令

**Blocker #2**: 指标日志显示 `<private>` 脱敏
- **位置**: `ScreenshotManager.swift:229-237`
- **现象**: 6 个指标字段被 macOS 统一日志系统脱敏，无法解析
- **证据**: codex-1 提供日志样本显示 `Screenshot created (mode: <private>): <private>`
- **修复**: 为所有 6 个指标插值添加 `privacy: .public` 注解

### 第三轮：V3 修复验证（Conditional GO）

**V3 Commit**: b0ba0c1f7186db77e29cb056ce390edca8d0c16c

**修复内容**:
1. `screenshot-mainthread-test.sh:89` - 添加 `--info` 标志
2. `ScreenshotManager.swift:231-236` - 添加 `privacy: .public` 到 6 个字段

**静态门禁验证** (claude-2):
- Build: ✅ PASS (2.20s, 0 errors)
- Test: ✅ PASS (129/129 tests, 0.254s)
- Concurrency: ✅ PASS (0 warnings, 7.93s)
- Script syntax: ✅ PASS

**运行时门禁验证** (codex-1, codex-2):
- 新进程验证: ✅ PID 85059（启动于 Mon Feb 23 06:05:14 2026，晚于 V3 commit）
- 脚本执行: ⚠️ SKIP（两次测试均无截图活动）
- 根本阻塞: 需要真实用户手动交互（触发截图 + 选择区域 + 点击 pin）

**门禁结论**:
- claude-2: GO (静态门禁)
- codex-1: Conditional GO（推荐）
- codex-2: Conditional GO（推荐）

---

## Conditional GO 转正条件

### Full GO 转正清单（一次性）

1. **用户交互**: 1 次用户手动 pin 截图交互
2. **日志验证**: `screenshot-log.txt` 命中 `Screenshot created`，且 6 字段可解析、无 `<private>`
3. **覆盖验证**:
   - `coverage_saveall=1`
   - `coverage_blur=1`（若 blur 不适用，需在报告注明原因与证据）

### 补证说明

**coverage_blur 特殊情况**:
- 若当前场景无 blur 触发条件（如未启用实时模糊功能），需在证据包中明确标注：
  - "not applicable" 状态
  - 触发前提说明
  - 日志证据支持
- 避免后续被误解为漏测

**证据包要求**:
- 新进程证明: `ps -p <PID> -o pid,lstart,command`（启动时间需晚于 b0ba0c1）
- 脚本包路径: `/tmp/spoke-screenshot-mainthread/<timestamp>`
- `SUMMARY.txt`: 状态非 SKIP
- `screenshot-log.txt`: 至少 1 条 `Screenshot created` 行
- Fixed output 6 值: 全部可读且符合预期范围

---

## 风险评估

### 低风险 ✅
- 代码修复正确且符合标准模式
- `--info` flag 是标准 log show 参数
- `privacy: .public` 是防止脱敏的正确方式
- 三门验证全部通过

### 中风险 ⚠️
- 缺少运行时实证
- 无法确认 log show 实际捕获 info 级别事件
- 无法确认 privacy 注解实际防止 `<private>` 脱敏
- 无法确认脚本 regex 正确解析指标

### 缓解措施
- 文档标注: "Runtime verification pending (user interaction required)"
- 后续补证: 用户手动测试后回传证据包
- 监控: 如生产环境发现问题，立即回滚

---

## 证据索引

### 静态门禁证据 (claude-2)
- Build: `/tmp/claude2-r2-2-v3-build.log`
- Test: `/tmp/claude2-r2-2-v3-test.log`
- Concurrency: `/tmp/claude2-r2-2-v3-concurrency.log`

### 运行时门禁证据 (codex-1)
- Build: `/tmp/r2-2-v3-codex1-build.log`
- Test: `/tmp/r2-2-v3-codex1-test.log`
- Concurrency: `/tmp/r2-2-v3-codex1-concurrency.log`
- Script: `/tmp/r2-2-v3-codex1-script.log`
- Package: `/tmp/r2-2-v3-codex1-script/20260223-060145/`

### 运行时门禁证据 (codex-2)
- Build: `/tmp/codex2-r2-2-v3-build.log`
- Test: `/tmp/codex2-r2-2-v3-test.log`
- Concurrency: `/tmp/codex2-r2-2-v3-concurrency.log`
- Script: `/tmp/codex2-r2-2-v3-script.log`
- Package: `/tmp/codex2-r2-2-v3-script/20260223-060101/`
- No-info comparison: `/tmp/codex2-r2-2-v3-noinfo-window.log`
- With-info comparison: `/tmp/codex2-r2-2-v3-withinfo-window.log`

### 测试包 (foreman)
- First run: `/tmp/spoke-screenshot-mainthread/20260223-060528/` (SKIP)
- Second run: `/tmp/spoke-screenshot-mainthread/20260223-061154/` (SKIP)

---

## 后续行动

### 立即行动
1. ✅ 更新 ROADMAP 标记 R2-2 Conditional GO 状态
2. ✅ Commit V3 fixes (b0ba0c1)
3. ⏳ 等待用户手动交互补证

### 转正后行动
1. 更新本文档状态为 Full GO
2. 归档完整证据包
3. 更新 ROADMAP 移除待补证标记

---

## 参考文档

- 回归脚本: `spoke/scripts/regression/screenshot-mainthread-test.sh`
- 核心代码: `spoke/Core/Screenshot/ScreenshotManager.swift`
- 模糊服务: `spoke/Services/ScreenCaptureBlurService.swift`
- 音频背压测试: `spoke/scripts/regression/audio-backpressure-test.sh` (参考模式)
