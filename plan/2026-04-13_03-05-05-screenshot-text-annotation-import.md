---
mode: plan
cwd: /Volumes/1TBSSD/offload/Workspace/macos/spokeanywhere
task: 导入 screenshot text annotation 执行记录（superpowers → repo GSD）
complexity: medium
created_at: 2026-04-13T03:05:05+0800
---

# Plan: 导入 screenshot text annotation 执行记录

## Goal
- 将 `docs/superpowers/` 与独立 worktree 中已经完成的 screenshot text annotation 工作迁移为仓库当前采用的 repo-native GSD 记录。
- 为后续 ship/merge 提供可追溯的需求、执行、验证与例外说明，而不强行引入当前仓库并未启用的 `.planning/` 体系。

## Scope
- In:
  - 盘点 superpowers 侧需求 spec、实现 plan、执行提交链与验证结果。
  - 生成 repo-native GSD 计划文件与 issue CSV。
  - 生成一份执行导入报告，记录 commit chain、变更文件、验证结果与 ship blocker。
  - 在 `ROADMAP.md` 中补一条 imported execution / freeze exception 记录。
- Out:
  - 不修改 screenshot text annotation 功能代码。
  - 不直接 ship、push 或创建 PR。
  - 不把“文本贴屏 / 桌面浮动文字”混入本次导入。
  - 不创建 `.planning/phases/*` 结构。

## Assumptions / Dependencies
- superpowers 原始产物仍可作为事实来源：
  - `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md`
  - `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md`
- 执行分支仍可访问：`codex/screenshot-text-annotation`
- 当前仓库的规划真源是 `PROJECT.md + ROADMAP.md + plan/ + issues/`，而不是 `.planning/`。
- 当前 `PROJECT.md` / `ROADMAP.md` 仍处于 feature freeze 口径，因此本次记录必须显式标注为 imported execution / exception。

## Phases
1. 盘点 source artifacts 与约束冲突
2. 生成 repo-native GSD 计划与 issue CSV
3. 写入执行导入报告与 roadmap exception 记录
4. 给出 ship 前置条件与后续动作

## Tests & Verification
- superpowers spec 与 implementation plan 路径存在且可读取 -> 手工核对路径
- `codex/screenshot-text-annotation` 相对 `main` 的变更文件清单可导出 -> `git diff --name-only main...HEAD`
- commit chain 可回放 -> `git log --reverse --oneline main..HEAD`
- 仓库内生成的 `plan/`、`issues/`、`docs/reports/` 记录互相引用一致 -> 手工检查
- `ROADMAP.md` 中新增 imported execution 记录且不破坏当前 freeze 口径 -> 手工检查

## Issue CSV
- Path: `issues/2026-04-13_03-05-05-screenshot-text-annotation-import.csv`
- Must share the same timestamp/slug as this plan.

## Tools / MCP
- `ace-tool.search_context`：盘点规划结构与冲突
- `read_file` / `grep`：读取 superpowers 计划、spec 与终端执行痕迹
- `shell`：导出 commit chain、branch diff、worktree 状态
- `edit_file`：写入 repo-native GSD 记录

## Acceptance Checklist
- [x] 找到 screenshot text annotation 的需求、实现计划、执行链与验证结果
- [x] 生成一份 repo-native `plan/` 记录
- [x] 生成对应 `issues/` CSV 记录
- [x] 生成执行导入报告，覆盖 commit chain、变更范围、验证与 blocker
- [x] 在 `ROADMAP.md` 中追加 imported execution / freeze exception 说明
- [x] 明确将“文本贴屏 / 桌面浮动文字”排除为独立待立项需求

## Risks / Blockers
- 当前 `PROJECT.md` 明确禁止新增 UI/API feature，本条记录只能作为 imported execution / exception，不能伪装成当前主路线原生任务。
- `codex/screenshot-text-annotation` worktree 仍有 `.serena/project.yml` 脏改动，ship 前必须清理。
- 终端执行记录提供了最终验证结果，但并未在主仓直接留下统一的 ship 记录，需要后续补 merge/PR 决策。

## Rollback / Recovery
- 本次仅新增文档与记录；若需回滚，删除本计划、对应 issue CSV、导入报告，并撤回 `ROADMAP.md` 的新增段落即可。

## Checkpoints
- Commit after: plan + issues + report + roadmap exception records written

## References
- `PROJECT.md`
- `ROADMAP.md`
- `docs/superpowers/specs/2026-04-11-screenshot-text-annotation-design.md`
- `docs/superpowers/plans/2026-04-11-screenshot-text-annotation-implementation.md`
- `/Users/bigdan/.cursor/projects/Volumes-1TBSSD-offload-Workspace-macos-spokeanywhere-spoke/terminals/4.txt`
- `codex/screenshot-text-annotation` worktree commit chain (`4abce99` → `91679e6`)
