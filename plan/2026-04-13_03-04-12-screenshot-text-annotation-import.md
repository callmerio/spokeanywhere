---
mode: plan
cwd: /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere
task: screenshot text annotation 迁移登记（superpowers -> repo GSD）
complexity: medium
created_at: 2026-04-13T03:04:12+08:00
---

# Plan: Screenshot Text Annotation 迁移登记

## Goal
- 将 superpowers 体系中的截图文字标注需求、实现计划、执行状态与验证证据迁移为仓库当前使用的 repo-native GSD 记录，确保后续 ship/merge 前有统一可追溯入口。

## Scope
- In:
  - 导入 `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md` 的需求范围与边界
  - 导入 `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md` 的任务拆分、文件清单与验证命令
  - 导入外部分支 `codex/screenshot-text-annotation` 的执行过程、提交链与验证状态
  - 在 `ROADMAP.md` 中增加一条“Imported External Execution Record”以解决 traceability 缺口
- Out:
  - 不改变当前 `PROJECT.md` / `ROADMAP.md` 的 feature freeze 约束
  - 不把“文本贴屏 / 桌面浮动文字”并入本条计划
  - 不在本计划中直接 merge、push 或创建 PR

## Assumptions / Dependencies
- 当前仓库没有 `.planning/` 结构，迁移目标采用仓库既有的 `plan/ + issues/ + ROADMAP.md + docs/memo/` 记录方式。
- 本计划属于历史补录 / 外部执行导入，不等于当前 roadmap 已批准新的 feature lane。
- 外部分支仍需清理 ship blocker（当前已知：`.serena/project.yml` 脏改动）。

## Phases
1. 盘点并冻结 superpowers 源产物：design spec、implementation plan、worktree 分支、变更文件与提交链。
2. 生成 repo-native GSD 计划与 issue CSV，承接需求、任务拆分与状态记录。
3. 补一份 imported execution summary，固化 review gate、fresh verification 与当前 blocker。
4. 在 `ROADMAP.md` 增加 traceability 入口，明确这是 imported external execution，不改变当前 feature freeze。

## Tests & Verification
- superpowers scope 与排除项能在迁移记录中被准确复述 -> 对照 design spec 抽检
- task/commit/file inventory 能在迁移记录中找到 -> 对照 implementation plan 与 branch diff 抽检
- `plan/` 与 `issues/` 文件名时间戳/slug 对齐 -> 文件名检查
- `ROADMAP.md` 新增条目明确说明“traceability only / does not unfreeze scope” -> 文本检查

## Issue CSV
- Path: `issues/2026-04-13_03-04-12-screenshot-text-annotation-import.csv`
- Must share the same timestamp/slug as this plan.

## Tools / MCP
- `ace-tool search_context`：汇总 superpowers 与 repo-native 规划痕迹
- `read_file` / `grep`：读取模板、spec、plan、ROADMAP 与 issue CSV 样式
- `shell`：枚举 worktree、branch diff、提交链与文件清单

## Acceptance Checklist
- [ ] 迁移计划文件已落到 `plan/`
- [ ] 对应 issue CSV 已落到 `issues/`
- [ ] imported execution summary 已落到 `docs/memo/`
- [ ] `ROADMAP.md` 已新增 imported external execution traceability 条目
- [ ] 迁移记录明确区分“截图文字标注”与“文本贴屏 / 桌面浮动文字”
- [ ] 迁移记录显式标出当前 freeze/ship blocker

## Risks / Blockers
- 当前 `PROJECT.md` 与 `ROADMAP.md` 仍将“新 UI/API feature”列为冻结项，若不标记 exception，会造成历史记录与主路线冲突。
- 若直接 ship 外部分支而不清理 `.serena/project.yml`，会把环境噪音一并带入交付。
- “文本贴屏 / 桌面浮动文字”尚无独立 spec，不应借本记录偷渡进当前范围。

## Rollback / Recovery
- 若迁移记录口径不准确，可删除本次新增的 `plan/`、`issues/`、`docs/memo/` 文件并回退 `ROADMAP.md`。
- 迁移只改文档，不影响应用运行态与源码逻辑。

## Checkpoints
- Commit after: plan + issue CSV + memo summary 初稿落盘
- Commit after: ROADMAP traceability 条目补齐并自检通过

## References
- `PROJECT.md:12`
- `PROJECT.md:14`
- `ROADMAP.md:28`
- `ROADMAP.md:36`
- `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md:1`
- `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md:6`
- `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md:67`
- `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md:613`
- `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md:1`
- `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md:5`
- `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md:48`
- `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md:257`
- `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md:531`
