---
description: Conductor 项目初始化 - 幂等、无状态检查
---

# Conductor Native Setup

初始化 Conductor 开发环境。此工作流是**幂等**的：它会检查已存在的文件并跳过相应步骤，仅创建缺失的部分。

## [FLOW_CONTROL]

### Phase 1: Context Definition
- **Step 1.1**: Check `conductor/product.md`.
- **Tool Call**: `ls conductor/product.md`
- **Result**:
  - Found: Announce "Product definition exists, skipping."
  - Missing:
    - **Prompt User**: "请简要描述这个产品/项目是做什么的？目标用户是谁？"
    - **Action**: Generate `conductor/product.md` based on response.
    - **Content Pattern**: `# Product: [Name]\n\n## Vision\n...\n## Users\n...`

- **Step 1.2**: Check `conductor/tech-stack.md`.
- **Tool Call**: `ls conductor/tech-stack.md`
- **Result**:
  - Found: Announce "Tech stack defined, skipping."
  - Missing:
    - **Action**: Analyze current codebase (file extensions, package.json, etc.).
    - **Prompt User**: "我检测到的技术栈是 [Detected Stack]。是否正确？(回复 'yes' 或补充细节)"
    - **Action**: Generate `conductor/tech-stack.md`.

- **Step 1.3**: Check `conductor/product-guidelines.md`.
- **Tool Call**: `ls conductor/product-guidelines.md`
- **Result**:
  - Found: Skip.
  - Missing: Create with default template (Standard Engineering English, Clean Code).

### Phase 2: Workflow & Rules
- **Step 2.1**: Check `conductor/workflow.md`.
- **Tool Call**: `ls conductor/workflow.md`
- **Result**:
  - Found: Skip.
  - Missing: Copy from `vendor/conductor/templates/workflow.md` (if avail) or generate default TDD workflow.

- **Step 2.2**: Check `conductor/tracks.md`.
- **Tool Call**: `ls conductor/tracks.md`
- **Result**:
  - Found: Skip.
  - Missing: Create empty tracks index.
    ```markdown
    # Project Tracks
    
    Status: `[ ]` Pending, `[~]` In Progress, `[x]` Completed
    
    ---
    ```

### Phase 3: Completion
- **Step**: Summarize status.
- **Instruction**: List all checked/created files.
- **Output**: "Conductor setup complete. Ready for `/conductor-new`."
