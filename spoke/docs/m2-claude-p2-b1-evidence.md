# M2 P2-B1 AttachmentManager 收敛 - 中间证据包

**执行时间**: 2026-02-22
**执行者**: claude-1
**批次**: P2-B1 (AttachmentManager SendableClosureCaptures)

---

## 1. 目标站点验证 (2/2 清除)

### 原始 2 个告警站点
1. `Core/Attachment/AttachmentManager.swift:99`
2. `Core/Attachment/AttachmentManager.swift:115`

### Before 统计
```bash
# 从 docs/m2-claude-p2-b1.log (初始构建)
grep -n "AttachmentManager.swift:99\|AttachmentManager.swift:115" docs/m2-claude-p2-b1.log
```
**结果**: 2 raw / 2 uniq (lines 99, 115)

### After 统计
```bash
# 从 docs/m2-claude-p2-b1.log (修复后构建)
grep -n "AttachmentManager.swift:99\|AttachmentManager.swift:115" docs/m2-claude-p2-b1.log
```
**结果**: 0 raw / 0 uniq ✅

---

## 2. 技术方案

### 根因分析
- Lines 99, 115 在 `handleDrop` 方法中捕获 `onAdd` 闭包跨越隔离边界
- `onAdd` 参数类型为 `@escaping (Attachment) -> Void`，但在 `Task { @MainActor in }` 中被捕获
- Swift 6 strict concurrency 要求跨隔离边界的闭包必须是 `@Sendable`

### 解决方案
**类型签名传播策略**：将 `onAdd` 参数类型统一改为 `@MainActor @Sendable`

#### 修改范围
**AttachmentManager.swift** (12 个方法签名):
```swift
// Before
func handleDrop(providers: [NSItemProvider], onAdd: @escaping (Attachment) -> Void)

// After
func handleDrop(providers: [NSItemProvider], onAdd: @escaping @MainActor @Sendable (Attachment) -> Void)
```

修改的方法:
1. `handleDrop(providers:onAdd:)` - line 67
2. `handleFileURL(_:source:onAdd:)` - line 124
3. `addImage(_:source:onAdd:)` - line 175
4. `addScreenshot(_:onAdd:)` - line 203
5. `addFile(_:onAdd:)` - line 210
6. `handleFolder(_:onAdd:)` - line 218
7. `handleZIP(_:onAdd:)` - line 256
8. `pickFiles(onAdd:)` - line 286
9. `pickFolder(onAdd:)` - line 303
10. `pickZIP(onAdd:)` - line 318
11. `captureScreen(onAdd:)` - line 336
12. `pickFromPhotos(onAdd:)` - line 347

**UI/Components/AttachmentDropOverlay.swift** (2 处):
```swift
// Line 58: struct property
let onAdd: @MainActor @Sendable (Attachment) -> Void

// Line 97: extension method parameter
func attachmentDropHandler(
    cornerRadius: CGFloat = 16,
    onAdd: @escaping @MainActor @Sendable (Attachment) -> Void
) -> some View
```

**UI/Components/AttachmentPickerMenu.swift** (1 处):
```swift
// Line 13: struct property
let onAdd: @MainActor @Sendable (Attachment) -> Void
```

---

## 3. 构建验证

### 命令
```bash
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke
swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
```

### 结果
```
Build complete! (10.08s)
EXIT: 0
```

### 并发告警统计
- **AttachmentManager.swift:99**: 0 个 ✅
- **AttachmentManager.swift:115**: 0 个 ✅
- **ImageEnhancementService.swift:224**: 1 个 (P2-B2 范围，保持不变) ✅
- **P1 kAX 4 位点**: 0 个 (验证保持不变) ✅

**日志**: `docs/m2-claude-p2-b1.log`

---

## 4. P1 站点保持验证

### 命令
```bash
grep -rn "kAXTrustedCheckOptionPrompt" \
  Services/SelectionMonitorService.swift \
  Services/InputService.swift \
  Services/TrackpadSwipeService.swift \
  App/AppDelegate.swift
```

### 结果
```
(无输出 - 4 个站点均保持清除状态)
```

**统计**: P1 4 站点 → 0 raw / 0 uniq ✅

---

## 5. P2-B2 站点保持验证

### 命令
```bash
grep -n "ImageEnhancementService.swift:224" docs/m2-claude-p2-b1.log
```

### 结果
```
113:/Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke/Services/ImageEnhancementService.swift:224:23: warning: passing closure as a 'sending' parameter risks causing data races between main actor-isolated code and concurrent execution of the closure; this is an error in the Swift 6 language mode
```

**统计**: ImageEnhancementService.swift:224 → 1 raw / 1 uniq (保持不变) ✅

---

## 6. 技术决策记录

### 为何使用类型签名传播？
AttachmentManager 的 `onAdd` 回调在多个异步上下文中被捕获（Task、后台线程），必须确保类型安全。通过在方法签名中声明 `@MainActor @Sendable`，编译器可以在调用点强制检查闭包的并发安全性。

### 为何同时修改 UI 组件？
UI 组件（AttachmentDropOverlay、AttachmentPickerMenu）是 AttachmentManager 的调用方，它们的 `onAdd` 属性类型必须与 AttachmentManager 的参数类型匹配。类型签名变更会传播到所有调用链。

### 业务行为影响
- ✅ **零业务逻辑变更**：仅修改类型签名，不改变执行逻辑
- ✅ **向后兼容**：所有现有调用点的闭包已经在 `@MainActor` 上下文中执行
- ✅ **类型安全增强**：编译器现在可以静态验证并发安全性

---

## 7. 可复现命令集

```bash
# 1. 验证 P2-B1 目标站点清除
cd /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere/spoke
grep -n "AttachmentManager.swift:99\|AttachmentManager.swift:115" docs/m2-claude-p2-b1.log
# 预期: 无输出

# 2. 验证 P1 站点保持清除
grep -rn "kAXTrustedCheckOptionPrompt" \
  Services/SelectionMonitorService.swift \
  Services/InputService.swift \
  Services/TrackpadSwipeService.swift \
  App/AppDelegate.swift
# 预期: 无输出

# 3. 验证 P2-B2 站点保持不变
grep -n "ImageEnhancementService.swift:224" docs/m2-claude-p2-b1.log
# 预期: 1 个命中

# 4. 严格并发构建
swift build -Xswiftc -warn-concurrency -Xswiftc -strict-concurrency=complete
# 预期: Build complete! (EXIT 0)

# 5. 检查修改的文件
git diff Core/Attachment/AttachmentManager.swift
git diff UI/Components/AttachmentDropOverlay.swift
git diff UI/Components/AttachmentPickerMenu.swift
```

---

## 8. 验收标准 (5/5 通过)

- [x] **P2-B1 目标 2 站点 → 0/0**: grep 无输出 ✅
- [x] **P1 4 站点保持 0/0**: grep 无输出 ✅
- [x] **P2-B2 1 站点保持 1/1**: grep 1 个命中 ✅
- [x] **clean strict build 通过**: EXIT 0, 10.08s ✅
- [x] **日志可复现**: 所有命令已记录 ✅

---

## 9. 下一步 (P2-B2)

等待 codex-1 快审 P2-B1 后，继续执行 P2-B2:
- 目标: `Services/ImageEnhancementService.swift:224` → 0/0
- 约束: 不使用 `@unchecked Sendable`，优先"去并发捕获"重构

---

**签名**: claude-1
**状态**: ✅ P2-B1 完成，等待 codex-1 快审
