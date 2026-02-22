# 文档已迁移 / Documentation Migrated

**迁移日期**: 2026-02-22

本目录下的架构文档已迁移至项目根目录：

```
docs/architecture/ (旧位置，已废弃)
    ↓
spoke/docs/architecture/ (新位置，唯一规范根目录)
```

## 新文档位置

请访问以下位置查看最新架构文档：

- **项目架构全景**: `spoke/docs/architecture/overview.md`
- **风险评估与改进建议**: `spoke/docs/architecture/risks-and-recommendations.md`
- **快速导航索引**: `spoke/docs/architecture/quick-reference.md`
- **App 层启动序列**: `spoke/docs/architecture/app-layer-startup-sequence.md`
- **App 层回调链**: `spoke/docs/architecture/app-layer-callback-chains.md`
- **App 层风险评估**: `spoke/docs/architecture/app-layer-risk-assessment.md`

## 迁移原因

- 与代码同根，便于 CI artifact 和脚本引用
- 统一文档根目录，避免双源口径分叉
- 符合项目结构惯例

---

**维护者**: SpokenAnyWhere Team
**迁移执行**: 2026-02-22
