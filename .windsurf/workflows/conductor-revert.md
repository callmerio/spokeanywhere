---
description: Conductor 回滚 - 智能 Git 历史分析
---

# Conductor Revert (Native)

基于 Git 历史回滚 Conductor 的工作单元。

## [FLOW_CONTROL]

### Phase 1: Target Identification
- **Step 1.1**: List Active Context.
- **Instruction**: List tracks currently `[~]` (In Progress).
- **Prompt User**: "Which track/task do you want to revert?"

### Phase 2: Git Analysis (The Brain)
- **Step 2.1**: Find Commits.
- **Tool Call**: `git log --oneline --grep="[Task Keyword]" -n 10`
- **Instruction**: Identify the range of commits belonging to this logical unit.
  - Look for start commit (first task) and end commit (latest).
  
- **Step 2.2**: Conflict Check.
- **Instruction**: Check if subsequent commits (from other tracks) have touched the same files.
  - If yes: Warn user of high conflict risk.
  - If no: Mark as Safe.

### Phase 3: Execution
- **Step 3.1**: Confirm Plan.
- **Output**:
  ```markdown
  **Revert Plan**
  - Revert Commit: a1b2c3d (feat: login)
  - Revert Commit: e5f6g7h (fix: button)
  ```
- **Prompt User**: "Proceed?"

- **Step 3.2**: Revert.
- **Tool Call**: `git revert --no-edit [SHA]...`
- **Action**: Update `plan.md` status back to `[ ]`.
