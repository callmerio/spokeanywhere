---
description: Memory and context management - update project docs, load task context
---

# Workflow: CCW Memory Management

Manages project knowledge and context for improved AI output quality.

## [FLOW_CONTROL]

### Command: memory:update-full
- **Description**: Full project re-indexing. Use after major refactoring.

- **Step 1**: Analyze project structure.
- **Tool Call**: `list_dir: DirectoryPath=./`
- **Tool Call**: `list_dir: DirectoryPath=src/` (if exists)
- **Store in**: [PROJECT_STRUCTURE]

- **Step 2**: Detect tech stack.
- **Tool Call**: `view_file: path=package.json` (if exists)
- **Tool Call**: `view_file: path=requirements.txt` (if exists)
- **Tool Call**: `view_file: path=go.mod` (if exists)
- **Store in**: [TECH_STACK]

- **Step 3**: Find existing documentation.
- **Tool Call**: `grep_search: Query="CLAUDE.md|README.md", SearchPath=./`
- **Store in**: [DOC_FILES]

- **Step 4**: Generate/update project summary.
- **Tool Call**: `write_to_file: path=.workflow/project-context.md`
- **Content**:
  ```markdown
  # Project Context (Auto-generated)
  
  ## Tech Stack
  [From TECH_STACK]
  
  ## Directory Structure
  [From PROJECT_STRUCTURE]
  
  ## Key Entry Points
  [Detected main files]
  
  ## Module Overview
  [Key modules and their purposes]
  
  ## Last Updated
  [Timestamp]
  ```

- **Step 5**: Confirm.
- **Prompt to User**: "项目上下文已更新: .workflow/project-context.md"

---

### Command: memory:update-related
- **Description**: Incremental update for recently changed modules.

- **Step 1**: Get recent changes.
- **Tool Call**: `run_command: git diff --name-only HEAD~5 2>/dev/null || echo "No git history"`
- **Store in**: [CHANGED_FILES]

- **Step 2**: Identify affected modules.
- **Instruction**: Group [CHANGED_FILES] by directory/module.
- **Store in**: [AFFECTED_MODULES]

- **Step 3**: Update module docs.
- **FOR EACH** module in [AFFECTED_MODULES]:
  - **Tool Call**: `view_file: path=[module main file]`
  - **Instruction**: Summarize module purpose, exports, dependencies.
  - **Tool Call**: `write_to_file: path=.workflow/modules/[module-name].md`

- **Step 4**: Confirm.
- **Prompt to User**: "已更新模块文档: [List of updated modules]"

---

### Command: memory:load
- **Description**: Load task-specific context before starting work.

- **Step 1**: Parse task keywords.
- **Instruction**: Extract keywords from user's task description (file names, functions, modules).
- **Store in**: [TASK_KEYWORDS]

- **Step 2**: Search relevant files.
- **Tool Call**: `grep_search: Query=[TASK_KEYWORDS], SearchPath=src/`
- **Store in**: [RELEVANT_FILES]

- **Step 3**: Load project context.
- **Tool Call**: `view_file: path=.workflow/project-context.md` (if exists)
- **Store in**: [PROJECT_CONTEXT]

- **Step 4**: Build context package.
- **Tool Call**: `write_to_file: path=.workflow/.ccw-session/context-package.json`
- **Content**: Follow schema from `.agent/schemas/context-package.json`

- **Step 5**: Report loaded context.
- **Instruction**: Display summary of loaded context (tech stack, relevant files, module info).
