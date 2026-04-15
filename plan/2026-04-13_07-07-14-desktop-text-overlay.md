---
mode: plan
cwd: /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere
task: 规划 Phase 999.1 桌面文本贴屏 Overlay（剪贴板优先）
complexity: high
created_at: 2026-04-13T07:07:14+0800
---

# Plan: Phase 999.1 桌面文本贴屏 Overlay

## Goal
- 为 `Phase 999.1` 产出一份可执行实现计划，交付第一版“桌面文本贴屏 Overlay”能力。
- 第一版以**剪贴板文本 -> 默认 pinned 的桌面文本对象**为主链路，支持：
  - 主题化预览态
  - 双击进入编辑
  - 轻量 Markdown 渲染
  - 拖动 / 缩放 / 透明度调整
  - 持久化与重启恢复
- 保持与现有 screenshot pin 窗口交互尽量一致，但不把该能力硬塞进 screenshot annotation 体系。

## Scope
- In:
  - 新增并行的 DesktopText / PinnedText 对象模型与窗口管理链路
  - 剪贴板文本创建 pinned text overlay
  - 预览态 / 编辑态双态流转
  - 轻量 Markdown 子集渲染
  - 默认 pinned 的持久化与恢复
  - 基础工具栏语义：pin / unpin / lock / close
  - 与 screenshot window 一致的拖动、滚轮/触控板缩放、透明度语义
  - 单元测试 + 定向手工验收矩阵
- Out:
  - 语音入口正式接线
  - 样式设置页、字体/背景/主题自定义
  - 完整富文本 / note 产品能力
  - Finder 桌面层集成
  - 把 DesktopText 直接并入 `ScreenshotItem` / `ScreenshotManager`

## Decisions Locked By Context
- 文本对象必须是**活文本对象**，不是先转透明图片。
- 默认是**预览态**；**双击**是进入编辑的唯一核心语义。
- 第一版采用**轻量 Markdown 子集**，不做完整 Markdown / 富文本编辑器。
- 第一入口优先做**剪贴板文本**。
- 对象创建后默认即为 **pinned**。
- 交互与 screenshot pin window 尽量一致。

## Architecture Direction
- 采用**并行桌面文本栈**，不要污染现有 screenshot 数据模型：
  - `spoke/Core/DesktopText/*`
  - `spoke/UI/DesktopText/*`
- 复用现有 screenshot window 的成熟交互，而不是复制 screenshot annotation 的对象体系。
- 保持“展示上像贴图，模型上仍是活文本”的方向：
  - 预览态使用 Markdown -> attributed rendering
  - 编辑态使用主题化编辑视图编辑 Markdown 源文本

## Assumptions / Dependencies
- 第一版可接受“编辑的是 Markdown 源文本”，而不是所见即所得富文本编辑。
- 第一版允许新增一个**菜单栏入口**作为用户可见触发点，避免复用现有 `⌥V` clipboard pipeline 热键而引入语义冲突。
- 后续语音入口应调用同一套 manager / model API，不另起系统。
- 现有 screenshot window 的交互代码可作为复用或抽象提取对象。

## Implementation Phases

### Phase 1. DesktopText Core Model & Persistence
目标：建立与 screenshot 平行的文本对象与 manager，而不是把文本硬塞进截图模型。

工作包：
1. 新增 `PinnedTextItem`（或同等命名）：
   - `id`
   - `text`
   - `frame`
   - `opacity`
   - `scale/fontSize`
   - `isPinned`
   - `isLocked`
   - `screenLocalizedName`
   - `createdAt`
2. 新增 `PinnedTextManager`：
   - create
   - showWindow
   - updateFrame
   - pin / unpin / lock / unlock / close
   - saveAll / restoreAll
3. 存储路径与 screenshot 分离，避免互相污染。
4. 默认创建即 pinned，因此 create 流程要立即进入持久化集合。

完成标准：
- 能创建文本对象并落到独立持久化文件。
- 重启后 manager 能恢复 pinned 文本对象。

### Phase 2. Preview Window & Shared Desktop Interaction
目标：把对象真正展示成桌面悬浮文本预览，而不是普通文本框。

工作包：
1. 新增 `PinnedTextWindow`：
   - borderless / floating / nonactivating
   - 复用 screenshot window 的移动、层级、collectionBehavior 经验
2. 新增 `PinnedTextContentView`：
   - 主题化预览
   - 固定主题视觉（Groovebox 气质）
   - hover / 工具栏露出
3. 复用 screenshot window 的交互语义：
   - 拖动
   - 滚轮/触控板缩放
   - 左右调透明度 / 上下调大小（或等效语义）
4. 基础动作：
   - pin / unpin
   - lock / unlock
   - close

完成标准：
- 一个剪贴板文本能以 pinned overlay 显示在桌面上。
- 窗口交互手感与 screenshot pin window 同类而非割裂。

### Phase 3. Markdown Preview & Themed Editing
目标：建立“预览态 / 编辑态”双态，不退化成原始文本框。

工作包：
1. 定义第一版 Markdown 子集：
   - `# / ##`
   - 段落
   - 换行
   - `-` 列表
   - `**粗体**`
2. 预览态：
   - Markdown -> attributed text / display layout
   - 长文本可受限宽并自动换行
3. 编辑态：
   - 双击进入
   - 主题化编辑容器
   - 编辑 Markdown 源文本
   - 保存后回预览态
4. 明确禁止：
   - 表格 / 图片 / 复杂块级组件
   - 样式配置 UI

完成标准：
- 双击进入编辑，退出后预览与编辑内容一致。
- 长文本编辑仍保持统一主题感，而不是裸 `NSTextView` 观感。

