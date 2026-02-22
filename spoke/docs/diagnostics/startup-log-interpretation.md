# 启动日志判读规则

**版本**: 1.0
**更新时间**: 2026-02-23
**适用范围**: SpokenAnyWhere 启动诊断

---

## 1. 启动日志开关

### 1.1 启用方式

**方式一：环境变量（推荐用于临时诊断）**
```bash
SPOKE_STARTUP_LOG=1 ./spoke/build/SpokenAnyWhere.app/Contents/MacOS/SpokenAnyWhere
```

**方式二：AppSettings 开关（推荐用于持续观测）**
- 打开设置 → 高级 → 启动诊断日志
- 重启应用生效

### 1.2 日志输出位置

- **Console.app**: 筛选 `subsystem:com.spokeanywhere category:Launch`
- **开发模式**: `.tmp_frames/dev-*.log`

---

## 2. 正常启动基线

### 2.1 时间基线（参考值）

```
Step 0: CrashLogger                    [0-5ms]
Step 1: Accessibility Permission       [5-20ms]
Step 2: Menu Bar Setup                 [20-40ms]
Step 3: Clipboard Service              [40-60ms]
Step 4: RecordingController            [60-150ms]  ⚠️ 级联初始化
Step 5: HistoryManager Config          [150-160ms]
Step 6: History Cleanup (async)        [160-165ms]
Step 6.1: Orphan Cleanup (async)       [165-170ms]
Step 6.5: Dictionary Precompile (bg)   [170-175ms]
Step 6.6: Speech Engine Warmup (bg)    [175-180ms]
Step 7: Trackpad Gesture               [180-190ms]
Step 8: Resource Monitor               [190-200ms]
Step 9: Selection Toolbar              [200-210ms]
Step 10: Screenshot Service            [210-220ms]
Step 11: Dictionary Panel              [220-230ms]
Step 12: Launch Complete               [~230ms]
```

**正常范围**: 200-300ms（同步路径）
**警戒阈值**: >500ms
**异常阈值**: >1000ms

### 2.2 步骤依赖关系

```
Step 0-2: 基础设施（必须同步完成）
Step 3-5: 核心服务（RecordingController 触发级联初始化）
Step 6-6.6: 数据维护与预热（异步，不阻塞启动）
Step 7-11: 功能服务（同步，但轻量）
```

---

## 3. 环境噪音 vs 功能性故障

### 3.1 环境噪音（可忽略）

#### 3.1.1 CMIO 插件错误
```
CMIO_DAL_PlugIn_PropertyChangedBlock ... kCMIODevicePropertyDeviceIsRunningSomewhere
```
**判定**: 环境噪音
**原因**: macOS 系统级摄像头插件状态查询，不影响录音功能
**处理**: 无需处理

#### 3.1.2 CoreAudio -10877
```
[aqme] 255: AQDefaultDevice (173): skipping input stream 0 0 0x0
```
**判定**: 环境噪音
**原因**: CoreAudio 内部设备枚举，不影响音频捕获
**处理**: 无需处理

#### 3.1.3 SwiftUI 性能警告（已修复）
```
onChange(of: String) action tried to update multiple times per frame
```
**判定**: 已修复（N044-N045 FloatingCapsuleView debounce patch）
**原因**: 历史遗留问题，当前版本已解决
**处理**: 如果仍出现，检查是否为旧版本

### 3.2 功能性故障（需处理）

#### 3.2.1 权限缺失
```
⚠️ Accessibility permission required for global hotkeys
⚠️ Microphone permission denied
⚠️ Screen Recording permission denied
```
**判定**: 功能性故障
**影响**: 核心功能不可用
**处理**: 引导用户授权（系统设置 → 隐私与安全性）

#### 3.2.2 服务启动失败
```
❌ Failed to start RecordingController: ...
❌ AudioRecorderService initialization failed: ...
```
**判定**: 功能性故障
**影响**: 录音功能不可用
**处理**: 检查音频设备、权限、系统资源

#### 3.2.3 数据库初始化失败
```
❌ Failed to create ModelContainer: ...
```
**判定**: 功能性故障
**影响**: 历史记录、设置无法持久化
**处理**: 检查磁盘空间、文件权限、数据库文件完整性

#### 3.2.4 启动超时
```
Step 4: RecordingController [2500ms]  ⚠️ 异常慢
```
**判定**: 性能异常
**影响**: 启动体验差，可能存在资源竞争
**处理**:
1. 检查是否有其他应用占用音频设备
2. 检查系统资源（CPU/内存）
3. 收集 freeze/hang 证据包（见第 4 节）

---

## 4. 故障分类决策树

```
启动日志异常
│
├─ 有 ❌ 错误标记？
│   ├─ Yes → 功能性故障 → 按错误类型处理
│   └─ No → 继续判断
│
├─ 有 ⚠️ 警告标记？
│   ├─ Permission 相关 → 功能性故障
│   ├─ CMIO/CoreAudio → 环境噪音
│   └─ 其他 → 需人工判断
│
├─ 启动时间 >1000ms？
│   ├─ Yes → 性能异常 → 收集 freeze/hang 证据
│   └─ No → 继续判断
│
└─ 功能验证失败？
    ├─ Yes → 功能性故障 → 深度诊断
    └─ No → 正常启动
```

---

## 5. 快速判读检查清单

### 5.1 一分钟快速检查

```bash
# 1. 提取启动总时间
grep "Step 12: Application launch complete" dev-*.log

# 2. 检查是否有错误
grep -E "❌|Failed|Error" dev-*.log

# 3. 检查权限警告
grep -E "permission|Permission" dev-*.log

# 4. 检查异常慢的步骤（>500ms）
grep -E "Step.*\[[5-9][0-9]{2,}ms\]" dev-*.log
```

### 5.2 判读结论模板

**正常启动**:
```
✅ 启动总时间: 230ms
✅ 无功能性错误
✅ 无权限缺失
✅ 无异常慢步骤
⚠️ 环境噪音: CMIO/CoreAudio（可忽略）
```

**异常启动**:
```
❌ 启动总时间: 1200ms（超出正常范围）
❌ Step 4 异常慢: 950ms（正常 <150ms）
⚠️ 建议: 收集 freeze/hang 证据包
```

---

## 6. 相关文档

- [Freeze/Hang 证据采集](./freeze-hang-evidence-collection.md)
- [启动序列分析](../architecture/app-layer-startup-sequence.md)
- [启动风险评估](../architecture/app-layer-risk-assessment.md)

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-02-23
