# SpokenAnyWhere 统一质量门禁说明

**状态**: Active Reference
**更新时间**: 2026-04-10
**适用范围**: 2026-04 架构优化路线图 v3 / QG-300

---

## 一、目标

本门禁入口用于把以下仓库内验证收敛成一个 provider-neutral 的统一入口：

- `swift build`
- `swift test`
- `bash Tests/run-concurrency-check.sh`
- `.shared` 使用扫描
- `NotificationCenter.default.(addObserver|post)` 使用扫描

约束：

- 不预设 GitHub Actions、其他 CI 或特定 provider
- 先保证“仓库内可直接复现”，再决定后续接到哪种自动化平台

---

## 二、统一入口

在 `spoke/` 目录执行：

```bash
scripts/verify/run-architecture-quality-gate.sh
```

如果从仓库根目录执行：

```bash
cd spoke
scripts/verify/run-architecture-quality-gate.sh
```

脚本会在每次运行时生成新的日志目录：

```text
verify/quality-gate/<timestamp>/
```

默认产物：

- `summary.md`
- `build.log`
- `test.log`
- `concurrency.log`
- `shared-scan.log`
- `notification-scan.log`

---

## 三、失败分类

当前脚本会显式区分以下失败类型：

| 分类 | 触发条件 | 最小复现路径 |
|------|----------|--------------|
| 环境失败 | 缺少 `swift` / `rg`、门禁脚本无法写日志、`Tests/run-concurrency-check.sh` 缺失 | `command -v swift`; `command -v rg`; `ls Tests/run-concurrency-check.sh` |
| 构建失败 | `swift build` 非零退出 | `swift build` |
| 测试失败 | `swift test` 非零退出 | `swift test` |
| 并发失败 | `bash Tests/run-concurrency-check.sh` 非零退出 | `bash Tests/run-concurrency-check.sh` |

扫描阶段当前仍是 **report-only**：

- `.shared` 扫描会输出到 `shared-scan.log`
- `NotificationCenter` 扫描会输出到 `notification-scan.log`
- `GOV-380` 已经把 allowlist 与 state crosswalk 固化到 `dependency-channel-decision-matrix.md`
- 在真正把 review / CI 规则接上之前，这两项仍默认不直接作为 hard fail

这样做的原因：

- Wave 0 先固化入口与证据路径
- Wave 4 再把扫描结果升级成可执行约束

---

## 四、最小复现路径

当统一门禁失败时，优先按以下顺序复现：

1. 环境检查

```bash
command -v swift
command -v rg
ls Tests/run-concurrency-check.sh
```

2. 构建

```bash
swift build
```

3. 测试

```bash
swift test
```

4. strict concurrency

```bash
bash Tests/run-concurrency-check.sh
```

5. 扫描输出

```bash
rg -n "\.shared\." App Core Services UI
rg -n "NotificationCenter\.default\.(addObserver|post)" App Core Services UI
```

---

## 五、与当前结论的关系

- 本门禁入口已经版本化，满足“仓库内可证明”的最低要求
- 这 **不等于** 仓库已经具备版本化 CI workflow 证据
- 当前关于自动化平台的结论仍保持：
  - 本地门禁入口已存在
  - 仓库内仍未发现 `.github/workflows/*` 的稳定证据

---

## 六、相关文档

- `./current-state-audit.md`
- `./fact-source-boundary.md`
- `./dependency-channel-decision-matrix.md`
- `./quick-reference.md`
- `../plans/2026-04-10-architecture-optimization-roadmap-v3.md`
- `../roadmap/2026-03-conditional-go-architecture-roadmap.md`

---

**维护者**: SpokenAnyWhere Team
**最后更新**: 2026-04-10
