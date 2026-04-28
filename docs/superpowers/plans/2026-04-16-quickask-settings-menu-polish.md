# Quick Ask / Settings Polish + Status Menu Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:super-40-subagent-driven-development (recommended) or superpowers:super-41-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐状态菜单里的“录音”和“Quick Ask”功能入口与快捷键提示，并对 Quick Ask 最终回答弹窗、设置页共享外壳做一轮低风险样式打磨。

**Architecture:** 保持现有 `AppDelegate + NSStatusItem + NSMenu`、`SwiftUI + AppKit` 混合结构不变，只补最薄的菜单命令层和少量可测试的样式常量。Quick Ask 回答弹窗不重做交互流，只收敛壳层、顶部工具栏显隐和正文/输入区的接缝；设置页不重做布局，只统一共享组件的字级、密度与壳层节奏。

**Tech Stack:** Swift 5.9、SwiftUI、AppKit `NSMenu` / `NSStatusItem`、Swift Testing、DesignTokens

---

### Task 1: 状态菜单命令标签与缺失入口

**Files:**
- Create: `spoke/App/AppStatusMenuLabels.swift`
- Create: `spoke/Tests/AppStatusMenuLabelsTests.swift`
- Modify: `spoke/App/AppDelegate.swift`
- Test: `spoke/Tests/AppStatusMenuLabelsTests.swift`

- [ ] **Step 1: 先写会失败的菜单标签测试**

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("状态菜单标签测试")
struct AppStatusMenuLabelsTests {

    @Test("会为录音与 Quick Ask 生成带快捷键的标题")
    func formatsRecordingAndQuickAskTitles() {
        let labels = AppStatusMenuLabels.make(
            recordingShortcut: "⌥R",
            quickAskShortcut: "⌥Q"
        )

        #expect(labels.recording == "录音  ⌥R")
        #expect(labels.quickAsk == "Quick Ask  ⌥Q")
    }
}
```

- [ ] **Step 2: 运行测试，确认当前还没有这个标签模型**

Run: `swift test --filter AppStatusMenuLabelsTests`

Expected: FAIL，报错类似 `cannot find 'AppStatusMenuLabels' in scope`

- [ ] **Step 3: 写最小菜单标签模型**

```swift
struct AppStatusMenuLabels: Equatable {
    let recording: String
    let quickAsk: String

    static func make(
        recordingShortcut: String,
        quickAskShortcut: String
    ) -> Self {
        .init(
            recording: "录音  \(recordingShortcut)",
            quickAsk: "Quick Ask  \(quickAskShortcut)"
        )
    }
}
```

- [ ] **Step 4: 在 `AppDelegate.setupMenuBar()` 里补上缺失的两条菜单项**

把 [AppDelegate.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/App/AppDelegate.swift) 的菜单构造从“只有一行录音快捷键总览”改成“有可点击命令入口”。
同时删掉已经不再需要的 `hotkeyMenuItem` 属性和对应的只读展示行，避免菜单里同时出现“旧总览”和“新命令入口”两套提示。

关键代码改成下面这种结构：

```swift
private var recordingMenuItem: NSMenuItem?
private var quickAskMenuItem: NSMenuItem?

