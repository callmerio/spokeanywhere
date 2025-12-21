---
trigger: model_decision
description: 当执行 Conductor 框架任务时加载，提供 TDD 标准流程、Commit 规范、Phase 验证协议等核心规则约束。
---

# Conductor Workflow Rules

当执行 Conductor 相关任务时，必须遵循以下规则。

## 核心原则

1. **Plan 是唯一真理源**: 所有工作必须在 `plan.md` 中跟踪
2. **Tech Stack 是刻意选择**: 技术栈变更必须先更新 `tech-stack.md` 再实现
3. **测试驱动开发**: 先写单元测试再实现功能
4. **高代码覆盖率**: 所有模块目标 >80% 覆盖率
5. **用户体验优先**: 每个决策都应优先考虑用户体验
6. **非交互式 & CI 感知**: 优先使用非交互式命令，对 watch 模式工具使用 `CI=true`

## 任务状态标记

- `[ ]` - 待处理 (Pending)
- `[~]` - 进行中 (In Progress)
- `[x]` - 已完成 (Completed)

## TDD 标准流程

1. **选择任务**: 从 `plan.md` 按顺序选择下一个任务
2. **标记进行中**: `[ ]` → `[~]`
3. **写失败测试 (Red)**: 创建测试文件，定义预期行为，确认测试失败
4. **实现至通过 (Green)**: 写最少代码让测试通过
5. **重构 (Refactor)**: 在测试保护下优化代码
6. **验证覆盖率**: 运行覆盖率报告，确保 >80%
7. **提交代码**: 使用语义化 commit message
8. **附加 Git Note**: 记录任务摘要到 commit
9. **更新 Plan**: `[~]` → `[x]` 并附加 commit SHA

## Commit Message 格式

```
<type>(<scope>): <description>

[optional body]
[optional footer]
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Phase 完成验证协议

每个 Phase 结束时：

1. 确保所有 Phase 内文件有对应测试
2. 执行自动化测试（最多重试 2 次）
3. 提供手动验证计划
4. 等待用户确认
5. 创建 Checkpoint Commit
6. 附加验证报告到 Git Note

## Quality Gates

任务完成前必须确认：

- [ ] 所有测试通过
- [ ] 代码覆盖率达标 (>80%)
- [ ] 遵循代码风格指南
- [ ] 公共函数/方法有文档
- [ ] 类型安全
- [ ] 无 lint/静态分析错误
- [ ] 移动端正常工作 (如适用)
- [ ] 无安全漏洞

## 源文件参考

完整 Workflow 定义见: `/Users/bigdan/prompt/vendor/conductor/templates/workflow.md`
