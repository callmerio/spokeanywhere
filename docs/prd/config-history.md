# History Cleanup 配置详细文档

> 版本: v1.0
> 创建时间: 2026-02-23
> 用途: History Cleanup 功能的所有配置项详细说明

---

## 配置项总览

History Cleanup 功能共有 3 个配置项，控制历史记录自动清理行为：

| setting_key | owner | read-path | write-path | 生效语义 | dependencies | side_effects |
|-------------|-------|-----------|------------|----------|--------------|--------------|
| `historyAutoCleanupEnabled` | AppSettings.swift:107 | AppDelegate.swift:233 | **UI 未实现** | 启动时 | HistoryManager | 自动清理任务启动/停止 |
| `historyKeepDays` | AppSettings.swift:110 | AppDelegate.swift:237-238 | **UI 未实现** | 启动时 | historyAutoCleanupEnabled | 清理保留天数 |
| `historyMaxCount` | AppSettings.swift:113 | AppDelegate.swift:242-243 | **UI 未实现** | 启动时 | historyAutoCleanupEnabled | 清理最大数量 |

---

## 1. historyAutoCleanupEnabled

### 基本信息

**类型**: `Bool`
**默认值**: `true`
**配置位置**: `spoke/Services/AppSettings.swift:107`
**持久化**: UserDefaults (`HistoryAutoCleanupEnabled`)

### 读取入口

**主要读取点**: `spoke/App/AppDelegate.swift:233`

```swift
// AppDelegate.swift:231-246
private func performHistoryCleanup() {
    let settings = AppSettings.shared
    guard settings.historyAutoCleanupEnabled else { return }

    Task {
        // 按天数清理
        if settings.historyKeepDays > 0 {
            await HistoryManager.shared.performCleanup(policy: .keepDays(settings.historyKeepDays))
        }

        // 按条数清理
        if settings.historyMaxCount > 0 {
            await HistoryManager.shared.performCleanup(policy: .keepCount(settings.historyMaxCount))
        }
    }
}
```

### 写入入口

**UI 入口**: **未实现**

**当前状态**:
- `HistorySettingsContent.swift` 仅包含历史记录列表视图
- 未找到配置项的 Toggle/Stepper 控件
- 配置项仅可通过 UserDefaults 手动修改

**预期 UI 位置**: `spoke/UI/Settings/HistorySettingsContent.swift`（待实现）

**预期响应逻辑**:
1. 用户在设置界面切换开关
2. SwiftUI 绑定自动更新 `AppSettings.shared.historyAutoCleanupEnabled`
3. `@AppStorage` 自动保存到 UserDefaults
4. 下次应用启动时生效

### 生效时机

**启动时生效** - 应用启动时检查并执行清理

**生效流程**:
1. 应用启动，`AppDelegate.applicationDidFinishLaunching()` 被调用
2. 调用 `performHistoryCleanup()` 方法
3. 检查 `settings.historyAutoCleanupEnabled` 当前值
4. 如果为 `true`，根据 `historyKeepDays` 和 `historyMaxCount` 执行清理
5. 如果为 `false`，跳过清理任务

### 依赖与联动

**前置依赖**:
- `HistoryManager` 必须已配置（`AppDelegate.swift:79` 初始化）
- SwiftData ModelContext 必须可用

**跨模块影响**:
- 影响 `AppDelegate.performHistoryCleanup()` 的清理逻辑
- 控制 `historyKeepDays` 和 `historyMaxCount` 是否生效

**关联配置**:
- `historyKeepDays`: 清理保留天数（子配置）
- `historyMaxCount`: 清理最大数量（子配置）

### 副作用与回退

**性能影响**:
- 开启时：应用启动时执行清理任务（后台线程，优先级 `.utility`）
- 关闭时：无清理开销

**UI 行为**:
- 无直接 UI 影响（后台任务）

**日志输出**:
```swift
// HistoryManager.swift 中的清理日志
logger.info("🗑️ Cleanup: removed \(count) items")
```

**兼容性**:
- 默认值 `true` 保持向后兼容
- 关闭后历史记录将无限累积

### 验证方式

