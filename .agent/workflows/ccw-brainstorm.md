---
description: Auto-parallel brainstorming simulation with role-switching (V2.0 Tool-Centric)
---

# Workflow: CCW Brainstorm (V2.0)

Simulates multi-perspective brainstorming by sequentially activating role personas.
Uses explicit tool calls for file I/O and context management.

## [FLOW_CONTROL]

### Phase 0: Session Setup
- **Step**: Create brainstorm workspace.
- **Tool Call**: `run_command: mkdir -p .brainstorm`
- **Output_to**: SESSION_DIR

### Phase 1: Capture User Requirement
- **Step**: Store the original user request.
- **Instruction**: The user's initial task description is already in context. Summarize it.
- **Tool Call**: `write_to_file: path=.brainstorm/user-requirement.md, content="# User Requirement\n\n[Paste user's original request here]"`
- **Output_to**: USER_REQ_PATH

### Phase 2: Generate Guidance Framework
- **Step**: Formulate 3-4 clarifying questions based on the requirement.
- **Instruction**: Analyze [USER_REQ_PATH]. What are the ambiguous areas? What trade-offs exist?
- **Tool Call**: `write_to_file: path=.brainstorm/framework.md`
- **Content Structure**:
  ```markdown
  # Guidance Framework
  
  ## Core Challenges Identified
  1. [Challenge 1]
  2. [Challenge 2]
  
  ## Clarifying Questions
  1. [Question about scope/priority]
  2. [Question about technical constraint]
  3. [Question about user impact]
  ```
- **Output_to**: FRAMEWORK_PATH

### Phase 3: Role Analysis - Product Manager
- **Step 3.1**: Load PM Role Context.
- **Tool Call**: `view_file: path=.agent/rules/role-product-manager.md`
- **Store in**: PM_ROLE_CONTEXT

- **Step 3.2**: PM Analysis.
- **Instruction**: 
  - Forget technical implementation. Focus on "Why" and "What".
  - Read [FRAMEWORK_PATH]. Answer each question from PM perspective.
  - Structure output as: Vision, User Value, Requirements, Business Case.
- **Tool Call**: `write_to_file: path=.brainstorm/analysis_pm.md`
- **Output_to**: PM_ANALYSIS_PATH

### Phase 4: Role Analysis - System Architect
- **Step 4.1**: Load Architect Role Context.
- **Tool Call**: `view_file: path=.agent/rules/role-system-architect.md`
- **Store in**: ARCH_ROLE_CONTEXT

- **Step 4.2**: Architect Analysis.
- **Instruction**:
  - Think in Components. Visualize system as interacting boxes.
  - Read [FRAMEWORK_PATH]. Answer each question from Architect perspective.
  - Structure output as: Architecture Overview, Component Design, Tech Stack, Risk.
- **Tool Call**: `write_to_file: path=.brainstorm/analysis_architect.md`
- **Output_to**: ARCH_ANALYSIS_PATH

### Phase 5: Conflict Detection & Resolution
- **Step 5.1**: Load both analyses.
- **Tool Call**: `view_file: path=[PM_ANALYSIS_PATH]`
- **Tool Call**: `view_file: path=[ARCH_ANALYSIS_PATH]`

- **Step 5.2**: Identify conflicts.
- **Instruction**:
  - Compare PM's "User Value" with Architect's "Tech Stack". Are they aligned?
  - Does PM's timeline expectation match Architect's complexity assessment?
  - List any contradictions.

- **Step 5.3**: Generate Synthesis.
- **Tool Call**: `write_to_file: path=.brainstorm/synthesis.md`
- **Content Structure**:
  ```markdown
  # Brainstorm Synthesis
  
  ## Aligned Decisions
  - [Decision 1: Both agree on X]
  
  ## Conflicts Identified
  - **Conflict 1**: PM wants [A], Architect recommends [B].
    - **Resolution**: [Proposed compromise or user decision needed]
  
  ## Unified Proposal
  [Merged action plan]
  ```
- **Output_to**: SYNTHESIS_PATH

### Phase 6: Report to User
- **Step 6.1**: Display synthesis.
- **Tool Call**: `view_file: path=[SYNTHESIS_PATH]`
- **Instruction**: Present the content to the user.

- **Step 6.2**: Ask for approval.
- **Prompt to User**: "以上是头脑风暴结果。是否批准？如需修改请指出。"
