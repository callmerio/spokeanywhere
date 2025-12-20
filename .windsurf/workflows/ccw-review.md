---
description: Code review workflow - security, quality, architecture checks
---

# Workflow: CCW Code Review

Comprehensive code review with multiple dimensions: Security, Quality, Architecture.

## [FLOW_CONTROL]

### Phase 1: Scope Definition
- **Step 1.1**: Identify review scope.
- **Prompt to User**: "请指定审查范围：\n1. 最近的 git 提交\n2. 特定文件/目录\n3. 整个 PR/分支"
- **Store in**: [REVIEW_SCOPE]

- **Step 1.2**: Get files to review.
- **IF** [REVIEW_SCOPE] == "git commits":
  - **Tool Call**: `run_command: git diff --name-only HEAD~3`
- **ELIF** [REVIEW_SCOPE] == "specific files":
  - **Prompt to User**: "请输入文件路径（逗号分隔）："
- **ELIF** [REVIEW_SCOPE] == "PR/branch":
  - **Tool Call**: `run_command: git diff --name-only main...HEAD`
- **Store in**: [FILES_TO_REVIEW]

### Phase 2: Load Reviewer Role
- **Tool Call**: `view_file: path=.agent/rules/role-model-qwen.md`
- **Instruction**: Activate Qwen (Critic) persona for all subsequent analysis.

### Phase 3: Multi-Dimension Review

#### Dimension A: Security Review
- **Step A.1**: Search for security patterns.
- **Tool Call**: `grep_search: Query="password|secret|token|api_key|eval|exec|innerHTML", SearchPath=[FILES_TO_REVIEW directories]`
- **Store in**: [SECURITY_FINDINGS]

- **Step A.2**: Analyze each finding.
- **FOR EACH** finding in [SECURITY_FINDINGS]:
  - **Tool Call**: `view_file: path=[finding file], StartLine=[finding line - 10], EndLine=[finding line + 10]`
  - **Instruction**: Is this a real vulnerability or false positive?
- **Store in**: [SECURITY_ISSUES]

#### Dimension B: Quality Review
- **Step B.1**: Check code complexity.
- **Tool Call**: `run_command: npx eslint [FILES_TO_REVIEW] --format json 2>/dev/null || echo "No ESLint"`
- **Store in**: [LINT_RESULTS]

- **Step B.2**: Review each file.
- **FOR EACH** file in [FILES_TO_REVIEW]:
  - **Tool Call**: `view_file: path=[file]`
  - **Instruction**: Check for:
    - Functions > 50 lines
    - Deep nesting (> 3 levels)
    - Missing error handling
    - Code duplication
- **Store in**: [QUALITY_ISSUES]

#### Dimension C: Architecture Review
- **Step C.1**: Check dependencies.
- **Instruction**: Are there circular dependencies? Inappropriate imports?
- **Tool Call**: `grep_search: Query="import.*from", SearchPath=[FILES_TO_REVIEW directories]`
- **Store in**: [IMPORT_PATTERNS]

- **Step C.2**: Evaluate architecture alignment.
- **Instruction**: Does the code follow project architecture patterns?
- **Store in**: [ARCHITECTURE_ISSUES]

### Phase 4: Generate Report
- **Tool Call**: `write_to_file: path=.workflow/.ccw-session/review-report.md`
- **Content**:
  ```markdown
  # Code Review Report
  
  **Review Scope**: [REVIEW_SCOPE]
  **Files Reviewed**: [count] files
  **Reviewer**: Qwen (CCW Critic Role)
  **Date**: [timestamp]
  
  ## Summary
  [Overall assessment: APPROVE / REQUEST CHANGES / REJECT]
  
  ## Critical Issues 🚨
  [From SECURITY_ISSUES where severity = critical]
  
  ## Security Findings 🔒
  [From SECURITY_ISSUES]
  
  ## Quality Issues ⚠️
  [From QUALITY_ISSUES]
  
  ## Architecture Concerns 🏗️
  [From ARCHITECTURE_ISSUES]
  
  ## Positive Observations ✅
  [Good patterns found]
  
  ## Recommendations
  1. [Actionable recommendation]
  2. [Actionable recommendation]
  ```

### Phase 5: Present to User
- **Tool Call**: `view_file: path=.workflow/.ccw-session/review-report.md`
- **Prompt to User**: "审查完成。以上是审查报告。是否需要详细解释任何问题？"