**最小复现步骤**:
1. 通过 UserDefaults 修改配置：
   ```bash
   defaults write com.spokeanywhere HistoryAutoCleanupEnabled -bool false
   ```
2. 重启应用
3. 检查日志确认清理任务未执行

**证据路径**:
```bash
# 查看日志
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "HistoryManager"' \
    --style syslog --last 1m | grep "Cleanup"
```

**预期结果**:
- 关闭时：无 "Cleanup" 日志
- 开启时：有 "Cleanup: removed X items" 日志

---

## 2. historyKeepDays

### 基本信息

**类型**: `Int`
**默认值**: `30`
**配置位置**: `spoke/Services/AppSettings.swift:110`
**持久化**: UserDefaults (`HistoryKeepDays`)

### 读取入口

**主要读取点**: `spoke/App/AppDelegate.swift:237-238`

```swift
// AppDelegate.swift:237-238
if settings.historyKeepDays > 0 {
    await HistoryManager.shared.performCleanup(policy: .keepDays(settings.historyKeepDays))
}
```

### 写入入口

**UI 入口**: **未实现**

**当前状态**:
- 配置项仅可通过 UserDefaults 手动修改
- 预期使用 `Stepper` 或 `TextField` 控件

**预期 UI 位置**: `spoke/UI/Settings/HistorySettingsContent.swift`（待实现）

**预期响应逻辑**:
1. 用户在设置界面调整数值
2. SwiftUI 绑定自动更新 `AppSettings.shared.historyKeepDays`
3. `@AppStorage` 自动保存到 UserDefaults
4. 下次应用启动时生效

### 生效时机

**启动时生效** - 应用启动时根据此值执行清理

**生效流程**:
1. 应用启动，`performHistoryCleanup()` 被调用
2. 检查 `settings.historyAutoCleanupEnabled` 是否为 `true`
3. 检查 `settings.historyKeepDays` 是否大于 0
4. 如果满足条件，调用 `HistoryManager.shared.performCleanup(policy: .keepDays(days))`
5. 删除创建时间早于 `days` 天前的历史记录

### 依赖与联动

**前置依赖**:
- `historyAutoCleanupEnabled` 必须为 `true`（否则此配置无效）
- `HistoryManager` 必须已配置

**跨模块影响**:
- 影响 `HistoryManager.performCleanup()` 的清理策略
- 影响历史记录的保留时长

**关联配置**:
- `historyAutoCleanupEnabled`: 清理总开关（前置依赖）
- `historyMaxCount`: 另一个清理策略（独立）

### 副作用与回退

**性能影响**:
- 数值越小：清理越频繁，保留记录越少
- 数值越大：清理越少，保留记录越多
- 特殊值 `0`：禁用按天数清理

**UI 行为**:
- 无直接 UI 影响（后台任务）

**日志输出**:
```swift
// HistoryManager.swift 中的清理日志
logger.info("🗑️ Cleanup: removed \(count) items older than \(days) days")
```

**兼容性**:
- 默认值 `30` 天平衡存储和可用性
- 设置为 `0` 可禁用按天数清理

### 验证方式

**最小复现步骤**:
1. 通过 UserDefaults 修改配置：
   ```bash
   defaults write com.spokeanywhere HistoryKeepDays -int 7
   ```
2. 重启应用
3. 检查日志确认清理策略

**证据路径**:
```bash
# 查看日志
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "HistoryManager"' \
    --style syslog --last 1m | grep "Cleanup"
```

**预期结果**:
- 设置为 7：删除 7 天前的记录
- 设置为 0：不执行按天数清理

---

## 3. historyMaxCount

### 基本信息

**类型**: `Int`
**默认值**: `500`
**配置位置**: `spoke/Services/AppSettings.swift:113`
**持久化**: UserDefaults (`HistoryMaxCount`)

### 读取入口

**主要读取点**: `spoke/App/AppDelegate.swift:242-243`

```swift
// AppDelegate.swift:242-243
if settings.historyMaxCount > 0 {
    await HistoryManager.shared.performCleanup(policy: .keepCount(settings.historyMaxCount))
}
```

