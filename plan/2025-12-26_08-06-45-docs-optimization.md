---
mode: plan
cwd: /Users/bigdan/Workspace/macos/spokeanywhere
task: docs 优化计划（结构、索引、引用一致性）
complexity: medium
tool: mcp__sequential-thinking__sequentialthinking
total_thoughts: 7
created_at: 2025-12-26T08:08:14+08:00
---

# Plan: Docs 优化计划

🎯 任务概述
本计划聚焦 docs/ 与 docs/memo 的结构、索引与引用一致性优化，让文档可以作为项目“真相源”独立使用。
目标是统一引用格式（path:line）、建立清晰入口与索引、同步状态/路线图、并提供可验证的检查点。

📋 执行计划
1. 盘点文档资产与入口：梳理 docs/ 与 docs/memo 的主入口、子系统设计文档、路线图与合规矩阵。
2. 规范引用与路径：统一文档引用为 path:line；标注未实现文件；修正过期路径与命名漂移。
3. 建立索引与导航：完善 docs/memo/mind.md 与 docs/memo/implementation-map.md 的“入口/索引/链路”。
4. 状态一致性校验：对照 roadmap / memory.csv / implementation-map 的完成度，标注冲突与优先级。
5. 形成可追踪输出：更新 memory.csv 与 memory-timeline.md 记录本轮变更，保证审计可追溯。
6. 复核与抽检：抽检关键链路是否可从文档直达实现位置；确认未引入破坏性结构调整。
7. 产出后续协作入口：补充“如何持续维护 docs”的简短指南或 checklist。

🧪 验证与检查
- 随机抽检 10-20 条引用能直达文件且行号合理。
- 关键入口文档（mind / implementation-map / roadmap）互相可跳转。
- 新增引用均符合 path:line 规范；未实现项有明确标注。

⚠️ 风险与注意事项
- 行号漂移需要后续维护流程配合。
- 历史文档引用量大，需分批规范化。

🛡️ 回滚与安全
- 仅修改文档，不改代码逻辑；如需回滚，直接还原相关 docs 文件。
- 修改前后保持备份/变更记录（memory.csv + timeline）。

📎 参考
- `docs/memo/mind.md:1`
- `docs/memo/implementation-map.md:1`
- `docs/roadmap.md:1`
