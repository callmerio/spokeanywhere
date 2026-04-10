# SpokenAnyWhere 最小规则包

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: `RULE-320`

---

## 一、这份规则只回答三道题

1. 新协作者能不能直接用 `.shared`
2. 新业务事件能不能直接用 `NotificationCenter`
3. 新状态能不能落到现有存储

这不是 Phase 4 的完整治理矩阵；它是基于当前代码现实的最小可执行约束，用来防止后续收敛时继续自由发挥。

---

## 二、依赖通道最小规则

### 2.1 默认顺序

新增依赖时，默认按以下优先级判断：

1. 同一功能链内可直接传参 / closure 注入
2. 跨功能但仍属 app-scope 的协作者，走 `ServiceContainer` 或 feature dependencies
3. 只有在组合根 / live wiring / system adapter 层，才允许新增 `.shared`

### 2.2 对 `.shared` 的直接回答

| 问题 | 默认答案 | 允许例外 | 不允许的落点 |
|------|----------|----------|--------------|
| 新协作者能不能直接 `.shared` | **不能** | `*LiveDependencies.swift`、`*LiveHelpers.swift`、`ServiceContainerLiveDependencies.swift`、预览/测试工厂、系统 singleton 适配器 | 新 UI 视图本体、新 orchestrator 主文件、新状态模型 |

补充解释：

- 当前仓库仍有 `.shared`，但主要集中在 `*LiveDependencies.swift`、系统 API 包装和少量历史 helper
- 这意味着 `.shared` 不是被“全面禁止”，而是被压缩到组合根与 live wiring 层
- 因此新代码如果不在这些边界，就默认不能继续加 `.shared`

### 2.3 对新抽取协作者的要求

新抽取协作者满足任一条件时，优先不走 `.shared`：

- 会被 UI 直接调用
- 会被两个以上 orchestrator 共享
- 需要 mock / preview / test double
- 生命周期需要显式 start / stop / cleanup

这类对象应优先通过：

- 显式依赖参数
- feature dependencies struct
- `@Environment(\\.services)` / `ServiceContainer`

---

## 三、广播禁区与 `NotificationCenter` 最小规则

### 3.1 对 `NotificationCenter` 的直接回答

| 问题 | 默认答案 | 允许例外 | 禁区 |
|------|----------|----------|------|
| 新业务事件能不能直接 `NotificationCenter` | **不能** | 跨窗口 / 跨 feature / app-scope 广播，且必须有 owner、事件名、payload、消费者、cleanup 路径 | view-local 事件、1:1 服务协调、只为省传参而引入的广播 |

### 3.2 当前允许条件

只有同时满足以下条件，才允许新增 `NotificationCenter`：

1. 事件确实是跨边界广播，不是 1:1 协调
2. 事件名进入显式 `Notification.Name` 常量或 live dependency 包装
3. owner、发送方、消费方、payload 和 cleanup 路径写进文档
4. 不能用 direct call / closure / `ServiceContainer` 更简单地解决

### 3.3 当前禁止模式

以下情况默认禁止：

- 在新 UI 视图中直接 `NotificationCenter.default.post(...)`
- 在 orchestrator 主文件中把业务流拆成匿名通知广播
- 用通知代替 `hide/show`、`send/cancel` 这种本来就有明确 owner 的动作

说明：

- 当前仓库中的 repo-owned `NotificationCenter.default` 使用已经缩到少量 `*LiveDependencies.swift` 和特定 bridge
- 这说明默认路径应该是“先不用通知”，而不是“先发一个再说”

---

## 四、运行时状态 / 持久化状态最小分界

### 4.1 对“新状态能不能落现有存储”的直接回答

| 状态类型 | 标准落点 | 例子 | 默认结论 |
|----------|----------|------|----------|
| 用户内容 / 历史资产 | `SwiftData` 或 feature-owned `Application Support` 文件 | `HistoryItem`、录音文件、pinned screenshot JSON / images | 可以，但必须属于用户资产 |
| Settings / preferences | `AppStorage` / `UserDefaults`（经 `AppSettings` 等统一入口） | 快捷键、字幕显示、截图/工具栏开关 | 可以，但应走现有设置骨架 |
| Secrets | `Keychain` | provider API keys | 只能走 `Keychain` |
| Capability cache / derived artifacts | feature-owned `Application Support` / cache 文件 | 预热结果、编译模型、衍生缓存 | 可以，但不能伪装成业务内容 |
| System runtime / session state | runtime-only objects | timer、panel visibility、selection window、OCR context、live caption buffer | **不能落持久化**，除非先升级为显式产品资产 |

### 4.2 三条硬判断

1. 如果状态只是为了当前会话跑通，就不要落盘
2. 如果状态属于用户长期资产，必须明确 owner、格式和恢复路径
3. 如果状态既不是设置、也不是用户内容、也不是 secret，就不要顺手塞进现有存储

### 4.3 当前特别边界

- `ScreenshotManager.saveAll()/restoreAll()` 只服务于 `pinned screenshots` 这类功能资产
- OCR 结果、录音中的上下文、Live Caption buffer 都属于 runtime-only
- 权限被拦截的 intent、临时 UI 状态、panel 打开状态，不应混入 `SwiftData` / `AppStorage`

---

## 五、Review 快答

做 diff review 时，直接按下面三行问：

1. 这个新协作者是不是被放进了组合根 / live wiring 之外？如果是，就不能新增 `.shared`
2. 这个新事件是不是跨窗口 / 跨 feature 广播？如果不是，就不要用 `NotificationCenter`
3. 这个新状态是不是用户长期资产或设置？如果不是，就不要落持久化

如果三问里有任一答不上来，先停在文档层，不进入实现层。

---

## 六、与后续阶段的关系

- `LIFE-310` 提供了 owner / register / cleanup 基线
- 本文件保留“最小快答”职责，不替代正式治理矩阵
- 正式决策矩阵、状态 crosswalk 与首批 allowlist 见 `./dependency-channel-decision-matrix.md`

---

## 七、相关文档

- `./p1-lifecycle-inventory.md`
- `./dependency-channel-decision-matrix.md`
- `./current-state-audit.md`
- `./quick-reference.md`
- `./quality-gate.md`
- `../plans/2026-04-10-architecture-optimization-roadmap-v3.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
