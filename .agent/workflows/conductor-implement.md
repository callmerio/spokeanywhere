---
description: Conductor 实现任务 - Issue 驱动 + TDD 循环 + 经验记录
---

# Conductor Implement (Native)

执行 `plan.md`。基于 **Issue 驱动**的执行循环，包含历史经验检索、TDD 执行、以及经验自动记录。

## [FLOW_CONTROL]

### Phase 1: Context Injection
- **Step 1.1**: Auto-load Global Context.
- **Tool Call**: `view_file` (if exists):
  - `conductor/product.md`
  - `conductor/tech-stack.md`
  - `conductor/workflow.md`

- **Step 1.2**: Select Track.
- **Instruction**: Find first `[ ]` or `[~]` track in `conductor/tracks.md`.
- **Tool Call**: `view_file` Track's `spec.md`, `plan.md`, and `issues.json`.

- **Step 1.3**: Load Issue Context. (🆕)
- **Tool Call**:
  ```bash
  python3 ~/.gemini/.claude/skills/memory/scripts/memory_db.py issue list --track [TRACK_ID]
  ```
- **Output**: 显示当前 Track 的 Issue 进度

---

### Phase 2: Issue-Driven Execution Loop (🆕)

**Loop Start**: 重复以下步骤直到所有 Issues 完成

#### Step 2.1: Get Next Issue
- **Tool Call**:
  ```bash
  python3 ~/.gemini/.claude/skills/memory/scripts/memory_db.py issue next --track [TRACK_ID]
  ```
- **Output**: 
  - 当前 Issue 的详细信息
  - Acceptance Criteria (验收标准)
  - 相关历史经验 (如有)
- **Store**: [CURRENT_ISSUE]

#### Step 2.2: Historical Context Check
- **IF** [CURRENT_ISSUE] 有 `related_issues`:
  - 展示历史解决方案
  - 询问用户是否参考历史方案

#### Step 2.3: TDD Execution
- **Check**: Does Issue have `verification_type == 'unit_test'`?
  - **Yes (TDD Mode)**:
    1. Write test file → Run (Expect Fail) 🔴
    2. Implement code → Run (Expect Pass) 🟢
    3. Refactor if needed ♻️
  - **No (Manual Mode)**:
    1. Implement code
    2. 提示用户执行验证步骤
    3. 等待用户确认

#### Step 2.4: Close Issue & Record Experience
- **Tool Call**:
  ```bash
  python3 ~/.gemini/.claude/skills/memory/scripts/memory_db.py issue close \
    --track [TRACK_ID] \
    --id [ISSUE_ID] \
    --outcome success \
    --solution "简述解决方案" \
    --lessons "经验教训（如有）"
  ```
- **Automatic**:
  - 更新 SQLite `issues` 表
  - 更新 `issues.json` 快照
  - 如果有价值的经验，自动创建 Memory Card

#### Step 2.5: Update Plan.md
- **Action**: Update `plan.md` 对应的 Task 为 `[x]`
- **Action**: 记录 Commit SHA (如有)

**Loop End**: 当 `issue next` 返回 "所有 Issues 已完成"

---

### Phase 3: Phase Verification (The "Audit" Step)
- **Trigger**: When a **Phase** in Plan is completed.
- **Step 3.1**: Generate Report.
- **Action**: Create `conductor/tracks/[ID]/reports/phase_[N]_audit.md`.
  - Content:
    - Issues completed in this phase
    - Automated Test Results (Console Output)
    - Manual Verification Steps used
    - Lessons learned summary
- **Step 3.2**: User Sign-off.
- **Prompt User**: "Phase Complete. Please review the audit draft. Approve?"
- **Step 3.3**: Link in Plan.
- **Action**: Update `plan.md`:
  `## Phase X [Completed]`
  `> Report: [Link to audit.md]`

---

### Phase 4: Track Completion
- **Condition**: All Issues status == 'done'
- **Step 4.1**: Complete Track.
- **Tool Call**:
  ```bash
  python3 ~/.gemini/.claude/skills/memory/scripts/memory_db.py track complete \
    --track [TRACK_ID] \
    --summary "整体总结" \
    --learnings "关键收获"
  ```
- **Step 4.2**: Update Artifacts.
- **Action**: Update `product.md` / `tech-stack.md` if Spec deviated.
- **Action**: Mark track as `[x]` in `conductor/tracks.md`.

- **Step 4.3**: Archive Decision.
- **Prompt User**: "Archive this track? (Y/N)"
- **IF** Yes:
  ```bash
  python3 ~/.gemini/.claude/skills/memory/scripts/memory_db.py track archive --track [TRACK_ID]
  ```
