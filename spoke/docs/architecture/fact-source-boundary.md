# SpokenAnyWhere 事实真源与历史边界

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: 2026-04 架构优化路线图 v3 执行期

---

## 一、当前事实真源

当前执行期内，以下三份文档分别承担唯一职责：

| 角色 | 文档 | 约束 |
|------|------|------|
| 当前事实真源 | `./current-state-audit.md` | 当前仓库事实、能力边界、质量基线与文档偏差只以此为准 |
| Active Plan | `../plans/2026-04-10-architecture-optimization-roadmap-v3.md` | 当前唯一生效的架构优化执行编排 |
| Active Execution Checklist | `../../tasks/2026-04-10-architecture-optimization-roadmap-v3-execution.md` | 当前唯一生效的 wave 执行清单 |

解释：

- `current-state-audit.md` 负责回答“现在仓库实际上是什么样”
- `roadmap-v3.md` 负责回答“这一轮要按什么阶段推进”
- `v3-execution.md` 负责回答“当前 wave 和 issue 怎么落地”

如果三者冲突，先修文档，再推进实现，不允许让历史文档反向覆盖当前事实。

---

## 二、历史文档边界

以下文档全部保留，但只作为历史证据或前序推演，不再承担当前执行口径：

| 文档 | 日期 / 版本 | 当前适用范围 | 说明 |
|------|-------------|--------------|------|
| `../plans/archive/2026-04-10/2026-04-10-architecture-optimization-roadmap-v1.md` | 2026-04-10 / v1 | 历史草案，不参与当前执行 | 保留第一版问题定义与排序尝试 |
| `../plans/archive/2026-04-10/2026-04-10-architecture-optimization-roadmap-v2.md` | 2026-04-10 / v2 | 历史草案，不参与当前执行 | 保留第二版 phase/gate 推演 |
| `../roadmap/2026-03-conditional-go-architecture-roadmap.md` | 2026-03-19 / v1 | 历史路线图，保留 Conditional Go 解冻合同来源 | 当前只保留“解冻条件”与前序 issue 设计背景 |
| `../m2-final-acceptance.md` | 2026-02-22 / M2 | 历史验收证据，不代表当前现状 | 只能作为历史通过记录引用 |

边界规则：

- 可以引用历史文档解释“为什么会有这条规则”
- 不可以把历史文档里的测试口径、active 状态、执行顺序写回当前结论
- 所有新的“当前状态”结论都必须回写到 `current-state-audit.md`

---

## 三、架构文档同步清单

当 v3 执行期内发生事实、计划或门禁变化时，至少同步以下文档：

| 文档 | 同步触发条件 | 必须回写的内容 |
|------|--------------|----------------|
| `./current-state-audit.md` | 当前事实、质量基线、历史边界变化 | 当前事实、口径边界、已确认偏差 |
| `./overview.md` | 主链路、入口、主要结构结论变化 | 架构导航与高层入口说明 |
| `./quick-reference.md` | 入口文件、验证命令、导航索引变化 | 快速定位命令、入口路径、相关文档索引 |
| `./risks-and-recommendations.md` | Go/Conditional Go 结论、风险优先级变化 | 风险结论、建议动作、相关文档 |
| `../plans/2026-04-10-architecture-optimization-roadmap-v3.md` | phase gate、artifact、验收口径变化 | active plan 本身 |
| `../../tasks/2026-04-10-architecture-optimization-roadmap-v3-execution.md` | wave 顺序、issue 输出、active/archived 关系变化 | 执行清单与 active plan 指向 |

追溯要求：

- 每次同步至少留下可点击的文档路径
- 当历史文档被提及时，必须同时说明“历史 / archived / contract-source”中的一种角色
- Active execution 文档只允许把 `v3` 标成 active；`v1` / `v2` 只能放在 archived 上下文

---

## 四、最小使用规则

阅读顺序：

1. 先读 `current-state-audit.md`
2. 再读 `roadmap-v3.md`
3. 再读 `v3-execution.md`
4. 需要导航时再读 `quick-reference.md`
5. 需要历史来源时最后回看本页第二节中的历史文档

写作规则：

1. “当前 / latest / active” 只指向 `current-state-audit.md` 与 `v3` 文档
2. “历史 / archived / contract-source” 必须显式标注
3. 不再把 `v1` / `v2` 或 2026-03 路线图中的执行顺序当作当前路线

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