private func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
        button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "SpokenAnyWhere")
    }

    let labels = AppStatusMenuLabels.make(
        recordingShortcut: dependencies.appSettings.shortcutDisplayString,
        quickAskShortcut: dependencies.appSettings.quickAskShortcutDisplayString
    )

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "SpokenAnyWhere", action: nil, keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())

    let recordingItem = NSMenuItem(title: labels.recording, action: #selector(toggleRecordingFromMenu), keyEquivalent: "")
    self.recordingMenuItem = recordingItem
    menu.addItem(recordingItem)

    let quickAskItem = NSMenuItem(title: labels.quickAsk, action: #selector(triggerQuickAskFromMenu), keyEquivalent: "")
    self.quickAskMenuItem = quickAskItem
    menu.addItem(quickAskItem)

    menu.addItem(NSMenuItem.separator())
    // 保留后面的实时字幕 / 选择工具栏 / 截图 / 贴屏文本 / 查词 / 设置 / 退出

    statusItem?.menu = menu
    setupShortcutObserver()
}
```

- [ ] **Step 5: 让标题在快捷键设置变更后同步刷新**

不要只更新旧的 `hotkeyMenuItem`。把刷新逻辑收敛成一个方法，至少同时刷新录音和 Quick Ask 两条命令标题：

```swift
private func updateShortcutMenuItems() {
    let labels = AppStatusMenuLabels.make(
        recordingShortcut: dependencies.appSettings.shortcutDisplayString,
        quickAskShortcut: dependencies.appSettings.quickAskShortcutDisplayString
    )

    recordingMenuItem?.title = labels.recording
    quickAskMenuItem?.title = labels.quickAsk
}

private func setupShortcutObserver() {
    installObserver(&shortcutObserver, forName: AppSettings.shortcutDidChangeNotification) { [weak self] _ in
        self?.updateShortcutMenuItems()
    }
    installObserver(&quickAskShortcutObserver, forName: AppSettings.quickAskShortcutDidChangeNotification) { [weak self] _ in
        self?.updateShortcutMenuItems()
    }
}
```

同时在 `AppDelegate` 属性区新增：

```swift
private var quickAskShortcutObserver: NSObjectProtocol?
```

并且同步更新观察者清理逻辑，避免泄漏：

```swift
private func removeAllObservers() {
    removeObserver(&shortcutObserver)
    removeObserver(&quickAskShortcutObserver)
    removeObserver(&toolbarSettingsObserver)
    removeObserver(&settingsWindowObserver)
}
```

- [ ] **Step 6: 重新运行菜单标签测试**

Run: `swift test --filter AppStatusMenuLabelsTests`

Expected: PASS，输出包含 `Test run with 1 test` 且无失败

- [ ] **Step 7: 提交这一小步**

```bash
git add spoke/App/AppStatusMenuLabels.swift spoke/App/AppDelegate.swift spoke/Tests/AppStatusMenuLabelsTests.swift
git commit -m "feat: add status menu labels for recording and quick ask"
```

### Task 2: 菜单触发的 Quick Ask / 录音命令

**Files:**
- Modify: `spoke/App/AppDelegate.swift`
- Modify: `spoke/Services/RecordingController.swift`
- Create: `spoke/Tests/AppStatusMenuCommandTests.swift`
- Test: `spoke/Tests/AppStatusMenuCommandTests.swift`

- [ ] **Step 1: 先写会失败的命令测试**

这里不直接实例化 `AppDelegate`，而是测试“菜单命令动作的最薄逻辑”。

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("状态菜单命令测试")
@MainActor
struct AppStatusMenuCommandTests {

    @Test("录音命令会走统一的菜单录音入口")
    func recordingCommandCallsMenuTogglePath() {
        var toggleCalls = 0

        let runtime = AppStatusMenuCommandRuntime(
            toggleRecording: { toggleCalls += 1 },
            startQuickAsk: {}
        )

        runtime.toggleRecording()

        #expect(toggleCalls == 1)
    }

    @Test("Quick Ask 命令会触发 Quick Ask 会话")
    func quickAskCommandStartsSession() {
        var quickAskCalls = 0

        let runtime = AppStatusMenuCommandRuntime(
            toggleRecording: {},
            startQuickAsk: { quickAskCalls += 1 }
        )

        runtime.startQuickAsk()

        #expect(quickAskCalls == 1)
    }
}
```

- [ ] **Step 2: 运行测试，确认运行时还不存在**

Run: `swift test --filter AppStatusMenuCommandTests`

Expected: FAIL，报错类似 `cannot find 'AppStatusMenuCommandRuntime' in scope`

- [ ] **Step 3: 增加极薄的命令运行时**

为了避免把 `AppDelegate` 变成难测对象，新建一个很薄的运行时类型，专门承接菜单点击动作：

```swift
@MainActor
struct AppStatusMenuCommandRuntime {
    let toggleRecording: () -> Void
    let startQuickAsk: () -> Void
}
```

建议把它和 `AppStatusMenuLabels` 放在同一个文件 `spoke/App/AppStatusMenuLabels.swift`，避免多造文件。

- [ ] **Step 4: 给 `RecordingController` 一个正式的菜单入口**

当前 [RecordingController.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/Services/RecordingController.swift) 已有 `debugToggleRecording()`，说明不需要重建状态机。把这段逻辑升格为正式公共入口，再让调试入口复用它：

```swift
func toggleRecordingFromMenu() {
    if dependencies.hotKeyService.isRecording {
        stopRecordingSession()
        logger.info("🎙️ [MenuBar] recording toggled -> stop")
        return
    }

    dependencies.hotKeyService.isRecording = true
    startRecordingSession()
    if dependencies.hotKeyService.isRecording {
        logger.info("🎙️ [MenuBar] recording toggled -> start")
    } else {
        logger.info("🎙️ [MenuBar] recording start aborted")
    }
}

#if DEBUG
func debugToggleRecording() {
    toggleRecordingFromMenu()
}
#endif
```

- [ ] **Step 5: 在 `AppDelegate` 里接上两个 selector**

把下面两个动作补到 [AppDelegate.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/App/AppDelegate.swift)：

```swift
private lazy var statusMenuRuntime = AppStatusMenuCommandRuntime(
    toggleRecording: { [recordingController = dependencies.recordingController] in
        recordingController.toggleRecordingFromMenu()
    },
    startQuickAsk: { [quickAskService = dependencies.quickAskService] in
        quickAskService.startSession()
    }
)

@objc func toggleRecordingFromMenu() {
    statusMenuRuntime.toggleRecording()
}

@objc func triggerQuickAskFromMenu() {
    statusMenuRuntime.startQuickAsk()
}
```

这样 AppDelegate 里只保留 selector，具体动作交给薄运行时，不需要为测试引入整个 `NSApplicationDelegate` 注入体系。

- [ ] **Step 6: 运行菜单命令测试**

Run: `swift test --filter AppStatusMenuCommandTests`

Expected: PASS，两个测试全部通过

- [ ] **Step 7: 补一轮与菜单相关的回归测试**

再加一个结构性断言，确认命令标题确实存在于菜单构造里。测试写进 `AppStatusMenuLabelsTests.swift` 或单独写在 `AppStatusMenuCommandTests.swift` 都可以，推荐追加到后者：

```swift
@Test("菜单标签会显式包含录音与 Quick Ask 入口") 
func labelsExposeMissingEntries() {
    let labels = AppStatusMenuLabels.make(
        recordingShortcut: "⌥R",
        quickAskShortcut: "⌥Q"
    )

    #expect(labels.recording.contains("录音"))
    #expect(labels.quickAsk.contains("Quick Ask"))
}
```

- [ ] **Step 8: 提交这一小步**

```bash
git add spoke/App/AppStatusMenuLabels.swift spoke/App/AppDelegate.swift spoke/Services/RecordingController.swift spoke/Tests/AppStatusMenuCommandTests.swift spoke/Tests/AppStatusMenuLabelsTests.swift
git commit -m "feat: add status menu commands for recording and quick ask"
```

### Task 3: Quick Ask 最终回答弹窗小修

**Files:**
- Create: `spoke/UI/QuickAsk/AnswerPanelStyle.swift`
- Create: `spoke/Tests/AnswerPanelStyleTests.swift`
- Modify: `spoke/UI/QuickAsk/AnswerPanelView.swift`
- Modify: `spoke/UI/QuickAsk/AnswerPanelView+Toolbar.swift`
- Modify: `spoke/UI/QuickAsk/AnswerPanelView+Input.swift`
- Test: `spoke/Tests/AnswerPanelStyleTests.swift`
- Test: `spoke/Tests/AnswerPanelPilotTests.swift`

- [ ] **Step 1: 先写会失败的样式常量测试**

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("AnswerPanel 样式测试")
struct AnswerPanelStyleTests {

    @Test("顶部工具栏在非 hover 时保持弱可见")
    func toolbarKeepsIdleOpacity() {
        #expect(AnswerPanelStyle.toolbarIdleOpacity == 0.42)
    }

    @Test("外层黑色叠加降低到更轻的覆盖度")
    func shellOverlayUsesLighterOpacity() {
        #expect(AnswerPanelStyle.backgroundOverlayOpacity == 0.28)
    }

    @Test("正文与追问输入区之间有明确分隔线")
    func inputSeparatorUsesVisibleOpacity() {
        #expect(AnswerPanelStyle.inputSeparatorOpacity == 0.55)
    }
}
```

- [ ] **Step 2: 运行测试，确认样式常量文件还不存在**

Run: `swift test --filter AnswerPanelStyleTests`

Expected: FAIL，报错类似 `cannot find 'AnswerPanelStyle' in scope`

- [ ] **Step 3: 写最小样式常量**

```swift
import Foundation

enum AnswerPanelStyle {
    static let toolbarIdleOpacity = 0.42
    static let backgroundOverlayOpacity = 0.28
    static let inputSeparatorOpacity = 0.55
}
```

- [ ] **Step 4: 让顶部工具栏从“完全隐藏”改为“弱显 + hover 强化”**

把 [AnswerPanelView.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/QuickAsk/AnswerPanelView.swift) 里这段：

```swift
toolbar
    .opacity(isHoveringToolbar ? 1 : 0)
```

改成：

```swift
toolbar
    .opacity(isHoveringToolbar ? 1 : AnswerPanelStyle.toolbarIdleOpacity)
```

这样工具栏不会再“完全躲起来”，但 hover 仍然有明显强化。

- [ ] **Step 5: 把回答弹窗外壳黑度收轻，并加正文/输入区分隔**

在 [AnswerPanelView.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/QuickAsk/AnswerPanelView.swift) 里做两个小改动：

1. 背景黑叠加：

```swift
Color.black.opacity(AnswerPanelStyle.backgroundOverlayOpacity)
```

2. 正文和输入区之间加分隔：

```swift
VStack(spacing: 0) {
    Color.clear.frame(height: 10)

    ScrollViewReader { proxy in
        ScrollView {
            // 维持现有消息流
        }
    }

    Divider()
        .overlay(DesignTokens.Colors.borderPrimary.opacity(AnswerPanelStyle.inputSeparatorOpacity))

    inputArea
}
```

- [ ] **Step 6: 保持输入区本身不重做，只做接缝优化**

在 [AnswerPanelView+Input.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/QuickAsk/AnswerPanelView+Input.swift) 里保留现有结构，不改发送、录音、拖拽逻辑，只把顶边距改成更贴合分隔线的节奏：

```swift
.padding(.horizontal, 16)
.padding(.bottom, 16)
.padding(.top, 10)
```

不要顺手去改 `AnswerPanelTextEditor` 的行为，也不要动 Markdown 渲染逻辑。

- [ ] **Step 7: 运行局部测试，确认结构没有回归**

Run: `swift test --filter 'AnswerPanelStyleTests|AnswerPanelPilotTests'`

Expected: PASS，样式常量测试通过，`show/hide 会创建可聚焦窗口并在关闭后移除状态` 继续通过

- [ ] **Step 8: 提交这一小步**

```bash
git add spoke/UI/QuickAsk/AnswerPanelStyle.swift spoke/UI/QuickAsk/AnswerPanelView.swift spoke/UI/QuickAsk/AnswerPanelView+Input.swift spoke/Tests/AnswerPanelStyleTests.swift
git commit -m "feat: polish quick ask answer panel chrome"
```

### Task 4: 设置页共享组件小修

**Files:**
- Create: `spoke/UI/Settings/SettingsChrome.swift`
- Create: `spoke/Tests/SettingsChromeTests.swift`
- Modify: `spoke/UI/Settings/SettingsView.swift`
- Modify: `spoke/UI/Settings/SettingsComponents.swift`
- Modify: `spoke/UI/Settings/GeneralSettingsContent.swift`
- Modify: `spoke/UI/Settings/ShortcutsSettingsContent.swift`
- Test: `spoke/Tests/SettingsChromeTests.swift`
- Test: `spoke/Tests/SettingsWindowRuntimeTests.swift`

- [ ] **Step 1: 先写会失败的设置页样式常量测试**

```swift
import Testing
@testable import SpokenAnyWhere

@Suite("Settings 共享样式测试")
struct SettingsChromeTests {

    @Test("侧栏宽度稍微放宽，避免标题与图标显得过挤")
    func sidebarWidthUsesSharedMetric() {
        #expect(SettingsChrome.sidebarWidth == 196)
    }

    @Test("内容区保留统一的横向留白")
    func contentHorizontalPaddingUsesSharedMetric() {
        #expect(SettingsChrome.contentHorizontalPadding == 28)
    }
}
```

- [ ] **Step 2: 运行测试，确认 `SettingsChrome` 还不存在**

Run: `swift test --filter SettingsChromeTests`

Expected: FAIL，报错类似 `cannot find 'SettingsChrome' in scope`

- [ ] **Step 3: 写最小样式常量**

```swift
import CoreGraphics

enum SettingsChrome {
    static let sidebarWidth: CGFloat = 196
    static let contentHorizontalPadding: CGFloat = 28
}
```

- [ ] **Step 4: 统一设置页共享壳层的宽度、留白和基础字体**

在 [SettingsView.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/Settings/SettingsView.swift) 和 [SettingsComponents.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/Settings/SettingsComponents.swift) 里做最小改动：

```swift
// SettingsView.sideBar
.frame(width: SettingsChrome.sidebarWidth)

// SettingsView.contentArea
.padding(.horizontal, SettingsChrome.contentHorizontalPadding)

// SidebarButton
Text(title)
    .font(DesignTokens.Typography.body)

// SettingsRow
Text(title)
    .font(DesignTokens.Typography.body)

if let desc = description {
    Text(desc)
        .font(DesignTokens.Typography.caption)
}
```

这里不要大面积替换所有设置页文件里的 `.font(.system(size: ...))`，先把共享组件打磨好，让大多数页面自然跟着变顺。

- [ ] **Step 5: 给高频页补共享 section header**

在 [SettingsComponents.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/Settings/SettingsComponents.swift) 新增一个小组件：

```swift
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DesignTokens.Typography.caption.weight(.medium))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .padding(.leading, 4)
    }
}
```

然后在 [GeneralSettingsContent.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/Settings/GeneralSettingsContent.swift) 和 [ShortcutsSettingsContent.swift](/Users/bigdan/.config/superpowers/worktrees/spokeanywhere/plan-quickask-settings-menu-polish-20260416/spoke/UI/Settings/ShortcutsSettingsContent.swift) 里，把顶部 section 文案替换成：

```swift
SettingsSectionHeader(title: "启动与行为")
SettingsSectionHeader(title: "音频设置")
SettingsSectionHeader(title: "全局快捷键")
```

- [ ] **Step 6: 运行设置页局部测试**

Run: `swift test --filter 'SettingsChromeTests|SettingsWindowRuntimeTests'`

Expected: PASS，新的样式常量测试通过，原有设置窗口 runtime 测试继续通过

- [ ] **Step 7: 提交这一小步**

```bash
git add spoke/UI/Settings/SettingsChrome.swift spoke/UI/Settings/SettingsView.swift spoke/UI/Settings/SettingsComponents.swift spoke/UI/Settings/GeneralSettingsContent.swift spoke/UI/Settings/ShortcutsSettingsContent.swift spoke/Tests/SettingsChromeTests.swift
git commit -m "feat: polish shared settings chrome"
```

### Task 5: 全量验证与手工验收

**Files:**
- Modify: 无
- Test: `spoke/Tests/AppStatusMenuLabelsTests.swift`
- Test: `spoke/Tests/AppStatusMenuCommandTests.swift`
- Test: `spoke/Tests/AnswerPanelStyleTests.swift`
- Test: `spoke/Tests/SettingsChromeTests.swift`

- [ ] **Step 1: 运行针对本次改动的局部测试**

Run: `swift test --filter 'AppStatusMenu|AnswerPanelStyle|AnswerPanelPilot|SettingsChrome|SettingsWindowRuntime'`

Expected: PASS，所有新旧相关测试通过

- [ ] **Step 2: 运行全量单元测试**

Run: `swift test`

Expected: PASS，输出包含 `Test run with` 且总数不低于当前基线 `238 tests in 63 suites`

- [ ] **Step 3: 运行并发检查**

Run: `bash Tests/run-concurrency-check.sh`

Expected: PASS，输出包含 `strict-concurrency build 通过 (0 warnings)`

- [ ] **Step 4: 启动最新 App 做手工验收**

Run:

```bash
pkill -x SpokenAnyWhere || true
pkill -f 'log stream.*SpokenAnyWhere' || true
LOG_DIR=/tmp/spokeanywhere-manual-uat-logs ./dev.sh
```

Expected: 开发版 App 成功启动，可在手工测试中确认以下 4 点：

1. 菜单栏里出现 `录音  <当前快捷键>` 和 `Quick Ask  <当前快捷键>`
2. 点击 `录音` 可开始/停止录音
3. 点击 `Quick Ask` 可拉起 Quick Ask 会话
4. Quick Ask 最终回答弹窗顶部工具栏默认弱可见，hover 更明显，正文与输入区之间有明确分隔

- [ ] **Step 5: 做一次设置页手工检查**

手工检查以下 3 点：

1. 侧栏标题、图标和文字不再显得过挤
2. 通用行标题/说明字级更统一
3. `General` 和 `Shortcuts` 两个高频页的 section header 节奏更稳

- [ ] **Step 6: 完成最终提交**

```bash
git status --short
git add spoke/App/AppStatusMenuLabels.swift spoke/App/AppDelegate.swift spoke/Services/RecordingController.swift spoke/UI/QuickAsk/AnswerPanelStyle.swift spoke/UI/QuickAsk/AnswerPanelView.swift spoke/UI/QuickAsk/AnswerPanelView+Input.swift spoke/UI/Settings/SettingsChrome.swift spoke/UI/Settings/SettingsView.swift spoke/UI/Settings/SettingsComponents.swift spoke/UI/Settings/GeneralSettingsContent.swift spoke/UI/Settings/ShortcutsSettingsContent.swift spoke/Tests/AppStatusMenuLabelsTests.swift spoke/Tests/AppStatusMenuCommandTests.swift spoke/Tests/AnswerPanelStyleTests.swift spoke/Tests/SettingsChromeTests.swift
git commit -m "feat: polish quick ask, settings, and status menu commands"
```

---

## Self-Review

### Spec coverage

- 菜单栏缺失 `Quick Ask` / `录音` 入口：Task 1 + Task 2 覆盖
- 菜单里显示快捷键提示：Task 1 覆盖
- 快捷键变更后菜单同步：Task 1 覆盖
- Quick Ask 最终回答弹窗只做小幅样式打磨：Task 3 覆盖
- 设置页只做共享组件和高频页轻量打磨：Task 4 覆盖
- 不做大改版、不重做交互流：Task 3 / Task 4 都明确限制了范围

### Placeholder scan

- 没有 `TODO`、`TBD`、`implement later`
- 每个代码步骤都给了明确文件和代码片段
- 每个验证步骤都给了命令和预期结果

### Type consistency

- `AppStatusMenuLabels`、`AppStatusMenuCommandRuntime`、`AnswerPanelStyle`、`SettingsChrome` 在任务内前后命名保持一致
- `toggleRecordingFromMenu()` / `triggerQuickAskFromMenu()` 是 `AppDelegate` selector 名称，和 Task 1 / Task 2 中的调用保持一致
- `SettingsSectionHeader` 只在 Task 4 中引入，并只用于 `GeneralSettingsContent` / `ShortcutsSettingsContent`
