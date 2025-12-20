---
description: Adaptive Bug Fix Workflow with Diagnosis and Risk Assessment (V2.0 Tool-Centric)
---

# Workflow: CCW Lite-Fix (V2.0)

For bug fixes. Diagnoses root cause, assesses risk, fixes, and verifies.

## [FLOW_CONTROL]

### Phase 1: Diagnosis (Root Cause Analysis)
- **Step 1.1**: Reproduce the bug context.
- **Prompt to User**: "请描述 Bug 的症状（错误信息、复现步骤、预期行为）："
- **Store in**: [BUG_DESCRIPTION]

- **Step 1.2**: Search for related code.
- **Tool Call**: `grep_search: Query=[keywords from BUG_DESCRIPTION], SearchPath=src/`
- **Store in**: [RELATED_FILES]

- **Step 1.3**: Analyze potential root cause.
- **Tool Call**: `view_file: path=[first file from RELATED_FILES]`
- **Instruction**: Examine the code. Identify suspicious logic, missing error handling, or incorrect conditions.
- **Tool Call**: `write_to_file: path=.workflow/.lite-fix/diagnosis.md`
- **Content**:
  ```markdown
  # Bug Diagnosis
  
  ## Symptoms
  [From BUG_DESCRIPTION]
  
  ## Suspected Root Cause
  [Your analysis - file:line, logic flaw]
  
  ## Reproduction Steps
  1. [Step 1]
  2. [Step 2]
  ```
- **Output_to**: DIAGNOSIS_PATH

### Phase 2: Risk Assessment
- **Step 2.1**: Evaluate impact.
- **Instruction**: Based on [DIAGNOSIS_PATH], score the risk:
  - **Critical (9-10)**: Production outage, data loss.
  - **High (7-8)**: Core functionality broken, affects many users.
  - **Medium (4-6)**: Non-critical feature broken, workaround exists.
  - **Low (1-3)**: Minor inconvenience, cosmetic issue.
- **Store in**: [RISK_SCORE]

- **Step 2.2**: Choose fix strategy.
- **IF** [RISK_SCORE] >= 9:
  - **Strategy**: HotFix Mode - Minimal, surgical change. No refactoring.
- **ELSE**:
  - **Strategy**: Standard Fix - Address root cause properly.
- **Store in**: [FIX_STRATEGY]

### Phase 3: Repair (The Fix)
- **Step 3.1**: Load Coder Role.
- **Tool Call**: `view_file: path=.agent/rules/role-model-codex.md`

- **Step 3.2**: Apply fix.
- **Instruction**: Acting as Codex (Precision Coder), apply [FIX_STRATEGY].
- **Tool Call**: `replace_file_content` on the file identified in [DIAGNOSIS_PATH].
- **Store in**: [FIXED_FILE]

### Phase 4: Verification
- **Step 4.1**: Run tests.
- **Tool Call**: `run_command: npm test -- --grep "[relevant test pattern]"`
- **Store in**: [TEST_RESULT]

- **Step 4.2**: Loop if failed.
- **IF** [TEST_RESULT] contains 'FAIL':
  - **Instruction**: Analyze failure. The fix may have introduced a regression or was incomplete.
  - **Action**: Return to Phase 1.2 with new context. (Max 3 iterations)
- **ELSE**:
  - Proceed to Phase 5.

### Phase 5: Closure
- **Step 5.1**: Record fix in memory.
- **Tool Call**: `grep_search: Query="memory.csv", SearchPath=docs/`
- **IF** memory.csv exists:
  - **Tool Call**: Append to memory.csv:
    ```
    [Date],[Bug Keyword],[Root Cause Summary],[Fix File:Line],[Verification Status]
    ```

- **Step 5.2**: Report to user.
- **Prompt to User**: "Bug 已修复。根因：[Root Cause from DIAGNOSIS]. 修改文件：[FIXED_FILE]。"
