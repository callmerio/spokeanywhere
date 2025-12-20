---
description: The Master Decision Tree for CCW (The 8-Step Loop)
---

# Workflow: CCW Lifecycle (Master Decision Tree V2.0)

This is the main entry point for the "CCW Lifecycle Decision Flow". 
Agent executes this as a sequential decision tree with tool calls.

## [FLOW_CONTROL]

### Phase 0: Initialize Workspace
- **Step**: Ensure workflow directory exists.
- **Tool Call**: `run_command: mkdir -p .workflow/.ccw-session`
- **Output_to**: WORKSPACE_READY

### Step 1: Classification (Bug or Feature?)
- **Step 1.1**: Ask user for classification.
- **Prompt to User**: "这是一个 **Bug 修复** 还是 **新功能开发**？请回复 'bug' 或 'feature'。"
- **Instruction**: Wait for user response. Store in [TASK_TYPE].

- **Step 1.2**: Route based on [TASK_TYPE].
- **IF** [TASK_TYPE] == 'bug':
  - **Action**: Execute `/ccw-lite-fix` workflow.
  - **Tool Call**: Read `.agent/workflows/ccw-lite-fix.md` and follow its steps.
  - **STOP** this workflow after lite-fix completes.
- **ELSE**:
  - **Action**: Proceed to Step 2.

### Step 2: Ideation (Do you know WHAT to build?)
- **Step 2.1**: Ask user for clarity.
- **Prompt to User**: "你清楚要构建**什么功能**吗？(是/否)"
- **Instruction**: Wait for user response. Store in [KNOWS_WHAT].

- **Step 2.2**: Route based on [KNOWS_WHAT].
- **IF** [KNOWS_WHAT] == '否':
  - **Action**: Execute `/ccw-brainstorm` workflow for product discovery.
  - **Tool Call**: Read `.agent/workflows/ccw-brainstorm.md` and follow its steps.
  - After brainstorm, return here and proceed to Step 3.
- **ELSE**:
  - **Action**: Proceed to Step 3.

### Step 3: Technical Design (Do you know HOW to build it?)
- **Step 3.1**: Ask user for technical clarity.
- **Prompt to User**: "你清楚**如何实现**这个功能吗？(是/否)"
- **Instruction**: Wait for user response. Store in [KNOWS_HOW].

- **Step 3.2**: Route based on [KNOWS_HOW].
- **IF** [KNOWS_HOW] == '否':
  - **Action**: Load Gemini Role for deep architecture analysis.
  - **Tool Call**: `view_file: .agent/rules/role-model-gemini.md`
  - **Instruction**: Acting as Gemini (Architect), analyze the codebase and propose architecture.
  - **Tool Call**: `write_to_file: .workflow/.ccw-session/architecture-analysis.md`
  - After analysis, proceed to Step 4.
- **ELSE**:
  - **Action**: Proceed to Step 4.

### Step 4: UI/UX Design (Does it involve UI?)
- **Step 4.1**: Ask user about UI involvement.
- **Prompt to User**: "这个任务涉及**用户界面**修改吗？(是/否)"
- **Instruction**: Wait for user response. Store in [HAS_UI].

- **Step 4.2**: Route based on [HAS_UI].
- **IF** [HAS_UI] == '是':
  - **Prompt to User**: "请提供 UI 参考（图片路径/URL）或描述你期望的设计风格："
  - **Instruction**: Store response in [UI_REF]. Continue to Step 5.
- **ELSE**:
  - **Action**: Proceed to Step 5.

### Step 5: Planning (Simple or Complex Task?)
- **Step 5.1**: Assess task complexity.
- **Tool Call**: `grep_search: Query="function|class|interface" in project src/`
- **Instruction**: Based on search results and user task, classify as 'simple' (<5 files) or 'complex'.
- **Store in**: [COMPLEXITY]

- **Step 5.2**: Route based on [COMPLEXITY].
- **IF** [COMPLEXITY] == 'simple':
  - **Action**: Execute `/ccw-lite-plan` workflow.
  - **Tool Call**: Read `.agent/workflows/ccw-lite-plan.md` and follow its steps.
  - **STOP** this workflow after lite-plan completes.
- **ELSE**:
  - **Action**: Execute Full Planning.
  - **Tool Call**: `view_file: .agent/rules/role-model-gemini.md`
  - **Instruction**: Generate detailed `IMPL_PLAN.md`.
  - **Tool Call**: `write_to_file: .workflow/.ccw-session/IMPL_PLAN.md`
  - Proceed to Step 6.

### Step 6: Execution
- **Step 6.1**: Prepare execution context.
- **Tool Call**: `view_file: .workflow/.ccw-session/IMPL_PLAN.md`
- **Store in**: [PLAN_CONTENT]

- **Step 6.2**: Load Coder Role.
- **Tool Call**: `view_file: .agent/rules/role-model-codex.md`
- **Instruction**: Acting as Codex (Implementer), execute [PLAN_CONTENT] step by step.
- **Instruction**: Use `replace_file_content` or `write_to_file` for code changes.

### Step 7: Testing & QA
- **Step 7.1**: Run tests.
- **Tool Call**: `run_command: npm test` (or project-specific test command)
- **Store in**: [TEST_RESULT]

- **Step 7.2**: Loop if failed.
- **IF** [TEST_RESULT] contains 'FAIL':
  - **Instruction**: Analyze failure. Fix code. Return to Step 7.1. (Max 3 iterations)
- **ELSE**:
  - Proceed to Step 8.

### Step 8: Review & Delivery
- **Step 8.1**: Load Reviewer Role.
- **Tool Call**: `view_file: .agent/rules/role-model-qwen.md`
- **Instruction**: Acting as Qwen (Critic), review the changes made in Step 6.
- **Tool Call**: `write_to_file: .workflow/.ccw-session/review-report.md`

- **Step 8.2**: Report to User.
- **Prompt to User**: "任务完成。请查看 `.workflow/.ccw-session/review-report.md` 获取审查报告。"

- **Step 8.3**: Archive Session (Optional).
- **Tool Call**: `run_command: mv .workflow/.ccw-session .workflow/archives/session-$(date +%Y%m%d-%H%M%S)`
