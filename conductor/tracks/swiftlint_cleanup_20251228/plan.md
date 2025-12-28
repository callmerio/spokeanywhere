# SwiftLint 全仓清理 Plan

> Track Type: **Chore** (代码重构，无功能变更)
> Created: 2025-12-28T08:24:02+08:00

---

## Checklist

### Task 1: 自动修复 (Auto-fix)
- [ ] 1.1 备份当前状态 (`git stash` 或确认工作区干净)
- [ ] 1.2 执行 `swiftlint --fix --config .swiftlint.yml`
- [ ] 1.3 验证编译 `swift build`
- [ ] 1.4 统计剩余违规数
- [ ] 1.5 提交 `git commit -m "chore: SwiftLint auto-fix"`

### Task 2: 手动修复 - 简单规则
- [ ] 2.1 修复 `sorted_imports` 残余 (如有)
- [ ] 2.2 修复 `trailing_comma`
- [ ] 2.3 修复 `vertical_whitespace` / `vertical_whitespace_closing_braces`
- [ ] 2.4 修复 `redundant_discardable_let` (`let _ =` → `_ =`)
- [ ] 2.5 修复 `identifier_name` (变量名 a/b/e → 有意义名称)
- [ ] 2.6 验证编译
- [ ] 2.7 提交 `git commit -m "chore: SwiftLint manual fix - simple rules"`

### Task 3: 修复 Force Cast
- [ ] 3.1 `SelectionMonitorService.swift` - 8 处 `as!`
- [ ] 3.2 `DictionarySelectableText.swift` - 1 处 `as!`
- [ ] 3.3 验证编译
- [ ] 3.4 提交 `git commit -m "chore: replace force_cast with safe unwrapping"`

### Task 4: 修复 Multiple Closures with Trailing Closure
- [ ] 4.1 `DictionarySettingsView.swift` - 11 处
- [ ] 4.2 `TranscriptionModelSettingsView.swift` - 1 处
- [ ] 4.3 `DictionarySelectableText.swift` - 2 处
- [ ] 4.4 验证编译
- [ ] 4.5 提交 `git commit -m "chore: fix multiple_closures_with_trailing_closure"`

### Task 5: 重构超长文件 (可选 - 评估风险后决定)
- [ ] 5.1 评估 `DictionarySettingsView.swift` 拆分方案
- [ ] 5.2 评估 `SelectionMonitorService.swift` 拆分方案
- [ ] 5.3 如风险可控：执行拆分
- [ ] 5.4 验证编译
- [ ] 5.5 提交 (如执行)

### Task 6: 降低复杂函数圈复杂度 (可选)
- [ ] 6.1 评估 `SelectionMonitorService.swift:570` 重构方案
- [ ] 6.2 评估 `LocalDictionaryService.swift:187` 重构方案
- [ ] 6.3 如风险可控：执行重构
- [ ] 6.4 验证编译
- [ ] 6.5 提交 (如执行)

### Task 7: 最终验证
- [ ] 7.1 执行 `swiftlint lint --config .swiftlint.yml`
- [ ] 7.2 确认输出 "Found 0 violations" 或记录剩余违规
- [ ] 7.3 执行完整编译 `swift build`
- [ ] 7.4 更新 issues CSV 状态
- [ ] 7.5 更新 `docs/memo/memory.csv` 记录

---

## Progress Tracking

| Task | 状态 | 备注 |
|------|------|------|
| Task 1 | ⬜ Pending | - |
| Task 2 | ⬜ Pending | - |
| Task 3 | ⬜ Pending | - |
| Task 4 | ⬜ Pending | - |
| Task 5 | ⬜ Pending | 可选，视风险评估 |
| Task 6 | ⬜ Pending | 可选，视风险评估 |
| Task 7 | ⬜ Pending | - |

---

## Notes

- Task 1-4 为必做项，预计可解决 80%+ 违规
- Task 5-6 涉及较大重构，建议单独评估
- 每个 Task 后验证编译，确保无回归
