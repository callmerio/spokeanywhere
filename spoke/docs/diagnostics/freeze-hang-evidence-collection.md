# Freeze/Hang 证据采集指南

**版本**: 1.0
**更新时间**: 2026-02-23
**适用范围**: SpokenAnyWhere 启动卡死、运行时卡顿诊断

---

## 1. 快速使用

### 1.1 一键采集

```bash
cd spoke
./scripts/diagnostics/collect-freeze-evidence.sh
```

**输出**: `/tmp/spoke-freeze-evidence/YYYYMMDD-HHMMSS/`

### 1.2 自定义输出目录

```bash
EVIDENCE_DIR=/path/to/custom/dir ./scripts/diagnostics/collect-freeze-evidence.sh
```

---

## 2. 证据包结构

```
/tmp/spoke-freeze-evidence/20260223-153045/
├── SUMMARY.txt              # 证据摘要（优先查看）
├── system-info.txt          # 系统信息
├── process-info.txt         # 进程状态
├── thread-info.txt          # 线程信息
├── open-files.txt           # 打开的文件描述符
├── sample.txt               # 5秒采样（关键）
├── spindump.txt             # 堆栈快照（需 sudo）
├── system-log.txt           # 系统日志（最近 5 分钟）
├── launch-log.txt           # 启动日志（最近 10 分钟）
├── resource-usage.txt       # CPU/内存/磁盘使用情况
├── audio-devices.txt        # 音频设备状态
├── permissions.txt          # TCC 权限状态
├── dev-*.log                # 开发日志（如果存在）
└── SpokenAnyWhere*.crash    # 崩溃报告（如果有）
```

---

## 3. 证据分析流程

### 3.1 第一步：查看摘要

```bash
cat /tmp/spoke-freeze-evidence/20260223-153045/SUMMARY.txt
```

**关键信息**:
- 进程是否运行
- 采样是否成功
- 快速状态检查

### 3.2 第二步：分析采样

```bash
open /tmp/spoke-freeze-evidence/20260223-153045/sample.txt
```

**查找关键词**:
- `Main Thread` - 主线程在做什么
- `Blocked` - 是否有线程阻塞
- `Waiting` - 等待什么资源
- `AudioQueue` - 音频队列状态
- `ScreenCaptureKit` - 截图服务状态

**常见模式**:

#### 模式 1: 主线程阻塞
```
Main Thread:
  + ! : 1000 samples (100%)
  + !   1000 __semwait_signal + 10
  + !     1000 _pthread_cond_wait + 1234
```
**判定**: 主线程在等待条件变量，可能是同步操作阻塞

#### 模式 2: 音频回调卡死
```
AudioQueue Thread:
  + ! : 1000 samples (100%)
  + !   1000 AudioRecorderService.processBuffer + 456
```
**判定**: 音频回调处理过慢，可能是缓冲区积压

#### 模式 3: 截图服务卡顿
```
ScreenCaptureKit Thread:
  + ! : 1000 samples (100%)
  + !   1000 SCStreamOutput.didOutputSampleBuffer + 789
```
**判定**: 截图回调处理过慢，可能是主线程占用

### 3.3 第三步：检查启动日志

```bash
grep -E "Step.*\[" /tmp/spoke-freeze-evidence/20260223-153045/launch-log.txt
```

**正常范围**: 参考 `startup-log-interpretation.md` 第 2.1 节

**异常示例**:
```
Step 4: RecordingController [2500ms]  ⚠️ 异常慢
```

### 3.4 第四步：检查资源使用

```bash
cat /tmp/spoke-freeze-evidence/20260223-153045/resource-usage.txt
```

**关注指标**:
- CPU 使用率 >200%（多核）
- 内存使用 >1GB
- 磁盘空间不足
- 内存压力（Memory Pressure）

### 3.5 第五步：检查权限

```bash
cat /tmp/spoke-freeze-evidence/20260223-153045/permissions.txt
```

**必需权限**:
- Microphone: 允许
- Screen Recording: 允许
- Accessibility: 允许

---

## 4. 常见问题诊断

### 4.1 启动卡死

**症状**: 应用启动后无响应，菜单栏图标不出现

