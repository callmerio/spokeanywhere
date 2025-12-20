---
description: Test-Driven Development workflow - Red-Green-Refactor cycle
---

# Workflow: CCW TDD (Test-Driven Development)

Implements features using TDD methodology: Write failing test → Implement → Refactor.

## [FLOW_CONTROL]

### Phase 1: Requirement Analysis
- **Step 1.1**: Understand the feature.
- **Prompt to User**: "请描述要实现的功能及其预期行为："
- **Store in**: [FEATURE_DESC]

- **Step 1.2**: Identify test scenarios.
- **Instruction**: Based on [FEATURE_DESC], list:
  - Happy path cases
  - Edge cases
  - Error cases
- **Store in**: [TEST_SCENARIOS]

- **Step 1.3**: Confirm test plan.
- **Prompt to User**: "以下是测试场景，请确认：\n[TEST_SCENARIOS]"

### Phase 2: RED - Write Failing Tests
- **Step 2.1**: Find test directory.
- **Tool Call**: `run_command: find . -type d -name "test*" -o -name "__tests__" | head -1`
- **Store in**: [TEST_DIR]

- **Step 2.2**: Create test file.
- **Instruction**: Generate test code for [TEST_SCENARIOS].
- **Tool Call**: `write_to_file: path=[TEST_DIR]/[feature].test.ts`
- **Content Structure**:
  ```typescript
  describe('[Feature Name]', () => {
    describe('Happy Path', () => {
      it('should [expected behavior]', () => {
        // Arrange
        // Act
        // Assert - THIS SHOULD FAIL
      });
    });
    
    describe('Edge Cases', () => {
      it('should handle [edge case]', () => {
        // Test edge case
      });
    });
    
    describe('Error Handling', () => {
      it('should throw when [error condition]', () => {
        // Test error case
      });
    });
  });
  ```

- **Step 2.3**: Run tests (expect failure).
- **Tool Call**: `run_command: npm test -- --testPathPattern=[feature]`
- **Store in**: [RED_RESULT]

- **Step 2.4**: Verify RED state.
- **IF** [RED_RESULT] contains "FAIL":
  - **Instruction**: Good! Tests are failing as expected. Proceed to GREEN phase.
- **ELSE**:
  - **Instruction**: Tests should not pass yet. Review test logic.

### Phase 3: GREEN - Implement Minimum Code
- **Step 3.1**: Load Coder Role.
- **Tool Call**: `view_file: path=.agent/rules/role-model-codex.md`

- **Step 3.2**: Implement feature.
- **Instruction**: Acting as Codex, write the MINIMUM code to make tests pass.
- **Instruction**: Do NOT over-engineer. Only implement what tests require.
- **Tool Call**: `write_to_file: path=src/[feature].ts`

- **Step 3.3**: Run tests (expect pass).
- **Tool Call**: `run_command: npm test -- --testPathPattern=[feature]`
- **Store in**: [GREEN_RESULT]

- **Step 3.4**: Verify GREEN state.
- **IF** [GREEN_RESULT] contains "PASS":
  - **Instruction**: All tests passing! Proceed to REFACTOR phase.
- **ELSE**:
  - **Instruction**: Fix implementation. Return to Step 3.2. (Max 3 iterations)

### Phase 4: REFACTOR - Improve Code Quality
- **Step 4.1**: Load Reviewer Role.
- **Tool Call**: `view_file: path=.agent/rules/role-model-qwen.md`

- **Step 4.2**: Review implementation.
- **Instruction**: Acting as Qwen, review for:
  - Code duplication
  - Naming clarity
  - Performance issues
  - Error handling gaps

- **Step 4.3**: Apply refactoring (if needed).
- **Tool Call**: `replace_file_content` for improvements.

- **Step 4.4**: Re-run tests.
- **Tool Call**: `run_command: npm test -- --testPathPattern=[feature]`
- **Store in**: [REFACTOR_RESULT]

- **Step 4.5**: Verify tests still pass.
- **IF** [REFACTOR_RESULT] contains "PASS":
  - Proceed to completion.
- **ELSE**:
  - **Instruction**: Refactoring broke tests. Revert and try again.

### Phase 5: Completion
- **Step 5.1**: Generate coverage report.
- **Tool Call**: `run_command: npm test -- --coverage --testPathPattern=[feature]`
- **Store in**: [COVERAGE]

- **Step 5.2**: Report to user.
- **Prompt to User**:
  ```
  TDD 循环完成！
  
  ✅ 测试文件: [TEST_DIR]/[feature].test.ts
  ✅ 实现文件: src/[feature].ts
  ✅ 测试覆盖率: [COVERAGE summary]
  
  Red-Green-Refactor 周期已完成。
  ```
