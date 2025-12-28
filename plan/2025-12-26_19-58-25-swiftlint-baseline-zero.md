---
mode: plan
cwd: /Users/bigdan/Workspace/macos/spokeanywhere
task: SwiftLint baseline zero (all modules)
complexity: complex
tool: mcp__sequential-thinking__sequentialthinking
total_thoughts: 10
created_at: "2025-12-26T20:12:20+08:00"
---

# Plan: SwiftLint 基线收敛（零违规，全模块）

## Goal
- swiftlint 0 violations（含 warning/serious）
- swift build 通过
- 不引入功能行为变更，仅做风格/结构性最小修复

## Scope
- In:
  - 修复所有 swiftlint 规则触发：imports 排序、命名、函数/类型/文件长度、trailing closure、unused 参数、for-where、empty_count 等
  - 必要时进行小规模拆分/提取函数/私有子类型
- Out:
  - 新功能、架构重写、设计改动、规则放宽

## Assumptions / Dependencies
- `.swiftlint.yml` 规则保持不变
- 可运行 `swiftlint` 与 `swift build`
- 允许分批次提交与回滚

## Phases
1. 基线盘点与分桶：按模块（Screenshot / QuickAsk / MessagePanel / Settings / Services+Core / Tests / .deprecated）与规则类型分桶。
2. Screenshot 批次：优先处理 `type_body_length` / `file_length`，拆分/提取私有子类或 extension；补齐 unused 参数、命名、imports 排序。
3. QuickAsk + MessagePanel 批次：拆分大视图/长函数；修复 empty_count、line_length、trailing closure、imports 排序。
4. Settings 批次：拆分大视图到子文件；修复命名短变量、line_length、trailing closure；保持 API 与行为不变。
5. Services + Core 批次：处理复杂度/长函数/force_cast/for-where/排序；必要时抽取 helper。
6. Tests + .deprecated 批次：修复 imports 排序、命名与长度类规则，不改测试逻辑。
7. 全量清零与回归：全仓 swiftlint 0 violations，swift build 通过；关键 UI 手测清单回归。

## Tests & Verification
- swiftlint 全量：`swiftlint --config .swiftlint.yml`
- 编译验证：`cd spoke && swift build`
- 手动回归（若无自动化）：截图选区、QuickAsk 面板、SelectionToolbar 触发与关闭

## Issue CSV
- Path: issues/2025-12-26_19-58-25-swiftlint-baseline-zero.csv
- Must share the same timestamp/slug as this plan.

## Tools / MCP
- shell:rg — 规则触发点快速定位
- shell:swiftlint / shell:swift build — 验证
- serena:search_for_pattern — 批量定位同类违规
- serena:replace_content — 小范围批量修复

## Acceptance Checklist
- [ ] swiftlint 无任何 violation（含 warning/serious）
- [ ] swift build 通过
- [ ] 未放宽/关闭规则
- [ ] 关键模块行为无回归

## Risks / Blockers
- 大文件拆分可能影响组织结构；需保持 public API 与调用路径不变
- 某些违规需要结构性拆分，需严格控制改动范围

## Rollback / Recovery
- 按批次提交；如某批次出现问题，回滚该批次即可

## Checkpoints
- Commit after: 每个模块批次完成（Screenshot / QuickAsk / MessagePanel / Settings / Services+Core / Tests）

## References
- `.swiftlint.yml:1`
- `spoke/UI/MessagePanel/MessagePanelView.swift:1013`
- `spoke/UI/Screenshot/RegionSelectionView.swift:1`
- `spoke/UI/QuickAsk/AnswerPanelView.swift:1`
- `spoke/Services/SelectionMonitorService.swift:1`

## 现状与证据
- `spoke/UI/MessagePanel/MessagePanelView.swift:1013` 触发 `empty_count` 规则
- `spoke/UI/Screenshot/RegionSelectionView.swift:1` 触发 `type_body_length` 规则
- `spoke/UI/QuickAsk/AnswerPanelView.swift:1` 触发 `file_length` / `type_body_length` 规则

## 测试与验证路径
- `swiftlint --config .swiftlint.yml`
- `cd spoke && swift build`
- 手动检查：截图选区、QuickAsk、SelectionToolbar
