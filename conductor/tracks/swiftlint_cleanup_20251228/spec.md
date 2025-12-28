# SwiftLint 全仓清理 Spec

## Overview

对 SpokenAnyWhere 项目执行 SwiftLint 全仓清理，目标是达到零违规状态。当前共有 **273 个违规**，主要集中在 Services/Core 模块 (66%)。

## Background

- SwiftLint 版本: 0.62.2
- 配置文件: `.swiftlint.yml` (118 行)
- 违规分布:
  | 模块 | 违规数 | 占比 |
  |------|--------|------|
  | Services + Core | 180 | 66% |
  | Settings UI | 27 | 10% |
  | LiveCaption | 20 | 7% |
  | Components | 6 | 2% |
  | Screenshot / QuickAsk | 0 | 0% ✅ |

## Requirements

### R1: 自动修复可修复规则
- 使用 `swiftlint --fix` 自动修复简单违规
- 覆盖规则: `sorted_imports`, `trailing_comma`, `vertical_whitespace`, `redundant_discardable_let`

### R2: 修复 Force Cast 违规
- 将 `as!` 替换为 `as?` + `guard let` / `if let`
- 主要文件: `SelectionMonitorService.swift`, `DictionarySelectableText.swift`

### R3: 修复 Multiple Closures 违规
- 将 trailing closure 语法改为显式参数标签
- 主要文件: `DictionarySettingsView.swift`, `TranscriptionModelSettingsView.swift`

### R4: 重构超长文件/函数
- `DictionarySettingsView.swift` (1197 行) → 拆分为多个文件
- `SelectionMonitorService.swift` (562 行) → 使用 extension 分离
- 超长函数 → 使用 `private` helper 函数拆分

### R5: 降低圈复杂度
- `SelectionMonitorService.swift:570` (复杂度 27)
- `LocalDictionaryService.swift:187` (复杂度 20)
- 使用 guard 早退出、提取子函数

## Acceptance Criteria

1. `swiftlint lint --config .swiftlint.yml` 输出 "Found 0 violations"
2. `swift build` 编译通过，无新增警告
3. 无功能回归（代码行为不变）
4. 每个 Phase 完成后提交一次 git commit

## Out of Scope

- 不修改 `.swiftlint.yml` 规则阈值
- 不新增功能
- 不删除功能代码
- 不重构非违规代码

## Risks

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 重构引入 bug | 高 | 逐步提交，每步编译验证 |
| 破坏 extension 跨文件访问 | 中 | 关注访问修饰符 |
| 超时（任务量大） | 低 | 分 Phase 执行 |

## References

- `.brainstorm/research_summary.md` - 研究摘要
- `issues/2025-12-26_19-58-25-swiftlint-baseline-zero.csv` - 原始任务定义
