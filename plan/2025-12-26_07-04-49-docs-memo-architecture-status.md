---
mode: plan
cwd: /Users/bigdan/Workspace/macos/spokeanywhere
task: 更新 docs/memo 代码引用与架构链路，并完成状态核对与路线图优化
complexity: complex
tool: mcp__sequential-thinking__sequentialthinking
total_thoughts: 10
created_at: 2025-12-26T07:04:53+0800
---

# Plan: docs/memo 全链路可追踪化

🎯 任务概述
目标是让 docs/memo 成为“项目全链路与状态真相源”，做到：每个功能都有明确代码落点、链路描述、当前状态与后续计划，并同步优化 roadmap。最终产出应让新成员仅看 memo 即可定位功能实现位置与整体链路。

📋 执行计划
1. 建立文档清单与索引规则：确定 docs/memo 中必须维护的主文档与索引位置（mind、memory.csv、memory-timeline、roadmap）。
2. 功能矩阵化：为主要功能建立“功能 → 入口/核心文件 → 链路 → 状态 → 计划”的统一结构，确保每个功能至少 1 个代码入口与 1 条链路描述。
3. 架构链路梳理：提取跨模块链路（录音、转录、LLM、输出、历史等），形成可复用的链路描述段落。
4. 状态核对规则：定义状态判定优先级（代码实现 > memo > roadmap > PRD），并用 [√]/[~]/[ ] 统一标记。
5. 路线图优化：根据最新状态更新 roadmap 的“当前焦点/Phase 完成度/待办”，避免重复与过期项。
6. 代码引用校验：对 docs/memo 中的关键引用补足/修正路径与文件名，确保能直达实现。
7. 更新记录：在 memory.csv 追加“文档同步记录”，必要时补充 memory-timeline 一条摘要。
8. 校验与维护规则：输出一个“如何保持文档不过期”的维护小节（建议写在 mind 或 memo 中）。

⚠️ 风险与注意事项
- 文档漂移：代码变化快，引用易过期，需要维护规则兜底。
- 功能状态冲突：不同文档标记不一致，必须以代码实现为最终裁决。
- 工作量集中：功能覆盖面广，优先保证主链路与核心功能准确。

📎 参考
- `docs/memo/mind.md`
- `docs/memo/memory.csv`
- `docs/memo/memory-timeline.md`
- `docs/roadmap.md`
- `docs/design.md`
- `docs/outline/app_store_compliance.md`

📋 Plan CSV
ID,Title,Description,Acceptance,Test_Method,Tools,Dev_Status,Review1_Status,Regression_Status,Files,Dependencies,Notes
P1,建立文档索引规则,确定 memo 主文档与索引位置,形成索引与维护规则草案,manual,manual,TODO,TODO,TODO,docs/memo/mind.md,,规则优先级需写明
P2,功能矩阵化,为核心功能建立落点/链路/状态矩阵,所有核心功能可定位到代码,manual,manual,TODO,TODO,TODO,docs/memo/mind.md,docs/memo/memory.csv,至少含录音/转录/LLM/输出/历史
P3,链路梳理,补全跨模块链路段落,链路描述可追踪到模块,manual,manual,TODO,TODO,TODO,docs/memo/mind.md,docs/design.md,建议用分段清晰描述
P4,状态核对,统一状态标记并对齐 roadmap,状态一致且可解释,manual,manual,TODO,TODO,TODO,docs/roadmap.md,docs/memo/mind.md,以代码实现为准
P5,引用校验,修正文档中的代码引用路径,引用路径可直达,manual,manual,TODO,TODO,TODO,docs/memo/*,,必要时补记 memory.csv
P6,记录更新,追加 memory.csv 与 timeline 条目,记录可追踪,manual,manual,TODO,TODO,TODO,docs/memo/memory.csv;docs/memo/memory-timeline.md,,记录变更原因
