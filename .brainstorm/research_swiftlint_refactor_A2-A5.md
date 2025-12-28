# Research Summary: SwiftLint Baseline Convergence A2-A5

## 📁 Code Context (15 items)

### 目标文件分析
1. `spoke/UI/Settings/DictionarySettingsView.swift:11` - **1537 行**，包含 `DictionarySettingsContent` 主视图及多个子组件
2. `spoke/UI/LiveCaption/LiveCaptionView.swift:1` - **1098 行**，包含 `AppKitScrollView` (NSScrollView 桥接) + `LiveCaptionView` 主视图
3. `spoke/UI/Components/DictionarySelectableText.swift:118` - **790 行**，包含 `SimpleMarkdownParser` + `DictionarySelectableText` + 多个辅助类

### 当前 SwiftLint 状态
4. **SwiftLint 结果**: 三个目标文件均已 0 violations (可能已使用 `// swiftlint:disable` 抑制)
5. `DictionarySettingsView.swift:1` - 包含 `// swiftlint:disable file_length` 暂时抑制

### 相关的 Issue CSV 定义
6. **A2**: DictionarySettingsContent lint refactor and split - 拆分子视图
7. **A3**: LiveCaptionView lint refactor and split - 拆分子视图
8. **A4**: DictionarySelectableText lint refactor - 减少复杂度
9. **A5**: Cross-module cleanup and verification - 最终验证

### 历史经验 (memory.csv)
10. `memory.csv:173` - PerformanceTracer 调试发现 DictionarySelectableText.updateNSView 性能问题，字体缓存解决
11. `memory.csv:107` - layout() 中调用 invalidateIntrinsicContentSize() 导致递归警告
12. `memory.csv:109` - updateNSView 内容变化检查避免重复解析

## 📜 Memory Context

已检查 `docs/memo/memory.csv`，相关条目：
- SwiftUI 视图拆分应避免破坏状态管理
- NSViewRepresentable 的 Coordinator 模式需保持一致
- 字体缓存机制 (`fontCache`) 必须保留

## 🌐 External Research (14 items)

### 1. SwiftUI View 重构最佳实践
- **来源**: medium.com, kodeco.com, swiftbysundell.com
- **核心洞察**: 
  - 提取子视图 (Extract Subviews) 是最基本的实践
  - 200 行以上的视图文件应考虑拆分
  - 使用 MVVM 分离业务逻辑到 ViewModel

### 2. SwiftLint file_length 修复策略
- **来源**: avanderlee.com, stackoverflow.com
- **核心洞察**:
  - 拆分为多个小文件，先移动代码不改逻辑
  - 使用 extension 分组相关方法
  - 配置阈值作为临时方案

### 3. NSViewRepresentable 代码组织模式
- **来源**: apple.com, medium.com
- **核心洞察**:
  - Coordinator 类作为 delegate 处理回调
  - 属性声明 → makeNSView → updateNSView → Coordinator 的标准结构
  - 保持 Coordinator 内聚性

### 4. SwiftUI 提取子视图的性能影响
- **来源**: dev.to, canopas.com, apple.com
- **核心洞察**:
  - 提取子视图**提高**性能（减少不必要的重新计算）
  - 避免过度使用 AnyView
  - 注意 @State 和 @ObservedObject 的正确使用

### 5. Swift Extension 文件组织模式
- **来源**: medium.com, stackademic.com
- **核心洞察**:
  - 命名规范: `MyType+Feature.swift`
  - 每个 extension 专注单一职责
  - 拆分对 bundle 大小无影响

### 6. macOS SwiftUI NSTextView Coordinator 模式
- **来源**: github.com, bluelemonbits.com
- **核心洞察**:
  - Coordinator 继承 NSObject + NSTextViewDelegate
  - textDidChange/textViewDidChangeSelection 关键方法
  - @Binding 属性实现双向数据流

### 7. MVVM ViewModel 拆分策略
- **来源**: zthh.dev, swiftanytime.com
- **核心洞察**:
  - 分解为 sub-ViewModel
  - 单一职责原则 (SRP)
  - 依赖注入提高可测试性

## 💡 Key Takeaways

### 拆分策略
1. **DictionarySettingsContent**: 按功能区拆分为独立子视图组件
   - `headerSection` → 独立文件
   - `filterAndSearchSection` → 独立文件
   - Sheet 组件 → 独立文件
   
2. **LiveCaptionView**: 按层拆分
   - `AppKitScrollView` → 独立文件 (已是独立 struct)
   - 设计常量 `CaptionDesign` → 独立文件
   - 子视图组件 → 按功能拆分

3. **DictionarySelectableText**: 按类型拆分
   - `SimpleMarkdownParser` → 独立文件
   - `SelectionColorLayoutManager` → 独立文件
   - `DictionaryTextView` → 独立文件

### 风险控制
- 保持现有 UI 行为不变
- 继续使用 DesignTokens
- 保持 fontCache 等性能优化
- 保持 Coordinator 模式一致性

### 验证标准
- SwiftLint 0 warnings (移除 disable 注释后)
- swift build 通过
- 目标视图手工 UI 抽检
