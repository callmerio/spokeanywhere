# 截图钉图（Pin to Space）PRD / 设计文档（v1.0）

> **日期**：2025-12-19
> 
> **状态**：已确认，可实现

---

## 1. 背景与问题

### 1.1 问题现象

现有截图工具的“Pin / 置顶”能力通常是“悬浮在屏幕上”，但在 macOS 多虚拟桌面（Spaces）场景下会出现：

- 截图跟随虚拟桌面左右切换一起移动
- 无法把截图“绑定到某个 Space”，作为该 Space 的长期参考图

### 1.2 目标用户

- 多 Space 并行工作的开发者 / 设计师 / 研究者
- 希望在不同 Space 保持不同工作上下文（文档/设计稿/调试信息）

---

## 2. 目标与非目标

### 2.1 目标（Goals）

- [G1] 提供**区域截图**能力（MVP）
- [G2] 截图后生成“截图窗”，hover 显示 **Action Strip**（快捷动作条）
- [G3] 用户主动点击 Pin 后，截图窗固定在当前 Space（切换 Space 不跟随）
- [G4] **跨重启持久化**：Pinned 截图在 App 重启后可恢复显示
- [G5] 与 Quick Ask / OCR 打通：截图可一键进入提问流程

### 2.2 非目标（Non-goals）

- 不做标注编辑器（画笔、马赛克、形状编辑、图层）
- 不做鼠标穿透（v0.2 不做）
- 不做复杂图库管理（仅做最小持久化与恢复）

---

## 3. 触发方式（Trigger）

### 3.1 快捷键触发（默认 `⌥ + A`）

- 默认快捷键：`⌥ + A`
- 可配置：在“设置 -> 快捷键”新增一项“截图”可改键
- 冲突处理：
  - 应用内快捷键冲突（与录音/Quick Ask/Message Panel/Live Caption 等）必须提示并阻止保存
  - 系统级冲突：若注册失败，提示“快捷键注册失败，请更换组合键”

### 3.2 菜单栏入口（选项 B）

- 菜单栏图标点击后弹出菜单
  - `区域截图`（主入口）
  - （可选）`打开设置…`
  - （可选）`退出`

---

## 4. 交互与状态机

### 4.1 核心对象

- **ScreenshotWindow**：承载截图内容的独立窗口（“还是那个截图的窗”）
- **Action Strip**：hover 时浮现的快捷动作条（3–5 个高频动作）

### 4.2 状态定义

#### Pin 维度

- **Unpinned**（默认）：截图窗创建后不自动 Pin
- **Pinned**：用户点击 Pin 后，固定在当前 Space

#### Lock 维度

- **Unlocked**（默认）：允许拖拽/（可选）缩放
- **Locked**（已确认）：仅禁用拖拽/缩放，用于减少误操作；不做鼠标穿透

### 4.3 控件显隐规则（已确认）

- 所有控件（Close / Pin / Lock / Action Strip）均遵循：
  - **仅 hover 显示**
  - 非 hover 时尽量安静展示内容（遵循 Apple HIG：减少干扰）

---

## 5. UI 规格（Pin 后态）

### 5.1 布局

- 左上：Close（圆形 X）
- 右上：Lock / Unlock（🔒/🔓）
- 底部：Action Strip（仅 hover 显示）
- 顶部居中：Zoom HUD（可选，缩放时短暂显示 `NN%`）

### 5.2 Action Strip（P0 按钮集合）

- Pin / Unpin
- Copy Image
- OCR / Extract Text
- Quick Ask

说明：Close 建议只保留左上按钮，Action Strip 不重复。

### 5.3 Pin 视觉反馈（已确认 A）

- Pin 未启用：图钉线框
- Pin 启用：图钉实心高亮 + 极轻的边框/发光增强（低干扰）

### 5.4 Lock 行为（已确认 A）

- Locked：禁拖拽/禁缩放
- Locked 状态下控件仍是 hover 才显示

### 5.5 右键菜单（全量能力入口 + 逃生门）

必须包含：

