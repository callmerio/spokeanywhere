---
description: Conductor 状态查看 - 显示项目进度概览
---

# Conductor Status

显示当前项目的任务进度概览。

## 执行协议

**读取并执行以下系统指令：**

1. **读取源 Prompt**: 读取 `/Users/bigdan/prompt/vendor/conductor/commands/conductor/status.toml` 文件
2. **执行 Prompt**: 按照 TOML 文件中 `prompt = """..."""` 的指令执行

## 用法

```bash
/conductor-status
```

## 输出内容

- **当前日期/时间**
- **项目状态**: On Track / Behind Schedule / Blocked
- **当前阶段和任务**: 正在进行的 Phase 和 Task
- **下一步行动**: 下一个待执行的任务
- **阻塞项**: 标记为 Blocker 的任务
- **进度统计**: `已完成/总任务数 (百分比)`

## 前置条件

- 必须先运行 `/conductor-setup`
- `conductor/tracks.md` 必须存在且非空
