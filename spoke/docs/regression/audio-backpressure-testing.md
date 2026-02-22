# 音频背压回归测试

**版本**: 1.0
**更新时间**: 2026-02-23
**适用范围**: SpokenAnyWhere 音频链路稳态验证

---

## 1. 测试目标

验证音频链路在引擎准备延迟场景下的背压管理能力，确保：
- 缓冲区不会无限增长导致内存溢出
- 丢帧策略正确执行，保持系统稳定
- 崩溃恢复写入不会造成额外背压
- 引擎准备延迟在可接受范围内

---

## 2. 测试脚本

### 2.1 脚本位置

```
spoke/scripts/regression/audio-backpressure-test.sh
```

### 2.2 使用方法

```bash
# 基础用法（默认 30 秒测试）
cd spoke
./scripts/regression/audio-backpressure-test.sh

# 自定义测试时长
TEST_DURATION=60 ./scripts/regression/audio-backpressure-test.sh

# 自定义输出目录
OUTPUT_DIR=/tmp/my-test ./scripts/regression/audio-backpressure-test.sh
```

### 2.3 前置条件

- SpokenAnyWhere 应用已启动
- 应用已获得麦克风权限
- 测试期间需进行录音操作（触发引擎准备流程）

---

## 3. 固定输出指标

脚本输出以下固定指标（机器可读格式 \`key=value\`）：

| 指标 | 说明 | 单位 |
|------|------|------|
| \`backlog_depth\` | 引擎准备前缓冲区峰值 | chunks |
| \`drop_rate\` | 丢帧率 = drops / (peak + drops) * 100 | % |
| \`p95_latency_ms\` | 引擎准备延迟（当前为单次测量） | ms |
| \`recovery_write_drops\` | 崩溃恢复写入丢弃次数 | count |

---

## 4. 基线与阈值

### 4.1 正常基线

```
backlog_depth: 10-50
drop_rate: 0%
p95_latency_ms: 1000-2000
recovery_write_drops: 0
```

### 4.2 告警阈值

| 级别 | 条件 | 说明 |
|------|------|------|
| **P0 (Critical)** | \`backlog_depth >= 128\` OR \`drop_rate > 0\` OR \`p95_latency_ms > 10000\` | 严重背压，阻塞发布 |
| **P1 (Warning)** | \`backlog_depth > 100\` OR \`p95_latency_ms > 5000\` | 背压升高，需关注 |
| **P2 (Attention)** | \`backlog_depth > 50\` OR \`p95_latency_ms > 3000\` | 轻度背压，建议优化 |

---

## 5. 状态判定

脚本根据指标自动判定状态：

| 状态 | 退出码 | 说明 |
|------|--------|------|
| \`PASS\` | 0 | 所有指标在正常范围内 |
| \`WARN\` | 0 | 触发 P1/P2 告警，但不阻塞 |
| \`FAIL\` | 1 | 触发 P0 告警，阻塞发布 |
| \`SKIP\` | 2 | 未检测到录音活动 |

---

## 6. 测试包结构

脚本生成测试包目录：\`/tmp/spoke-audio-backpressure/<timestamp>/\`

```
<timestamp>/
├── baseline.txt           # 基线信息（进程、时间）
├── audio-log.txt          # 音频子系统日志（30秒）
├── sample.txt             # 性能采样（sample 工具）
├── resource-usage.txt     # 资源使用监控（CPU/内存）
├── analysis.txt           # 指标分析（缓冲区/引擎/错误）
└── SUMMARY.txt            # 测试摘要（固定输出指标 + 状态）
```

---

## 7. 诊断计数器

### 7.1 计数器定义

脚本依赖 \`AudioRecorderService.swift\` 中的诊断计数器：

```swift
private var preReadyBufferPeak: Int = 0          // 引擎准备前缓冲区峰值
private var preReadyDropCount: Int = 0           // 引擎准备前丢帧次数
private var recoveryWriteDropCount: Int = 0      // 崩溃恢复写入丢弃次数
private var enginePrepareStartTime: CFAbsoluteTime = 0  // 引擎准备开始时间
```

### 7.2 日志格式

引擎准备完成时输出：

```
✅ Engine ready, sending X buffered chunks [prepare: Yms, peak: Z, drops: W, recovery_drops: V]
```

脚本通过正则提取这些指标。

---

## 8. CI 集成

### 8.1 集成示例

```yaml
- name: Audio Backpressure Regression
  run: |
    # 启动应用（后台）
    ./spoke/dev.sh &
    APP_PID=$!
    sleep 5  # 等待启动

    # 运行回归测试
    cd spoke
    ./scripts/regression/audio-backpressure-test.sh

    # 清理
    kill $APP_PID
```

### 8.2 结果解析

CI 可通过退出码判断：
- \`0\`: 通过或警告（不阻塞）
- \`1\`: 失败（阻塞发布）
- \`2\`: 跳过（未录音）

---

## 9. 故障排查

### 9.1 常见问题

**Q: 测试显示 SKIP（未检测到录音活动）**
A: 测试期间需手动触发录音（快捷键或菜单），确保引擎准备流程被触发。

**Q: backlog_depth 异常高（>100）**
A: 检查引擎准备延迟（p95_latency_ms），可能是 LLM API 响应慢或系统资源不足。

**Q: drop_rate > 0**
A: 缓冲区溢出，检查 \`AUDIO_BUFFER_SIZE\` 配置或引擎准备性能。

**Q: recovery_write_drops > 0**
A: 崩溃恢复写入槽位已满，检查恢复写入频率和缓冲区管理。

### 9.2 深度诊断

查看测试包中的详细日志：

```bash
# 查看分析结果
cat /tmp/spoke-audio-backpressure/<timestamp>/analysis.txt

# 查看音频日志
cat /tmp/spoke-audio-backpressure/<timestamp>/audio-log.txt

# 查看性能采样
open /tmp/spoke-audio-backpressure/<timestamp>/sample.txt
```

---

## 10. 相关文档

- [AudioRecorderService 实现](../../Core/Audio/AudioRecorderService.swift)
- [启动日志判读规则](../diagnostics/startup-log-interpretation.md)
- [Freeze/Hang 证据采集](../diagnostics/freeze-hang-evidence-collection.md)
- [ROADMAP R2: P0 路径稳态化](../../ROADMAP.md)

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-02-23