### Phase 4. Clipboard Entry & App Surface Integration
目标：打通第一条完整用户链路。

工作包：
1. 增加用户可见入口：
   - 推荐先接 `AppDelegate` 菜单栏菜单项，例如“贴屏文本”
   - 不复用现有 `⌥V` clipboard pipeline 热键
2. 读取剪贴板文本：
   - 为空时提示 / beep / 日志
   - 过长时截断策略需明确
3. 创建 DesktopText 对象并默认 pinned
4. 预留 service API，供后续语音链路接入：
   - `createFromClipboard()`
   - `createFromText(_:, source:)`

完成标准：
- 用户能从显式入口把当前剪贴板文本生成一个默认 pinned 的桌面文本对象。
- 不影响现有 Message Panel 的 clipboard pipeline 语义。

### Phase 5. Verification, Polish, and Regression Safety
目标：把行为跑通，并确保不破坏现有 screenshot / floating window 行为。

工作包：
1. 新增测试：
   - 数据模型编码/解码 round-trip
   - pin/save/restore
   - Markdown 子集渲染核心逻辑
   - 预览态 / 编辑态流转
2. 手工验收矩阵：
   - 剪贴板 -> overlay
   - 默认 pinned
   - 双击编辑
   - 编辑后回预览
   - 拖动 / 缩放 / 透明度
   - 关闭后删除 / 重启恢复
3. 回归检查：
   - screenshot pin window 不回归
   - clipboard pipeline 仍走原 Message Panel 语义

完成标准：
- build / test / concurrency 全过
- 核心手工验收项逐项通过

## Candidate File Map
- `spoke/Core/DesktopText/PinnedTextItem.swift`
- `spoke/Core/DesktopText/PinnedTextManager.swift`
- `spoke/Core/DesktopText/PinnedTextMarkdownRenderer.swift`
- `spoke/UI/DesktopText/PinnedTextWindow.swift`
- `spoke/UI/DesktopText/PinnedTextContentView.swift`
- `spoke/UI/DesktopText/PinnedTextEditorView.swift` 或同等 AppKit bridge 文件
- `spoke/App/AppDelegate.swift`
- `spoke/Services/ServiceContainer.swift`
- `spoke/Services/ServiceContainerLiveDependencies.swift`
- `spoke/Tests/PinnedTextModelTests.swift`
- `spoke/Tests/PinnedTextWindowStateTests.swift`

## Tests & Verification
- `cd spoke && swift build`
- `cd spoke && swift test`
- `cd spoke && bash Tests/run-concurrency-check.sh`

建议新增测试重点：
- `PinnedTextItem` Codable / 状态 round-trip
- `PinnedTextManager` save / restore / default pinned 行为
- Markdown 子集解析与 attributed rendering
- 双击进入编辑 / 编辑退出回预览

手工验收：
1. 菜单栏点击“贴屏文本”时，当前剪贴板文本生成桌面对象
2. 对象创建后默认已 pinned
3. 单击是对象交互，双击进入编辑
4. 编辑后仍保持主题化外观
5. 上下/左右滚动调节大小与透明度
6. 重启后 pinned 文本能恢复
7. 原有 screenshot pin window 与 Message Panel clipboard pipeline 不回归

## Issue CSV
- Path: `issues/2026-04-13_07-07-14-desktop-text-overlay.csv`
- Must share the same timestamp/slug as this plan.

## Tools / MCP
- `manual|edit_file`：计划与 issue CSV 产物写入
- `shell|rg`：扫描现有 screenshot / clipboard / window 复用点
- `shell|swift build|swift test`：后续执行期验证

## Acceptance Checklist
- [x] 将 `999.1-CONTEXT` 中的产品决策转化为实现分期
- [x] 明确第一版以“剪贴板 -> 默认 pinned 文本对象”为主链路
- [x] 明确采用并行 DesktopText 栈，而不是污染 screenshot annotation
- [x] 明确默认 Markdown 范围与 deferred 能力
- [x] 明确验证矩阵与回归边界
- [x] 生成匹配的 issue CSV

## Risks / Blockers
- 当前项目主路线仍是功能冻结口径，此 phase 仍属于 backlog / exception lane，执行前需确认进入 feature 施工。
- 默认 pinned 意味着创建即持久化，若缺少清晰的 close/unpin 语义，桌面容易堆积对象。
- Markdown 预览与编辑源文本之间若处理不稳，容易出现“预览和编辑不一致”。
- 若过度复用 screenshot window 代码而不抽清边界，后续会形成两套特化逻辑互相牵扯。

## Rollback / Recovery
- 本计划阶段仅新增计划与 issue CSV；如需回滚，删除这两个文档即可。
- 实施阶段若发现 DesktopText 栈方向不成立，应优先回退新增 manager/window 链路，不影响 screenshot 体系。

## Checkpoints
- Commit after: plan + issues for Phase 999.1 are written
- Before implementation: confirm whether to keep planning-only artifacts uncommitted or commit as docs

## References
- `ROADMAP.md`
- `PROJECT.md`
- `docs/memo/999.1-CONTEXT.md`
- `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md`
- `docs/memo/2026-04-13-screenshot-text-annotation-imported-execution.md`
- `docs/reports/2026-04-13-screenshot-text-annotation-imported-execution.md`
- `spoke/UI/Screenshot/ScreenshotWindow.swift`
- `spoke/Core/Screenshot/ScreenshotManager.swift`
- `spoke/Core/Screenshot/ScreenshotItem.swift`
- `spoke/UI/HUD/FloatingPanel.swift`
- `spoke/Services/ClipboardPipelineService.swift`
- `spoke/App/AppDelegate.swift`
