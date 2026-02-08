---
description: Conductor 新建任务轨道 - 集成 CCW Brainstorm
---

# Conductor New Track (Native)

创建新的开发任务。集成 **Research (探索)** 和 **CCW 深度思考** 模式，根据任务复杂度自动调整 Plan 结构。

## [FLOW_CONTROL]

### Phase 1: Ideation & Intent
- **Step 1.1**: Capture User Intent.
- **Prompt User**: "你想构建/修复什么？(Please describe the feature/bug/chore)"
- **Store**: [USER_INTENT]

---

### Phase 2: Research (探索阶段) 🔴 强制执行
**目标**: 在生成 Spec 之前，**必须**收集足够的上下文信息。

> 🚨 **CRITICAL - 不可跳过**: 
> - 必须收集 **≥10 条有效联网信息**
> - **必须调用**: `search_web` / `resolve-library-id -> get-library-docs` (Context7) / `read_url_content` (Crawl)
> - 整理后才能进入 Phase 3
> - **违反此规则 = 工作流执行失败**

- **Step 2.1**: Project Knowledge Search (强制 ≥3 条).
- **Tool Call**: 执行 **至少 3 次** `grep_search` / `find_by_name`
- **Instruction**:
  - 从 [USER_INTENT] 中提取 **至少 3 个** 核心关键词
  - 对每个关键词执行搜索
  - 记录：相关文件路径、函数名、当前实现逻辑
- **Output Requirement**: 必须列出 ≥3 个相关代码位置
- **Store**: [CODE_CONTEXT]

- **Step 2.2**: Memory Check (强制).
- **Tool Call**: `view_file: docs/memo/memory.csv`
- **Instruction**: 
  - 如果文件存在：必须搜索相关条目
  - 如果文件不存在：明确记录 "No memory file found"
- **Store**: [MEMORY_CONTEXT]

- **Step 2.3**: External Research (🔴 强制 ≥10 条联网信息).
- **Mandatory Tool Calls** (必须全部执行):
  1. `search_web("[USER_INTENT] best practices 2024")` - 最佳实践
  2. `search_web("[USER_INTENT] implementation guide")` - 实现指南
  3. `search_web("[USER_INTENT] testing strategy")` - 测试策略
  4. 如涉及库/框架: `resolve-library-id` -> `get-library-docs` (Context7)
  5. 如需深入阅读: `read_url_content` 爬取关键文章
- **Output Requirement**: 
  - 必须记录 ≥10 条外部信息
  - 每条需包含：标题 + 核心洞察 + 来源URL
- **Store**: [EXTERNAL_CONTEXT]

- **Step 2.4**: Validate & Summarize.
- **Validation Checklist** (全部必须满足):
  - [ ] [CODE_CONTEXT] ≥ 3 条
  - [ ] [MEMORY_CONTEXT] 已检查
  - [ ] [EXTERNAL_CONTEXT] ≥ 10 条 (**联网信息**)
  - [ ] **Total ≥ 15 条**
- **IF Validation Fails**: 
  - **返回 Step 2.3 继续收集**
  - 不满足数量要求时**禁止进入 Phase 3**
- **Tool Call**: `write_to_file: .brainstorm/research_summary.md`
- **Content Structure**:
  ```markdown
  # Research Summary for: [USER_INTENT]
  
  ## 📁 Code Context (X items)
  1. `path/file.ts:line` - description
  2. ...
  
  ## 📜 Memory Context
  - [Related entries or "None found"]
  
  ## 🌐 External Research (X items) 🔴 必须 ≥10 条
  1. [Title](URL) - Key insight
  2. ...
  
  ## 💡 Key Takeaways
  - Point 1
  - Point 2
  ```
- **Output**: 向用户展示研究发现。**必须等待用户确认后才能继续**。

---

### Phase 3: Spec Generation (CCW Integrated)
- **Step 3.1**: Brainstorming (Auto).
- **Instruction**: Acting as **CCW Architect**, based on:
  - [USER_INTENT]
  - [RESEARCH_SUMMARY] (from Phase 2)
  - `conductor/product.md`, `conductor/tech-stack.md`
- **Output**: Key functional requirements, edge cases, and rough implementation path.
- **Tool Call**: `write_to_file: .brainstorm/temp_spec_draft.md`

- **Step 3.2**: Generate Spec.
- **Instruction**: Convert the draft into formal `spec.md`.
  - Sections: Overview, Requirements, Acceptance Criteria, Out of Scope.
- **Prompt User**: "Review the generated Spec. Approve or Request Changes?"

---

### Phase 4: Planning with Adaptive Rigor
- **Step 4.1**: Determine Complexity.
- **Prompt User**: "这是一个 **Feature** (需要 TDD/验证) 还是 **Chore/Bug** (轻量级)? (Type 'F' or 'C')"
- **Store**: [TRACK_TYPE]

- **Step 4.2**: Generate Plan.
- **IF** [TRACK_TYPE] == 'F':
  - **Structure**: Strict TDD.
    - Phase 1: Setup
    - Phase 2: Implementation (Task: Test -> Task: Code -> Task: Refactor)
    - Phase 3: Verification (Task: Verify & Report)
- **IF** [TRACK_TYPE] == 'C':
  - **Structure**: Checklist.
    - Task 1: Fix
    - Task 2: Verify

- **Step 4.3**: Create Artifacts.
- **Action**:
  1. Generate Track ID: `folder_name_YYYYMMDD`.
  2. `mkdir -p conductor/tracks/[ID]`.
  3. Write `spec.md` and `plan.md`.
  4. Append to `conductor/tracks.md`.

---

### Phase 4.5: Issue Extraction (🆕 细粒度验收点)

**目标**: 将 Plan 中的每个 Task 转化为可验证的 Issue，并检索历史经验。

- **Step 4.5.1**: Historical Search.
- **Tool Call**: 
  ```bash
  python3 ~/.gemini/.claude/skills/memory/scripts/memory_db.py issue search "[从 Spec 提取的关键词]"
  ```
- **Instruction**:
  - 如果找到相似历史问题，展示给用户
  - 将相关 Issue ID 记录到新 Issue 的 `related_issues` 字段
- **Store**: [HISTORICAL_CONTEXT]

- **Step 4.5.2**: Generate Issues from Plan.
- **Instruction**: 遍历 Plan 中的每个 Task，提取：
  - `local_id`: I001, I002...
  - `type`: feature / ui / logic / bug / refactor
  - `title`: Task 标题
  - `description`: 详细描述
  - `target_files`: 目标文件列表
  - `acceptance_criteria`: **必须具体可验证** (颜色、尺寸、行为...)
  - `verification_type`: manual / unit_test / e2e / script
  - `verification_cmd`: 测试命令（如适用）
  - `dependencies`: 依赖的其他 Issue
- **Prompt User**: "确认以下 Issues 的验收标准是否完整？"

- **Step 4.5.3**: Persist Issues.
- **Tool Call**:
  ```bash
  python3 ~/.gemini/.claude/skills/memory/scripts/memory_db.py issue batch \
    --track [TRACK_ID] \
    --json '[{"local_id": "I001", "type": "...", "title": "...", ...}]'
  ```
- **Automatic**: 
  - 写入 SQLite `issues` 表
  - 导出 `conductor/tracks/[TRACK_ID]/issues.json`

---

### Phase 5: Handoff
- **Output**: 
  ```
  Track [ID] created. 
  Issues: [N] items
  Status: [ ] Pending.
  
  First Issue: [I001] {title}
  
  Run `/conductor-implement` to start.
  ```