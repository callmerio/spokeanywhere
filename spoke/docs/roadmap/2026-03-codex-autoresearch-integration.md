# 2026-03 Codex Autoresearch 接入说明

版本：v1  
日期：2026-03-19  
状态：试点中

## 1. 目标

本说明定义如何把现有 issues CSV 接入 `$codex-autoresearch`，用于逐步推进 Conditional Go 收敛相关工作。

核心原则：

1. issues CSV 继续作为任务边界合同，不直接承担循环运行状态。
2. `$codex-autoresearch` 只消费单个 issue 对应的 launch-ready spec。
3. 每次运行的实验日志、状态快照与结果产物落到独立 run artifacts，不回写到主 CSV 的逐轮细节。

## 2. 为什么不能直接把 CSV 喂给 autoresearch

当前 CSV 已经很适合做 backlog 与验收合同，但还不是 autoresearch 的直接输入。

原因：

- 一个 issue 往往包含多个验收维度，而 autoresearch 偏好单一机械 metric。
- 有些 issue 更偏 review / 文档 / 治理约定，不适合无人循环。
- autoresearch 需要 `Goal / Scope / Metric / Direction / Verify` 五元组，而 CSV 当前只部分覆盖。

因此采用两层结构：

1. `issues/*.csv`
   - 任务边界、优先级、验收、refs
2. `autoresearch/specs/<ISSUE>.json`
   - 单个 issue 的运行配置 sidecar
3. `autoresearch/queue/conditional-go-architecture.json`
   - 顺序队列、依赖、worktree 与 artifact 根目录
4. `autoresearch/status/conditional-go-architecture.json`
   - 队列执行摘要状态

## 3. 目录约定

### 3.1 输入

- issues CSV：`issues/2026-03-19_20-55-00-conditional-go-architecture.csv`

### 3.2 转换脚本

- `scripts/autoresearch/issue_csv_to_spec.py`

### 3.3 Sidecar Spec

- `autoresearch/specs/*.json`

### 3.4 队列与状态

- `autoresearch/queue/conditional-go-architecture.json`
- `autoresearch/status/conditional-go-architecture.json`

### 3.5 转换 / 验证 / 调度脚本

- `scripts/autoresearch/issue_csv_to_spec.py`
- `scripts/autoresearch/verify_issue_metric.py`
- `scripts/autoresearch/run_issue_exec.py`
- `scripts/autoresearch/run_queue_exec.py`

## 4. 当前接入规则

### 4.1 CSV 继续保留的职责

- `title` / `description`：问题边界
- `acceptance_criteria`：最终完成条件
- `refs`：上下文与修改范围
- `test_*` 字段：验证与回归要求

### 4.2 sidecar 新承担的职责

- `goal`
- `scope`
- `metric`
- `direction`
- `verify`
- `guard`
- `iterations`
- `stop_condition`

## 5. 哪些 issue 适合优先接入

### 当前 spec 覆盖

已补齐以下 issue 的 sidecar spec：

- `AG-010`
- `QG-010`
- `APP-010`
- `APP-020`
- `ARCH-010`
- `ARCH-020`
- `ARCH-030`
- `GOV-010`
- `TEST-010`

说明：

- `ARCH-010` / `ARCH-020` / `ARCH-030` 的 metric 是目标文件中的 `.shared` 直连数量
- `QG-010` 的 metric 是质量门禁合同缺项数
- `APP-*` / `GOV-010` / `TEST-010` 当前使用“治理缺口数”作为机械代理指标

## 6. Pilot 与队列

### 6.1 当前 pilot spec

`autoresearch/specs/QG-010.json`

### 6.2 当前 pilot metric

- `missing_quality_gate_contract_items`

### 6.3 当前 pilot verify

```bash
python3 scripts/autoresearch/verify_issue_metric.py --issue QG-010
```

脚本会机械检查：

1. 路线图存在
2. issues CSV 存在且包含 `QG-010`
3. `current-state-audit.md` 中记录了 `swift test` 与 `bash Tests/run-concurrency-check.sh`
4. CSV 中包含失败分类约定

### 6.4 当前 pilot guard

```bash
swift test
bash Tests/run-concurrency-check.sh
```

### 6.5 当前状态

- `QG-010` 当前机械 metric 已为 `0`
- 已在 `autoresearch/status/conditional-go-architecture.json` 中标记为 `completed`
- 队列调度默认会跳过已完成 issue；如需强制重跑，可传 `--force`

### 6.6 当前队列顺序

固定串行顺序：

1. `AG-010`
2. `QG-010`
3. `APP-010`
4. `APP-020`
5. `ARCH-010`
6. `ARCH-020`
7. `ARCH-030`
8. `GOV-010`
9. `TEST-010`

## 7. 使用方式

### 7.1 从 CSV 生成 spec 草案

```bash
python3 scripts/autoresearch/issue_csv_to_spec.py \
  --csv issues/2026-03-19_20-55-00-conditional-go-architecture.csv \
  --issue QG-010 \
  --overrides autoresearch/specs/QG-010.json \
  --format md
```

### 7.2 生成 JSON 配置快照

```bash
python3 scripts/autoresearch/issue_csv_to_spec.py \
  --csv issues/2026-03-19_20-55-00-conditional-go-architecture.csv \
  --issue QG-010 \
  --overrides autoresearch/specs/QG-010.json \
  --format json
```

### 7.3 dry-run 单条 issue

```bash
python3 scripts/autoresearch/run_issue_exec.py \
  --queue autoresearch/queue/conditional-go-architecture.json \
  --issue QG-010
```

### 7.4 dry-run 整个队列

```bash
python3 scripts/autoresearch/run_queue_exec.py \
  --queue autoresearch/queue/conditional-go-architecture.json
```

### 7.5 launch 单条 issue

```bash
python3 scripts/autoresearch/run_issue_exec.py \
  --queue autoresearch/queue/conditional-go-architecture.json \
  --issue QG-010 \
  --launch
```

### 7.6 launch 整个队列

```bash
python3 scripts/autoresearch/run_queue_exec.py \
  --queue autoresearch/queue/conditional-go-architecture.json \
  --launch
```

### 7.7 强制重跑已完成 issue

```bash
python3 scripts/autoresearch/run_issue_exec.py \
  --queue autoresearch/queue/conditional-go-architecture.json \
  --issue QG-010 \
  --force
```

### 7.8 交给 `$codex-autoresearch`

当前调度脚本已经直接面向 `Mode: exec`。

如果要单独人工校验某条 spec，也可以先运行：

```bash
python3 scripts/autoresearch/issue_csv_to_spec.py \
  --csv issues/2026-03-19_20-55-00-conditional-go-architecture.csv \
  --issue QG-010 \
  --overrides autoresearch/specs/QG-010.json \
  --format md
```

## 8. 下一步建议

1. 先用 `QG-010` 验证 `issue -> spec -> worktree -> exec -> artifact -> status` 全链路。
2. 再用 `ARCH-010` 验证真正的代码收敛型 loop。
3. 等 `QG-010` 与 `ARCH-010` 稳定后，再考虑是否给主 CSV 增加 `autoresearch_*` 字段。

## 9. 结论

本仓库的 issues CSV **可以合理接入** `$codex-autoresearch`，但应采用：

- `CSV 作为任务合同`
- `sidecar spec 作为运行配置`
- `独立 run artifacts 作为实验日志`

而不是把主 CSV 直接当作 loop 配置文件。
