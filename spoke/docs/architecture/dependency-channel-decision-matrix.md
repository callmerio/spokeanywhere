# SpokenAnyWhere 依赖通道决策矩阵

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `GOV-380`

---

## 一、依赖通道决策矩阵

| 场景 | 默认通道 | 何时使用 | 当前例子 | 何时不要用 |
|------|----------|----------|----------|------------|
| 同一 feature 内、owner 明确的 1:1 协调 | `direct call` | 调用链短、owner 明确、无需广播 | `RecordingController -> hudManager`、`ActionBarView -> dependencies.closeWindow` | 不要为了省传参引入通知 |
| app-scope 协作者、需要注入 / mock / preview | `ServiceContainer` / feature dependencies | UI、本地预览、测试替身、跨 feature service 装配 | `@Environment(\\.services)`、`AnswerPanelViewLiveDependencies`、`ServiceContainerLiveDependencies` | 不要把业务状态机直接绑到 `.shared` |
| 跨窗口 / 跨 feature / 广播式事件 | `NotificationCenter`（仅 allowlist 内） | 发送方与消费方天然解耦，且确实不是 1:1 协调 | `quickAskCancelRequested`、`translationUpdated`、`tagDeleted` | 不要在 view-local 事件或 orchestrator 主文件里滥发 |

### 快答

1. 新协作者能不能直接 `.shared`

- 默认：**不能**
- 允许：`*LiveDependencies.swift`、组合根、系统 API wrapper、预览/测试工厂

2. 新业务事件能不能直接 `NotificationCenter`

- 默认：**不能**
- 允许：只在下方 allowlist 模型可解释时新增

3. 新状态能不能落现有存储

- 默认：只有落进下方 state crosswalk 里的分类才可以

---

## 二、状态落点 Crosswalk

| 状态域 | 标准落点 | 当前例子 | 不该混入的东西 |
|--------|----------|----------|----------------|
| `UserContent` | `SwiftData` 或 feature-owned `Application Support` 文件 | `HistoryItem`、录音文件、`screenshot_items.json`、`session_history.json`、`vocabulary.json`、`tag_library.json` | 临时 UI 状态、权限阻塞态 |
| `Settings` | `AppStorage` / `UserDefaults`（统一经 `AppSettings` / `TTSSettings` / 设置类入口） | 快捷键、历史清理、字幕/截图/工具栏设置、TTS 配置 | 用户内容、secret |
| `Secrets` | `Keychain` | `AIProviderConfig.apiKeyReference`、`KeychainService` 下的 provider 凭据 | 普通设置、缓存 |
| `CapabilityCache` | 优先 runtime memory；若需跨重启，则 feature-owned `Application Support` cache | `ScreenCaptureService.cachedContent` 当前是 runtime-only；持久化缓存应单列 feature cache | 把缓存伪装成业务记录 |
| `SystemRuntime` | runtime-only objects | OCR context、Quick Ask 当前会话、Live Caption buffer、selection window、panel visibility、timer/task 状态 | `SwiftData`、`AppStorage`、`session_history.json` |

### 当前特别边界

- `ScreenshotManager.saveAll()/restoreAll()` 只服务于 pinned screenshot 资产
- `ClipboardHistoryService` 属于用户内容历史，不是设置
- `ScreenCaptureService.cachedContent` 当前是 capability cache，但仍停留在 runtime memory，不应误记成持久化
- 被权限拦截的 intent、临时面板状态、hover / focus / picker 可见性，一律归 `SystemRuntime`

---

## 三、NotificationCenter Allowlist

首批允许留在 `NotificationCenter.default` 的使用点如下：

| 事件 / 发布点 | 文件 | 为什么允许 | 未来要求 |
|---------------|------|------------|----------|
| `.quickAskCancelRequested` | `UI/HUD/FloatingPanelLiveDependencies.swift` | 跨浮层取消 Quick Ask，属于窗口级广播 | 保持只在 live dependency / bridge 层发，不回流视图本体 |
| `.translationUpdated` | `Core/LiveCaption/LiveCaptionManagerLiveDependencies.swift` | 字幕翻译刷新属于跨视图广播 | 若后续收敛，可转为更窄的 observer/facade |
| `.requestAddToDictionary` | `UI/Components/DictionarySelectableTextLiveDependencies.swift` | 选中文本到加词请求跨组件广播 | 保持 payload 结构文档化 |
| `.transcriptionModelChanged` | `Core/Transcription/Models/TranscriptionModelManagerLiveDependencies.swift` | 模型切换影响多个设置/运行面 | 只允许在 model live dependency 层发 |
| `.transcriptionModelRoleChanged` | `Core/Transcription/Models/TranscriptionModelManagerLiveDependencies.swift` | 角色切换影响多个依赖方 | 同上 |
| `.tagDeleted` | `Core/Tags/TagLibraryLiveDependencies.swift` | 标签库删除需要广播给内容层回收引用 | 继续维持 tagId payload |
| `.settingsSwitchToToolbar` publisher | `UI/Settings/SettingsViewLiveDependencies.swift` | 设置页内的跨 section 跳转仍是 UI 级广播 | 若后续形成更清晰 route object，可迁出 |

### Allowlist 使用规则

1. 新增默认通知必须先证明自己属于“跨窗口 / 跨 feature / 广播式协调”
2. 新增默认通知必须优先落在 `*LiveDependencies.swift` / bridge，不直接写进主业务文件
3. 新增通知必须带 owner、事件名、payload、消费方说明
4. 不在 allowlist 内的新增 `NotificationCenter.default` 使用，应视为 review blocker

---

## 四、与最小规则包的关系

- `minimal-rule-pack.md` 给默认答案
- 本文把默认答案升级为“可以直接做 review 判定”的矩阵与 allowlist

---

## 五、相关文档

- `./minimal-rule-pack.md`
- `./quality-gate.md`
- `./current-state-audit.md`
- `./shared-hot-path-contract.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
