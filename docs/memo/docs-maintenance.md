# Docs 维护清单

目标：让 docs/ 与 docs/memo 始终可作为项目“真相源”，引用可追溯、状态一致、入口清晰。

## 日常维护流程

1. 代码变更落地后，先更新 `docs/memo/implementation-map.md:1`
   - 功能矩阵状态与实现链路同步
   - 新增入口时补充 path:line 引用
2. 同步 `docs/roadmap.md:1`
   - 状态以代码实现为准（避免与实现不一致）
3. 记录到 `docs/memo/memory.csv:1`
   - 变更目的、范围、实现点与关键引用
4. 补充 `docs/memo/memory-timeline.md:1`
   - 新增 Learn 或里程碑条目
5. 有稳定知识沉淀时更新 `docs/memo/cards.md:1`
   - 卡片引用保持 path:line

## 更新频率与优先级

- 高优先级（每次功能入口/链路变更后立即）：`implementation-map`
- 中优先级（每次阶段推进/roadmap 调整）：`roadmap`
- 低优先级（每周或阶段回顾）：抽检引用可达性 + `memory-timeline`
- 更新入口：`implementation-map` / `mind` / `roadmap` / `memory.csv`

## 引用规范

- 统一使用 `path:line`，禁止纯文件名或锚点引用
- 未实现文件必须标注“未实现”
- 文档内路径保持仓库相对路径

## 状态一致性检查

- roadmap / implementation-map / memory 口径一致
- 如出现冲突，优先以代码实现为准并在文档中标注

## 抽检建议

- 使用 `rg -n \"spoke/\" docs/memo` 快速发现引用
- 抽检 10-20 条引用可达性（文件存在 + 行号合理）