### 写入入口

**UI 入口**: **未实现**

**当前状态**:
- 配置项仅可通过 UserDefaults 手动修改
- 预期使用 `Stepper` 或 `TextField` 控件

**预期 UI 位置**: `spoke/UI/Settings/HistorySettingsContent.swift`（待实现）

**预期响应逻辑**:
1. 用户在设置界面调整数值
2. SwiftUI 绑定自动更新 `AppSettings.shared.historyMaxCount`
3. `@AppStorage` 自动保存到 UserDefaults
4. 下次应用启动时生效

### 生效时机

**启动时生效** - 应用启动时根据此值执行清理

**生效流程**:
1. 应用启动，`performHistoryCleanup()` 被调用
2. 检查 `settings.historyAutoCleanupEnabled` 是否为 `true`
3. 检查 `settings.historyMaxCount` 是否大于 0
4. 如果满足条件，调用 `HistoryManager.shared.performCleanup(policy: .keepCount(count))`
5. 保留最新的 `count` 条记录，删除更早的记录

### 依赖与联动

**前置依赖**:
- `historyAutoCleanupEnabled` 必须为 `true`（否则此配置无效）
- `HistoryManager` 必须已配置

**跨模块影响**:
- 影响 `HistoryManager.performCleanup()` 的清理策略
- 影响历史记录的最大数量

**关联配置**:
- `historyAutoCleanupEnabled`: 清理总开关（前置依赖）
- `historyKeepDays`: 另一个清理策略（独立）

### 副作用与回退

**性能影响**:
- 数值越小：清理越频繁，保留记录越少
- 数值越大：清理越少，保留记录越多
- 特殊值 `0`：禁用按数量清理（不限制）

**UI 行为**:
- 无直接 UI 影响（后台任务）

**日志输出**:
```swift
// HistoryManager.swift 中的清理日志
logger.info("🗑️ Cleanup: removed \(count) items, keeping latest \(maxCount)")
```

**兼容性**:
- 默认值 `500` 条平衡存储和可用性
- 设置为 `0` 表示不限制数量

### 验证方式

**最小复现步骤**:
1. 通过 UserDefaults 修改配置：
   ```bash
   defaults write com.spokeanywhere HistoryMaxCount -int 100
   ```
2. 重启应用
3. 检查日志确认清理策略

**证据路径**:
```bash
# 查看日志
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "HistoryManager"' \
    --style syslog --last 1m | grep "Cleanup"
```

**预期结果**:
- 设置为 100：保留最新 100 条记录
- 设置为 0：不限制数量

---

## 配置依赖关系图

```
应用启动
│
└─ historyAutoCleanupEnabled = true
   │
   ├─ historyKeepDays > 0
   │  └─ HistoryManager.performCleanup(policy: .keepDays(days))
   │     └─ 删除 days 天前的记录
   │
   └─ historyMaxCount > 0
      └─ HistoryManager.performCleanup(policy: .keepCount(count))
         └─ 保留最新 count 条记录
```

---

## 常见问题

### Q1: 为什么 UI 未实现？

**A**: 当前版本优先实现核心功能，配置项已定义并可通过 UserDefaults 修改。UI 控件将在后续版本中添加到 `HistorySettingsContent.swift`。

### Q2: historyKeepDays 和 historyMaxCount 可以同时生效吗？

**A**: 可以。两个策略独立执行，先按天数清理，再按数量清理。最终保留的是同时满足两个条件的记录。

### Q3: 如何禁用某个清理策略？

**A**: 将对应配置项设置为 `0`：
- `historyKeepDays = 0`：禁用按天数清理
- `historyMaxCount = 0`：禁用按数量清理

### Q4: 清理任务何时执行？

**A**: 仅在应用启动时执行一次。运行期间不会自动清理。

### Q5: 如何验证配置是否生效？

**A**: 查看日志中的 `Cleanup` 关键字，或检查历史记录数量是否符合预期。

---

## 相关文档

- [配置索引](./configuration-index.md)
- [功能流视图](./ui-ux-optimization-feature-flow.md)
- [History Manager 设计文档](../design-history.md)（如存在）
