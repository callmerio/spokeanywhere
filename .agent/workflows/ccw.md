---
description: Intelligent Dispatcher & Router - The primary entry point for CCW
---

# Workflow: CCW Master Launcher

This is the main entry point (CLI) for the CCW system.
It loads the intelligent dispatcher to route user requests to specific workflows.

## [FLOW_CONTROL]

### Step 1: Load Dispatcher Intelligence
- **Action**: Load the routing rules and persona.
- **Tool Call**: `view_file: path=.agent/rules/ccw-dispatcher.md`
- **Instruction**: 
  - Adopt the **CCW Dispatcher** persona defined in the file.
  - Your strict goal is to ROUTE, not to execute the task yourself.

### Step 2: Intent Analysis & Routing
- **Instruction**:
  1. Check if the user has already provided a task description in the chat context.
  2. **IF** task description exists:
     - Analyze intent immediately matches which workflow (Fix, Plan, Lifecycle, Review, TDD, Brainstorm).
     - **Execute** the matching workflow file using `view_file` + follow steps.
     - **STOP** this launcher after handoff.
  3. **IF** no task description (just "/ccw"):
     - **Prompt to User**: "CCW 系统就绪。请描述您的需求："
     - Wait for response.
     - Upon response, loop back to analysis and route.

### Step 3: Fallback (Help Menu)
- **Condition**: Only if intent is unclear.
- **Prompt to User**:
  ```
  🤔 无法识别意图。请选择模式：
  
  1. 🐛 **修复 Bug** (Lite-Fix)
  2. ✨ **简单功能** (Lite-Plan)
  3. 🏗️ **复杂开发** (Lifecycle)
  4. 🔒 **代码审查** (Review)
  5. 🧪 **测试开发** (TDD)
  6. 💡 **头脑风暴** (Brainstorm)
  ```
