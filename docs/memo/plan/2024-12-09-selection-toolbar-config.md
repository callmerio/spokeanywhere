# 选择工具栏可配置化设计

## 1. 背景

### 当前架构

```
┌─────────────────────────────────────────────────────────────────┐
│                     SelectionToolbarView                         │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐                                │
│  │朗读 │ │查询 │ │翻译 │ │总结 │  ← 硬编码 enabledActions 数组   │
│  └─────┘ └─────┘ └─────┘ └─────┘                                │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  SelectionToolbarActionType (enum)                               │
│  - speak / lookup / translate / summarize / copy                 │
│  - 固定5种，无法扩展                                              │
└─────────────────────────────────────────────────────────────────┘
```

**问题**：

1. 按钮种类固定，用户无法自定义技能
2. 按钮顺序固定，无法拖拽排序
3. 全部显示在主栏，无下拉菜单收纳
4. 配置未持久化（`loadConfig`/`saveConfig` 是空 TODO）

### 目标架构

```
┌─────────────────────────────────────────────────────────────────┐
│                     SelectionToolbarView                         │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌───┐                  │
│  │朗读 │ │伴读 │ │搜索 │ │翻译 │ │总结 │ │ ⌄ │ ← 下拉菜单按钮   │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └───┘                  │
│                                              │                   │
│                                              ▼                   │
│                                    ┌──────────────┐              │
│                                    │ 📋 复制      │              │
│                                    │ ❓ 解释      │              │
│                                    │ ────────     │              │
│                                    │ ⚙️ 自定义    │              │
│                                    └──────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  ToolbarAction (struct, Codable)                                 │
│  - id: UUID / builtinId                                          │
│  - name: String                                                  │
│  - icon: String (SF Symbol / Emoji)                              │
│  - type: .builtin(ActionType) / .custom(prompt: String)          │
│  - isEnabled: Bool                                               │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  ToolbarConfigService                                            │
│  - actions: [ToolbarAction] (有序列表)                           │
│  - visibleCount: Int = 5 (前N个显示主栏)                         │
│  - isEnabled: Bool (全局开关)                                    │
│  - 持久化: UserDefaults / JSON 文件                              │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Settings → ToolbarSettingsView                                  │
│  - 工具栏预览                                                    │
│  - 全局开关                                                      │
│  - 技能列表 (拖拽排序 + hover 删除/编辑)                          │
│  - 添加技能弹窗 (名称 + 图标 + 提示词模板)                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 方案选型

| 方案                    | 描述                                                            | 优点                       | 缺点                              |
| ----------------------- | --------------------------------------------------------------- | -------------------------- | --------------------------------- |
| **A. 扩展现有 enum**    | 在 `SelectionToolbarActionType` 添加 `.custom(id, prompt)` case | 改动小                     | enum 不适合动态数据；Codable 复杂 |
| **B. 新建 struct 模型** | `ToolbarAction` struct，内置和自定义统一                        | 灵活；易扩展；Codable 简单 | 需要迁移现有代码                  |
| **C. 协议抽象**         | `ToolbarActionProtocol`，内置和自定义分别实现                   | 类型安全                   | 过度设计；存储复杂                |

**选择：方案 B**

- 统一数据模型，简化逻辑
- struct + Codable 天然支持 JSON 持久化
- 内置动作用 `.builtin(type)` 包装，保留原有执行逻辑

---

## 3. 详细设计变更

### 3.1 新建文件

| 文件路径                                    | 操作 | 说明              |
| ------------------------------------------- | ---- | ----------------- |
| `Core/SelectionToolbar/ToolbarAction.swift` | 新建 | 统一动作模型      |
| `Services/ToolbarConfigService.swift`       | 新建 | 配置管理 + 持久化 |
| `UI/Settings/ToolbarSettingsView.swift`     | 新建 | 设置页面 UI       |

### 3.2 修改文件

| 文件路径                                                  | 操作 | 说明                             |
| --------------------------------------------------------- | ---- | -------------------------------- |
| `Core/SelectionToolbar/SelectionToolbarState.swift:24-42` | 修改 | Config 引用 ToolbarConfigService |
| `UI/SelectionToolbar/SelectionToolbarView.swift:28-57`    | 修改 | 添加下拉菜单按钮                 |
| `Services/SelectionActionService.swift:54-88`             | 修改 | 支持执行自定义动作               |
| `UI/Settings/SettingsView.swift`                          | 修改 | 添加工具栏设置 Tab               |

---

### 3.3 核心代码设计

#### 3.3.1 ToolbarAction.swift

```swift
// Core/SelectionToolbar/ToolbarAction.swift

import SwiftUI