- Close（⌘W）
- Copy Image（⌘C）
- Pin / Unpin
- Lock / Unlock（⌘L）
- Extract Text (OCR)
- Save As…（⌘S）
- Zoom：50% / 100% / 200%
- Opacity：20% / 50% / 100%
- Appearance：Shadow / Rounded Corners / Border

---

## 6. 端到端流程（MVP）

1) 触发截图（快捷键 `⌥+A` 或 菜单栏 -> 区域截图）
2) 进入区域选择模式，完成截图
3) 创建 ScreenshotWindow（Unpinned + Unlocked）
4) hover 显示 Action Strip
5) 用户点击 Pin：进入 Pinned（不自动 Pin）
6) 用户点击 Lock：进入 Locked（安静展示）
7) 用户点击 Quick Ask：带截图附件进入 Quick Ask
8) 用户点击 OCR：提取文字，可复制/可送入 Quick Ask

---

## 7. 持久化与恢复（跨重启）

### 7.1 持久化内容（最小集）

- 截图文件路径（或图片数据）
- 窗口几何信息（位置/尺寸/缩放/透明度）
- 外观开关（Shadow/Border/RoundedCorners）
- 状态（Pinned/Locked）

### 7.2 启动恢复策略（已确认 B：自动恢复显示）

- App 启动后自动恢复所有 Pinned 截图窗并显示

### 7.3 Space 绑定的可行性声明（必须写清）

- macOS 无稳定公开 API 可在重启后精确定位到“原 Space ID”。
- v0.2 的承诺：
  - **数据与状态不丢**，并会自动恢复显示
  - “恢复到原 Space”仅 best-effort；若 Space 发生变化，用户可再次 Pin 校正

---

## 8. 技术实现方案

### 8.1 方案对比：区域截图实现

| 方案 | 描述 | 优点 | 缺点 | 推荐度 |
|------|------|------|------|--------|
| A | 调用系统 `screencapture -i <temp_file>` | 原生体验、零开发量、不覆盖剪贴板 | 无法自定义 UI、依赖外部进程 | ⭐⭐⭐ |
| B | 自建全屏遮罩 + 鼠标绘制 | 完全可控、可自定义 | 开发量大、需处理多屏幕 | ⭐⭐ |

**推荐方案 A**：MVP 阶段使用系统 `screencapture -i <temp_file>` 写入临时文件（⚠️ 不使用 `-c` 避免覆盖用户剪贴板），后续按需自建。

### 8.2 方案对比：Pin to Space 实现

| 方案 | 描述 | 优点 | 缺点 | 推荐度 |
|------|------|------|------|--------|
| A | `collectionBehavior = []` | 一行代码、原生支持 | 无 | ⭐⭐⭐ |

**唯一方案**：设置 `window.collectionBehavior = []` 即可固定在当前 Space。

### 8.3 文件变更清单

| 文件路径 | 操作 | 说明 |
|----------|------|------|
| `Services/HotKeyService.swift` | 修改 | 新增 screenshotKeyCode/Modifiers + onScreenshotTrigger 回调 |
| `Services/AppSettings.swift` | 修改 | 新增 @AppStorage screenshotKeyCode/Modifiers |
| `Core/Attachment/ScreenCaptureService.swift` | 修改 | 新增 `captureRegion() async -> NSImage?` (调用 screencapture -i) |
| `Core/Screenshot/ScreenshotManager.swift` | 新建 | 管理截图窗生命周期、持久化、恢复 |
| `Core/Screenshot/ScreenshotItem.swift` | 新建 | 数据模型 (id/image/frame/isPinned/isLocked/opacity/...) |
| `UI/Screenshot/ScreenshotWindow.swift` | 新建 | NSPanel 子类，支持 Pin/Lock/hover 控件 |
| `UI/Screenshot/ScreenshotView.swift` | 新建 | SwiftUI 视图 (图片 + Action Strip + 控件) |
| `UI/Screenshot/ActionStripView.swift` | 新建 | 底部快捷动作条 (Pin/Copy/OCR/Quick Ask) |
| `App/AppDelegate.swift` | 修改 | 启动时恢复 Pinned 截图 |
| `UI/Settings/ShortcutSettingsView.swift` | 修改 | 新增"截图"快捷键配置项 |

