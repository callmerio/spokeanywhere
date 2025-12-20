# CCW Agent Configuration

This directory contains the CCW (Claude Code Workflow) implementation for IDE Agent environments.

## 🚀 Quick Start (One Command)

**Just type `/ccw` and describe your task.**

The intelligent dispatcher will route you to the right workflow:

```
@[.agent] /ccw 修复登录页面报错
```
*(Auto-routes to Bug Fix)*

```
@[.agent] /ccw 添加用户头像上传功能
```
*(Auto-routes to Feature Plan)*

```
@[.agent] /ccw 审查代码
```
*(Auto-routes to Code Review)*

---

## 📂 System Architecture

### 1. The Dispatcher (`workflows/ccw.md`)
The single entry point that analyzes intent and loads specific workflows.

### 2. Task Workflows
| Workflow | Purpose |
|----------|---------|
| `ccw-lite-fix` | 🐛 **Bug Fix**: Diagnose → Risk → Fix → Verify |
| `ccw-lite-plan` | ✨ **Quick Feature**: Explore → Plan → Execute |
| `ccw-lifecycle` | 🏗️ **Complex Project**: Full 8-step decision tree |
| `ccw-review` | 🔒 **Code Review**: Security & Quality gates |
| `ccw-tdd` | 🧪 **TDD**: Red-Green-Refactor cycle |
| `ccw-brainstorm` | 💡 **Brainstorm**: Multi-role analysis |

### 3. Roles & Intelligence
- **System Roles**: Gemini (Architect), Codex (Coder), Qwen (Critic)
- **Business Roles**: PM, Architect, QA, UX, etc.
- **Data Schemas**: Standardized JSON for context passing

## ⚙️ Usage Tips
- **Always start with `/ccw`** to ensure the right context is loaded.
- You can also invoke specific workflows directly if you know what you need:
  - `@[.agent] run workflows/ccw-lite-fix.md`