/// 工具栏动作类型
enum ToolbarActionKind: Codable, Equatable {
    /// 内置动作
    case builtin(SelectionToolbarActionType)
    /// 自定义动作 (提示词模板)
    case custom(prompt: String)
}

/// 工具栏动作 (统一模型)
struct ToolbarAction: Identifiable, Codable, Equatable {
    /// 唯一 ID
    let id: String
    /// 显示名称
    var name: String
    /// 图标 (SF Symbol 名称或 Emoji)
    var icon: String
    /// 图标颜色 (Hex)
    var iconColorHex: String
    /// 动作类型
    var kind: ToolbarActionKind
    /// 是否启用
    var isEnabled: Bool = true

    // MARK: - 便捷属性

    /// 是否为内置动作
    var isBuiltin: Bool {
        if case .builtin = kind { return true }
        return false
    }

    /// 图标颜色
    var iconColor: Color {
        Color(hex: iconColorHex) ?? .gray
    }

    // MARK: - 内置动作工厂方法

    static func builtin(_ type: SelectionToolbarActionType) -> ToolbarAction {
        ToolbarAction(
            id: "builtin.\(type.rawValue)",
            name: type.displayName,
            icon: type.iconName,
            iconColorHex: type.iconColor.toHex() ?? "#808080",
            kind: .builtin(type)
        )
    }

    /// 默认动作列表
    static let defaults: [ToolbarAction] = [
        .builtin(.speak),
        .builtin(.lookup),
        .builtin(.translate),
        .builtin(.summarize),
        .builtin(.copy)
    ]
}
```

#### 3.3.2 ToolbarConfigService.swift

```swift
// Services/ToolbarConfigService.swift

import Foundation
import Combine

@MainActor
final class ToolbarConfigService: ObservableObject {
    static let shared = ToolbarConfigService()

    // MARK: - Published

    /// 动作列表 (有序)
    @Published var actions: [ToolbarAction] = []

    /// 主栏显示数量 (前N个)
    @Published var visibleCount: Int = 5

    /// 全局开关
    @Published var isEnabled: Bool = true

    // MARK: - Computed

    /// 主栏显示的动作
    var visibleActions: [ToolbarAction] {
        Array(actions.filter(\.isEnabled).prefix(visibleCount))
    }

    /// 下拉菜单中的动作
    var menuActions: [ToolbarAction] {
        Array(actions.filter(\.isEnabled).dropFirst(visibleCount))
    }

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - Persistence

    private let storageKey = "toolbar.config.v1"

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(StoredConfig.self, from: data) else {
            // 首次使用，加载默认配置
            actions = ToolbarAction.defaults
            return
        }
        actions = config.actions
        visibleCount = config.visibleCount
        isEnabled = config.isEnabled
    }

    func save() {
        let config = StoredConfig(actions: actions, visibleCount: visibleCount, isEnabled: isEnabled)
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - CRUD

    func addAction(_ action: ToolbarAction) {
        actions.append(action)
        save()
    }

    func removeAction(id: String) {
        actions.removeAll { $0.id == id }
        save()
    }

    func moveAction(from: IndexSet, to: Int) {
        actions.move(fromOffsets: from, toOffset: to)
        save()
    }

    func updateAction(_ action: ToolbarAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index] = action
            save()
        }
    }
}

// MARK: - Storage Model

private struct StoredConfig: Codable {
    let actions: [ToolbarAction]
    let visibleCount: Int
    let isEnabled: Bool
}
```

#### 3.3.3 SelectionToolbarView 修改

```swift
// ❌ 旧代码 (SelectionToolbarView.swift:31-44)
var body: some View {
    HStack(spacing: ToolbarLayout.spacing) {
        ForEach(Array(state.config.enabledActions.enumerated()), id: \.element) { index, action in
            // ...
        }
    }
}

// ✅ 新代码
var body: some View {
    HStack(spacing: ToolbarLayout.spacing) {
        // 主栏按钮
        ForEach(Array(configService.visibleActions.enumerated()), id: \.element.id) { index, action in
            if index > 0 {
                ToolbarDivider()
            }
            ToolbarActionButton(action: action) {
                executeAction(action)
            }
        }

        // 下拉菜单按钮
        if !configService.menuActions.isEmpty || true {
            ToolbarDivider()
            ToolbarMenuButton()
        }
    }
    // ... background
}
```

#### 3.3.4 ToolbarSettingsView

```swift
// UI/Settings/ToolbarSettingsView.swift

struct ToolbarSettingsView: View {
    @ObservedObject var configService = ToolbarConfigService.shared
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 预览区
            ToolbarPreviewSection()

            Divider()

            // 全局开关
            Toggle("当选中文本时显示工具栏", isOn: $configService.isEnabled)
                .onChange(of: configService.isEnabled) { _ in
                    configService.save()
                }