### 8.4 核心接口定义

```swift
// ScreenshotItem.swift
// ✅ 使用 class + ObservableObject 确保状态同步（参考 CaptionItem 模式）
final class ScreenshotItem: ObservableObject, Identifiable, Codable {
    let id: UUID
    var imagePath: String          // ~/Library/Application Support/Spoke/Screenshots/
    var frame: CGRect              // 窗口位置尺寸
    var isPinned: Bool = false
    var isLocked: Bool = false
    var opacity: Double = 1.0
    var zoomLevel: Double = 1.0
    var appearance: ScreenshotAppearance = .default
    var createdAt: Date
}

// ScreenshotManager.swift
@MainActor
final class ScreenshotManager {
    static let shared = ScreenshotManager()
    
    func captureRegion() async -> ScreenshotItem?
    func createWindow(for item: ScreenshotItem) -> ScreenshotWindow
    func pin(_ item: ScreenshotItem)
    func unpin(_ item: ScreenshotItem)
    func lock(_ item: ScreenshotItem)
    func unlock(_ item: ScreenshotItem)
    func close(_ item: ScreenshotItem)
    func saveAll()
    func restoreAll()  // App 启动时调用
}

// ScreenshotWindow.swift
class ScreenshotWindow: NSPanel {
    var item: ScreenshotItem
    
    func updateCollectionBehavior() {
        // ✅ Unpinned 时包含 .transient 避免出现在 Mission Control（统一项目规范）
        collectionBehavior = item.isPinned ? [] : [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }
}
```

### 8.5 数据流

```
┌─────────────────────────────────────────────────────────────┐
│ 触发截图 (⌥+A / 菜单栏)                                      │
└─────────────────┬───────────────────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ ScreenCaptureService.captureRegion()                        │
│ → Process("screencapture", ["-i", "<temp_file>"])           │
│ → NSImage(contentsOf: tempFile) // 不污染剪贴板              │
└─────────────────┬───────────────────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ ScreenshotManager.createWindow(for: item)                   │
│ → ScreenshotWindow (Unpinned + Unlocked)                    │
│ → collectionBehavior = [.canJoinAllSpaces]                  │
└─────────────────┬───────────────────────────────────────────┘
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 用户点击 Pin                                                 │
│ → item.isPinned = true                                      │
│ → collectionBehavior = []                                   │
│ → saveAll() 持久化                                          │
└─────────────────────────────────────────────────────────────┘
```

### 8.6 持久化结构

```
~/Library/Application Support/Spoke/
├── Screenshots/
│   ├── {uuid}.png
│   └── ...
└── screenshot_items.json   // [ScreenshotItem]
```

---

## 9. 验收标准（Acceptance Criteria）

### AC1: 快捷键触发截图
- **Given**: App 运行中，用户在任意应用
- **When**: 按下 `⌥+A`
- **Then**: 进入区域选择模式；完成选择后出现截图窗（Unpinned + Unlocked）

### AC2: 菜单栏触发截图
- **Given**: App 运行中，菜单栏图标可见
- **When**: 点击菜单栏图标 -> 选择「区域截图」
- **Then**: 行为与 AC1 一致

### AC3: Action Strip hover 显隐
- **Given**: 截图窗已创建
- **When**: 鼠标移入截图窗区域
- **Then**: Action Strip 淡入显示（Pin/Copy/OCR/Quick Ask）
- **When**: 鼠标移出截图窗区域
- **Then**: Action Strip 淡出隐藏；截图窗不抢焦点

### AC4: Pin to Space 行为
- **Given**: 截图窗已创建（Unpinned），当前在 Space A
- **When**: 点击 Pin 按钮
- **Then**: Pin 按钮变为实心高亮；`window.collectionBehavior = []`
- **When**: 切换到 Space B
- **Then**: 截图窗**不**跟随，留在 Space A
- **When**: 切回 Space A
- **Then**: 截图窗仍在原位置

