# 长按 ESC 取消录音/润色 设计文档

## 1. 背景分析

### 当前问题
1. **录音时难以取消**：按住 Option+R 录音时，另一只手不好按 ESC；松开 Option+R 后会进入润色状态
2. **润色阶段无法取消**：LLM 处理中（转圈圈）用户无法中止，浪费资源
3. **Toggle 模式录音无法取消**：按一次 Option+R 开始录音后，无快捷方式取消

### 目标
- 长按 ESC 取消当前任务（录音/润色）
- 短按 ESC 显示提示（类似 Chrome Cmd+Q 交互）
- 提示样式参考图片：居中、简洁、深色背景

## 2. 方案对比

| 方案 | 描述 | 优点 | 缺点 | 推荐度 |
|------|------|------|------|--------|
| A | 双击 ESC 取消 | 简单直观 | 容易误触 | ⭐⭐ |
| B | 长按 ESC 取消 + 短按提示 | 防误触、符合 HIG | 实现稍复杂 | ⭐⭐⭐ |
| C | ESC 直接取消 | 最简单 | 太容易误触 | ⭐ |

### 推荐方案 B
参考 Chrome Cmd+Q 交互：
1. 短按 ESC → 显示提示"长按 ESC 取消"
2. 长按 ESC (≥0.5s) → 执行取消
3. 提示 1.5s 后自动消失

## 3. 详细设计

### 3.1 文件变更

| 文件路径 | 操作 | 说明 |
|----------|------|------|
| `Services/HotKeyService.swift` | 修改 | 新增 ESC 键监听 + 长按检测 |
| `Services/RecordingController.swift` | 修改 | 新增 cancelLLMProcessing() |
| `Services/FloatingHUDManager.swift` | 修改 | 新增 showCancelHint() / hideCancelHint() |
| `UI/HUD/RecordingState.swift` | 修改 | 新增 .cancelHint 状态 |
| `UI/HUD/FloatingCapsuleView.swift` | 修改 | 新增取消提示 overlay |
| `Core/LLM/LLMPipeline.swift` | 修改 | 新增 cancel() 方法 |

### 3.2 交互流程

```
[录音中 / 润色中 / Toggle 录音中]
        │
        ▼
   短按 ESC (<0.5s)
        │
        ▼
  显示提示 "长按 ESC 取消"
        │
   ┌────┴────┐
   │         │
 1.5s后    长按 ESC
 自动消失   (≥0.5s)
   │         │
   ▼         ▼
 恢复原状   执行取消
             │
             ▼
        显示 "已取消"
             │
             ▼
         0.5s 后隐藏
```

### 3.3 ESC 键处理逻辑 (HotKeyService)

```swift
// 新增属性
private var escPressStartTime: Date?
private let escLongPressThreshold: TimeInterval = 0.5

// ESC 键处理
case .keyDown:
    if keyCode == UInt32(kVK_Escape) && isInCancellableState() {
        escPressStartTime = Date()
        onEscShortPress?()  // 显示提示
        return nil
    }

case .keyUp:
    if keyCode == UInt32(kVK_Escape) {
        if let start = escPressStartTime {
            let duration = Date().timeIntervalSince(start)
            if duration >= escLongPressThreshold {
                onEscLongPress?()  // 执行取消
            }
        }
        escPressStartTime = nil
        return nil
    }

func isInCancellableState() -> Bool {
    return isRecording || isProcessing || isThinking
}
```

### 3.4 提示 UI 设计

```
┌─────────────────────────────────┐
│                                 │
│      长按 ESC 键取消录音         │
│                                 │
└─────────────────────────────────┘

样式：
- 背景: Color.black.opacity(0.85)
- 圆角: 12pt
- 字体: .system(size: 15, weight: .medium)
- 颜色: Color.white.opacity(0.9)
- 内边距: horizontal 20, vertical 12
- 位置: HUD 中央 overlay
```

### 3.5 状态机扩展

```swift
enum RecordingPhase {
    case idle
    case recording
    case processing
    case thinking
    case success
    case error
    case cancelHint    // 新增：显示取消提示
    case cancelled     // 新增：已取消
}
```

## 4. 测试计划

- [ ] 录音中短按 ESC → 显示提示 → 1.5s 后消失
- [ ] 录音中长按 ESC → 取消录音 → 显示"已取消"
- [ ] Toggle 录音中长按 ESC → 取消录音
- [ ] 润色中 (thinking) 长按 ESC → 取消 LLM → 显示"已取消"
- [ ] 非录音状态按 ESC → 无反应（不拦截系统 ESC）
- [ ] 长按阈值测试：0.4s 松开不触发，0.6s 松开触发

## 5. 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| ESC 被拦截影响其他应用 | 中 | 只在可取消状态拦截，其他状态放行 |
| LLM 取消后状态不一致 | 中 | cancel() 中清理所有状态 |
| 提示闪烁 | 低 | 防抖：提示显示期间不重复触发 |

## 6. 当前进度

- [x] 设计完成
- [ ] review 通过
- [ ] 实现完成
- [ ] 验证通过