**诊断步骤**:
1. 查看 `launch-log.txt`，找到卡在哪个步骤
2. 查看 `sample.txt`，确认主线程在做什么
3. 查看 `permissions.txt`，确认权限是否缺失

**常见原因**:
- Step 4 (RecordingController) 级联初始化过慢
- 音频设备初始化失败
- 权限弹窗未响应

### 4.2 运行时卡顿

**症状**: 应用运行中突然卡顿，UI 无响应

**诊断步骤**:
1. 查看 `sample.txt`，确认主线程是否阻塞
2. 查看 `thread-info.txt`，检查线程数量是否异常
3. 查看 `resource-usage.txt`，检查资源是否耗尽

**常见原因**:
- 主线程执行耗时操作（音频处理、图像处理）
- 线程死锁或资源竞争
- 内存不足触发系统降级

### 4.3 音频录制失败

**症状**: 点击录音按钮无反应，或录音中断

**诊断步骤**:
1. 查看 `audio-devices.txt`，确认音频设备状态
2. 查看 `system-log.txt`，搜索 `AudioRecorder` 或 `AVAudioEngine`
3. 查看 `permissions.txt`，确认麦克风权限

**常见原因**:
- 音频设备被其他应用占用
- 麦克风权限未授予
- 音频引擎初始化失败

### 4.4 截图功能异常

**症状**: 截图卡顿、截图失败、截图窗口无响应

**诊断步骤**:
1. 查看 `sample.txt`，搜索 `ScreenCaptureKit` 或 `Screenshot`
2. 查看 `permissions.txt`，确认屏幕录制权限
3. 查看 `system-log.txt`，搜索 `Screenshot` 或 `SCStream`

**常见原因**:
- 屏幕录制权限未授予
- 截图回调在主线程执行过慢
- 截图窗口数量过多（内存不足）

---

## 5. 高级诊断

### 5.1 使用 spindump（需 sudo）

```bash
sudo spindump $(pgrep SpokenAnyWhere) -file /tmp/spindump.txt
```

**优势**: 比 sample 更详细，包含系统调用信息

### 5.2 使用 Instruments

```bash
# 启动 Time Profiler
open -a Instruments

# 选择 Time Profiler 模板
# Attach 到 SpokenAnyWhere 进程
# 录制 10-30 秒
```

**适用场景**: 需要精确定位性能瓶颈

### 5.3 使用 lldb

```bash
# Attach 到进程
lldb -p $(pgrep SpokenAnyWhere)

# 打印所有线程堆栈
(lldb) thread backtrace all

# 继续执行
(lldb) continue
```

**适用场景**: 需要实时调试或修改状态

---

## 6. 证据提交

### 6.1 内部排查

将证据包发送给开发团队：
```bash
# 打包
tar -czf spoke-freeze-evidence.tar.gz /tmp/spoke-freeze-evidence/20260223-153045/

# 上传到内部存储或附加到 issue
```

### 6.2 用户反馈

如果需要用户提供证据：
1. 提供脚本下载链接
2. 指导用户运行脚本
3. 要求用户提供 `SUMMARY.txt` 和 `sample.txt`

**隐私注意**:
- 证据包可能包含敏感信息（文件路径、进程列表）
- 提醒用户检查后再提交

---

## 7. 自动化采集（可选）

### 7.1 启动时自动采集

在 `AppDelegate.swift` 中添加：
```swift
if ProcessInfo.processInfo.environment["SPOKE_AUTO_COLLECT_EVIDENCE"] == "1" {
    Task.detached {
        try? await Task.sleep(for: .seconds(10))
        let script = Bundle.main.path(forResource: "collect-freeze-evidence", ofType: "sh")
        Process.launchedProcess(launchPath: "/bin/bash", arguments: [script!])
    }
}
```

### 7.2 定时采集

使用 launchd 定时任务：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.spokeanywhere.evidence-collector</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/collect-freeze-evidence.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer> <!-- 每小时 -->
</dict>
</plist>
```

---

## 8. 相关文档

- [启动日志判读规则](./startup-log-interpretation.md)
- [启动序列分析](../architecture/app-layer-startup-sequence.md)
- [启动风险评估](../architecture/app-layer-risk-assessment.md)

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-02-23