### AC5: Lock 行为
- **Given**: 截图窗已创建（Unlocked）
- **When**: 点击 Lock 按钮（或右键菜单 Lock）
- **Then**: Lock 图标变为 🔒；拖拽/缩放被禁用
- **When**: hover 截图窗
- **Then**: 控件（包括 Unlock）仍可见可点击

### AC6: Copy Image
- **Given**: 截图窗已创建
- **When**: 点击 Action Strip 的 Copy 或右键菜单 Copy Image
- **Then**: 图片写入剪贴板；在任意 App 可 ⌘V 粘贴

### AC7: OCR 提取文字
- **Given**: 截图窗已创建，截图内有可识别文字
- **When**: 点击 OCR 按钮
- **Then**: 提取文字并显示（Toast 或面板）；可复制或一键送入 Quick Ask

### AC8: Quick Ask 集成
- **Given**: 截图窗已创建
- **When**: 点击 Quick Ask 按钮
- **Then**: 打开 Quick Ask 面板，截图已作为附件预填

### AC9: 跨重启持久化与恢复
- **Given**: 存在 1+ 个 Pinned 截图窗
- **When**: 退出 App 并重新启动
- **Then**: 所有 Pinned 截图窗自动恢复显示；位置/尺寸/状态与退出前一致
- **Note**: Space 精确绑定为 best-effort；若 Space 变化，用户可再次 Pin 校正

---

## 10. 测试计划

### 10.1 触发入口
- [ ] `⌥+A` 触发区域截图
- [ ] 菜单栏 -> 区域截图
- [ ] 快捷键冲突：设置与录音相同快捷键 -> 提示冲突并阻止
- [ ] 快捷键可配置：改为 `⌥+S` -> 新快捷键生效

### 10.2 截图窗 UI
- [ ] 截图完成后出现截图窗（Unpinned + Unlocked）
- [ ] hover 显示 Action Strip；移出隐藏
- [ ] 截图窗不抢焦点（用户在其他 App 输入时不被打断）
- [ ] Close 按钮关闭截图窗
- [ ] 右键菜单包含所有功能入口

### 10.3 Pin to Space
- [ ] 点击 Pin -> 图标变实心高亮
- [ ] Pinned 后切换 Space -> 截图不跟随
- [ ] 切回原 Space -> 截图仍在
- [ ] 点击 Unpin -> 恢复跟随行为

### 10.4 Lock
- [ ] 点击 Lock -> 禁拖拽/缩放
- [ ] Locked 状态 hover -> 控件仍可见
- [ ] 点击 Unlock -> 恢复拖拽/缩放

### 10.5 功能集成
- [ ] Copy Image -> 剪贴板可粘贴
- [ ] OCR -> 提取文字正确
- [ ] Quick Ask -> 截图作为附件

### 10.6 持久化
- [ ] Pinned 截图 -> 退出 App -> 重启 -> 自动恢复
- [ ] 恢复后位置/尺寸/状态一致
- [ ] Unpinned 截图 -> 退出后不恢复（或可配置）

### 10.7 边界条件
- [ ] 截图权限未授予 -> 提示并引导授权
- [ ] 区域选择时按 ESC -> 取消截图
- [ ] 同时存在多个截图窗 -> 各自独立状态
- [ ] 截图窗拖出屏幕边界 -> 允许（用户可拖回）

---

## 11. 风险与约束

| 风险 | 影响 | 缓解 |
|------|------|------|
| 重启后无法精确回到原 Space | 体验不符合“绑定 Space”的理想预期 | PRD 明确 best-effort；提供二次 Pin 校正路径 |
| 自动恢复显示可能打扰用户 | 启动时出现多个截图窗 | 后续可加“启动恢复开关/延迟恢复/恢复数量上限” |
| 权限与签名导致截图 API 异常 | 无法截图或崩溃 | 依赖正确 .app 签名与 TCC 权限流程（开发流程约束） |

---

## 12. 当前进度

- [x] PRD v0.2 需求确认
- [x] PRD v1.0 定稿（边界条件 + 可测验收用例）
- [ ] 实现
- [ ] 验证
