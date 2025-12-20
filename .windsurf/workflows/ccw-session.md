---
description: Session management - create, list, resume, complete workflow sessions
---

# Workflow: CCW Session Management

Manages workflow sessions for multi-task tracking and context persistence.

## [FLOW_CONTROL]

### Command: session:start
- **Step 1**: Generate session ID.
- **Instruction**: Create ID from task description: `WFS-[topic-slug]-[YYYYMMDD]`
- **Store in**: [SESSION_ID]

- **Step 2**: Create session directory.
- **Tool Call**: `run_command: mkdir -p .workflow/active/[SESSION_ID]`

- **Step 3**: Initialize session metadata.
- **Tool Call**: `write_to_file: path=.workflow/active/[SESSION_ID]/workflow-session.json`
- **Content**:
  ```json
  {
    "session_id": "[SESSION_ID]",
    "created_at": "[ISO timestamp]",
    "status": "active",
    "description": "[user's task description]",
    "current_phase": "init",
    "tasks_completed": [],
    "tasks_pending": []
  }
  ```

- **Step 4**: Confirm to user.
- **Prompt to User**: "会话已创建: [SESSION_ID]。工作目录: .workflow/active/[SESSION_ID]/"

---

### Command: session:list
- **Step 1**: Find all sessions.
- **Tool Call**: `run_command: find .workflow/active -maxdepth 1 -type d -name "WFS-*" 2>/dev/null`
- **Store in**: [ACTIVE_SESSIONS]

- **Tool Call**: `run_command: find .workflow/archives -maxdepth 1 -type d -name "WFS-*" 2>/dev/null`
- **Store in**: [ARCHIVED_SESSIONS]

- **Step 2**: Display list.
- **Instruction**: Format output as:
  ```
  ## Active Sessions
  - WFS-xxx (created: date, phase: current_phase)
  
  ## Archived Sessions
  - WFS-yyy (completed: date)
  ```

---

### Command: session:resume
- **Step 1**: Check for sessions.
- **Tool Call**: `run_command: ls -t .workflow/active/ | head -5`
- **Store in**: [RECENT_SESSIONS]

- **Step 2**: If multiple, ask user.
- **Prompt to User**: "发现多个会话，请选择要恢复的会话：\n[List sessions]"
- **Store in**: [SELECTED_SESSION]

- **Step 3**: Load session context.
- **Tool Call**: `view_file: path=.workflow/active/[SELECTED_SESSION]/workflow-session.json`
- **Store in**: [SESSION_CONTEXT]

- **Step 4**: Report status.
- **Instruction**: Display session status, pending tasks, and next steps.

---

### Command: session:complete
- **Step 1**: Identify current session.
- **Tool Call**: `run_command: ls .workflow/active/ | head -1`
- **Store in**: [CURRENT_SESSION]

- **Step 2**: Update session status.
- **Tool Call**: `view_file: path=.workflow/active/[CURRENT_SESSION]/workflow-session.json`
- **Instruction**: Update status to "completed", add completed_at timestamp.
- **Tool Call**: `write_to_file: path=.workflow/active/[CURRENT_SESSION]/workflow-session.json`

- **Step 3**: Archive session.
- **Tool Call**: `run_command: mkdir -p .workflow/archives && mv .workflow/active/[CURRENT_SESSION] .workflow/archives/`

- **Step 4**: Confirm.
- **Prompt to User**: "会话已归档: .workflow/archives/[CURRENT_SESSION]/"
