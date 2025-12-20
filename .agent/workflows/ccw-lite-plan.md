---
description: Lightweight planning and execution workflow (V2.0 Tool-Centric)
---

# Workflow: CCW Lite-Plan (V2.0)

For quick, low-overhead tasks. Explores codebase, generates plan, executes with user confirmation.

## [FLOW_CONTROL]

### Phase 1: Task Analysis & Exploration
- **Step 1.1**: Understand task scope.
- **Instruction**: Analyze user's task description. Identify keywords (file names, functions, modules).
- **Store in**: [TASK_KEYWORDS]

- **Step 1.2**: Explore codebase.
- **Tool Call**: `grep_search: Query=[TASK_KEYWORDS], SearchPath=src/`
- **Tool Call**: `list_dir: DirectoryPath=src/`
- **Store in**: [CODEBASE_CONTEXT]

- **Step 1.3**: Assess complexity.
- **Instruction**: Based on [CODEBASE_CONTEXT], is this 'simple' (1-2 files) or 'medium' (3-5 files)?
- **Store in**: [COMPLEXITY]

### Phase 2: Clarification (Optional)
- **Condition**: IF [COMPLEXITY] == 'medium' OR task description is ambiguous.
- **Step 2.1**: Ask clarifying questions.
- **Prompt to User**: 
  - "关于这个任务，有几个问题需要确认："
  - "[Question 1 based on exploration findings]"
  - "[Question 2 if applicable]"
- **Instruction**: Wait for user response. Store in [CLARIFICATIONS].

### Phase 3: Planning
- **Step 3.1**: Generate plan.
- **Instruction**: Based on [CODEBASE_CONTEXT] and [CLARIFICATIONS], create a step-by-step plan.
- **Tool Call**: `write_to_file: path=.workflow/.lite-plan/plan.json`
- **Content Structure**:
  ```json
  {
    "summary": "Brief task summary",
    "tasks": [
      {
        "id": 1,
        "title": "Task title",
        "file": "path/to/file.ts",
        "modification_points": ["Line X: Add function Y"],
        "depends_on": []
      }
    ],
    "complexity": "simple|medium",
    "estimated_time": "5-15 min"
  }
  ```
- **Output_to**: PLAN_PATH

### Phase 4: Confirmation & Selection
- **Step 4.1**: Display plan.
- **Tool Call**: `view_file: path=[PLAN_PATH]`
- **Instruction**: Present plan summary to user.

- **Step 4.2**: Ask for confirmation.
- **Prompt to User**:
  - "以上是执行计划。请确认："
  - "1. 批准 (Allow)"
  - "2. 修改 (Modify)"
  - "3. 取消 (Cancel)"

- **Step 4.3**: Handle response.
- **IF** response == 'Allow': Proceed to Phase 5.
- **IF** response == 'Modify': Ask for modifications, update plan, return to Step 4.1.
- **IF** response == 'Cancel': **STOP** workflow.

### Phase 5: Execution
- **Step 5.1**: Load plan.
- **Tool Call**: `view_file: path=[PLAN_PATH]`

- **Step 5.2**: Execute each task.
- **FOR EACH** task in [PLAN_CONTENT].tasks:
  - **Tool Call**: `view_file: path=task.file`
  - **Instruction**: Apply modifications as described in task.modification_points.
  - **Tool Call**: `replace_file_content` OR `write_to_file`

- **Step 5.3**: Verify changes.
- **Tool Call**: `run_command: npm run lint` (or project-specific validation)
- **IF** errors: Fix and re-verify.

### Phase 6: Completion
- **Step 6.1**: Report.
- **Prompt to User**: "任务完成。以下是修改的文件：[List of files]"

- **Step 6.2**: Update memory (Optional).
- **Tool Call**: `grep_search: Query="memory.csv", SearchPath=docs/`
- **IF** memory.csv exists: Append entry for this task.
