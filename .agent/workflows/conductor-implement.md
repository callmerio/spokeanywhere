---
description: Conductor 实现任务 - TDD 循环 + 可视化审计
---

# Conductor Implement (Native)

执行 `plan.md`。包含上下文自动注入、TDD 循环执行、以及基于 Markdown 的验证报告生成。

## [FLOW_CONTROL]

### Phase 1: Context Injection
- **Step 1.1**: Auto-load Global Context.
- **Tool Call**: `view_file` (if exists):
  - `conductor/product.md`
  - `conductor/tech-stack.md`
  - `conductor/workflow.md`

- **Step 1.2**: Select Track.
- **Instruction**: Find first `[ ]` or `[~]` track in `conductor/tracks.md`.
- **Tool Call**: `view_file` Track's `spec.md` and `plan.md`.

### Phase 2: Execution Loop
- **Step 2.1**: Pick Next Task.
- **Instruction**: Find first uncompleted task. Mark as `[~]`.

- **Step 2.2**: TDD Execution (If strictly defined in Plan).
- **Check**: Does task say "Write Tests"?
  - Yes: Write test file -> Run (Fail) -> Implement -> Run (Pass).
  - No (Chore): Just implement and verify.

- **Step 2.3**: Commit & Log.
- **Action**: `git commit`.
- **Action**: Update `plan.md` task to `[x]` with Commit SHA.

### Phase 3: Phase Verification (The "Audit" Step)
- **Trigger**: When a **Phase** is completed.
- **Step 3.1**: Generate Report.
- **Action**: Create `conductor/tracks/[ID]/reports/phase_[N]_audit.md`.
  - Content:
    - Automated Test Results (Console Output).
    - Manual Verification Steps used.
    - User Approval timestamp.
- **Step 3.2**: User Sign-off.
- **Prompt User**: "Phase Complete. Please review the audit draft. Approve?"
- **Step 3.3**: Link in Plan.
- **Action**: Update `plan.md`:
  `## Phase X [Completed]`
  `> Report: [Link to audit.md]`

### Phase 4: Sync
- **Condition**: If Track `[x]`.
- **Action**: Update `product.md` / `tech-stack.md` if Spec deviated.
- **Action**: Archive or Keep track based on user pref.