            Divider()

            // 技能管理
            HStack {
                VStack(alignment: .leading) {
                    Text("技能管理")
                        .font(.headline)
                    Text("前 \(configService.visibleCount) 个技能将显示在工具栏上，其他的将隐藏在下拉菜单中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("+ 添加技能") {
                    showAddSheet = true
                }
            }

            // 可拖拽列表
            List {
                ForEach(configService.actions) { action in
                    ActionRowView(action: action)
                }
                .onMove { from, to in
                    configService.moveAction(from: from, to: to)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAddSheet) {
            AddActionSheet()
        }
    }
}
```

---

## 4. 测试计划

### 4.1 单元测试

```swift
// Tests/ToolbarConfigServiceTests.swift

final class ToolbarConfigServiceTests: XCTestCase {

    func testDefaultActions() {
        let service = ToolbarConfigService.shared
        XCTAssertEqual(service.actions.count, 5)
        XCTAssertEqual(service.actions[0].name, "朗读")
    }

    func testAddCustomAction() {
        let service = ToolbarConfigService.shared
        let custom = ToolbarAction(
            id: UUID().uuidString,
            name: "解释",
            icon: "questionmark.circle",
            iconColorHex: "#007AFF",
            kind: .custom(prompt: "请解释 {selection}")
        )
        service.addAction(custom)
        XCTAssertTrue(service.actions.contains(where: { $0.name == "解释" }))
    }

    func testMoveAction() {
        let service = ToolbarConfigService.shared
        let firstId = service.actions[0].id
        service.moveAction(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(service.actions[1].id, firstId)
    }

    func testVisibleAndMenuSplit() {
        let service = ToolbarConfigService.shared
        service.visibleCount = 3
        XCTAssertEqual(service.visibleActions.count, 3)
        XCTAssertEqual(service.menuActions.count, service.actions.count - 3)
    }
}
```

### 4.2 UI 测试流程

1. **启动应用** → 选中文本 → 工具栏显示 5 个主按钮 + 下拉菜单
2. **打开设置** → 工具栏 Tab → 预览区显示当前配置
3. **拖拽排序** → 拖动"翻译"到第一位 → 保存 → 工具栏刷新
4. **添加技能** → 填写名称/图标/提示词 → 保存 → 列表更新
5. **删除技能** → hover 显示删除按钮 → 点击 → 确认删除
6. **执行自定义技能** → 选中文本 → 点击自定义技能 → LLM 使用模板处理

---

## 5. 验收标准

| 验收项             | 验证方式       | 预期结果                               |
| ------------------ | -------------- | -------------------------------------- |
| 工具栏显示下拉菜单 | 选中文本       | 主栏 5 个按钮 + ⌄ 菜单按钮             |
| 配置持久化         | 重启应用       | 保持上次配置                           |
| 拖拽排序           | 设置页拖拽     | 顺序变化立即反映到工具栏               |
| 自定义技能执行     | 点击自定义按钮 | LLM 使用 `{selection}` 替换后的 prompt |
| 删除内置动作       | 尝试删除       | 仅禁用不删除 / 可删除但可恢复默认      |

---

## 6. 红队审查修订

| 问题              | 处理                                       |
| ----------------- | ------------------------------------------ |
| ID 命名冲突       | ✅ 自定义动作 id 强制 `custom.{UUID}` 前缀 |
| 配置损坏          | ✅ 解码失败时备份原数据到 `.backup` key    |
| save() 防抖       | ✅ 300ms debounce 减少 I/O                 |
| visibleCount 边界 | ✅ 约束 1-10                               |
| 删除内置动作      | ✅ 内置动作只能禁用 + 添加"恢复默认"       |
| 占位符安全        | ✅ `{selection}` → `{{selection}}`         |
| 空提示词          | ✅ AddActionSheet 添加验证                 |

---

## 7. 执行顺序

```
Phase 1: 数据模型 + 配置服务
├── 1.1 创建 ToolbarAction.swift (含修订)
├── 1.2 创建 ToolbarConfigService.swift (含防抖/备份/约束)
└── 1.3 添加 Color.hex 扩展

Phase 2: UI 改造
├── 2.1 改造 SelectionToolbarView (下拉菜单)
├── 2.2 改造 SelectionActionService (支持 custom + {{selection}})
└── 2.3 更新 SelectionToolbarState 引用

Phase 3: 设置页面
├── 3.1 创建 ToolbarSettingsView
├── 3.2 创建 AddActionSheet (含验证)
├── 3.3 集成到 SettingsView
└── 3.4 实现拖拽排序

Phase 4: 测试 + 收尾
├── 4.1 单元测试
├── 4.2 UI 手动测试
└── 4.3 更新 memory.csv
```
