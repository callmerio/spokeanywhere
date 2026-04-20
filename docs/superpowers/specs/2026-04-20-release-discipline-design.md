# SpokenAnyWhere Release Discipline Design

> Goal: 为 SpokenAnyWhere 建立从 `v0.1.0` 开始的正式发版纪律，并同时抽象出一个用户级、跨项目可复用的 `release notes + 发布流程` skill。项目内保留版本实际产物、项目特有规则和单版本 notes；用户级 skill 负责通用方法、偏好和命名规范。

---

## 1. 背景

SpokenAnyWhere 到目前为止已经积累了大量功能和修复，但长期缺少稳定的 release 节奏。这会带来几个问题：

- 很难回答“这一版到底改了什么”
- 版本与交付阶段缺少清晰锚点
- CHANGELOG 越拖越难补
- 未来即使继续开发，也难以建立 beta / stable / patch 的自然节奏

当前仓库已经有部分发版基础设施：

- `.github/workflows/release.yml`
- `scripts/build-release.sh`
- `CHANGELOG.md`
- `spoke/Bundler.toml`

但现状仍存在几个结构性问题：

- 版本号来源分散
- release notes 没有固定落点和维护纪律
- GitHub Release 语义没有和仓库内 release notes 对齐
- 本地 release 脚本与当前正式 Bundle ID / 版本来源没有完全统一

本设计要解决的是“发版纪律”和“可复用方法论”，而不是一次性只发出一个版本包。

---

## 2. 设计目标

### 2.1 项目目标

为 SpokenAnyWhere 建立一套明确、可重复的 release 规则：

- 从 `v0.1.0` 开始正式发版
- 为 `stable / beta / patch` 定义清晰语义
- 让 `CHANGELOG`、单版本 release notes、GitHub Release 三者各有分工
- 让版本号来源和 release 入口统一
- 让“什么时候升 `X`，什么时候升 `Y`，什么时候用 `beta`”成为明确规则而不是临场判断

### 2.2 Skill 目标

将本次讨论中已经稳定下来的“release notes 写法、版本命名、beta/stable 判断、私有仓库 GitHub Release 的定位、个人偏好”抽象成一个用户级通用 skill，用于未来别的项目也能复用。

这个 skill 的职责不是替某个仓库硬编码项目细节，而是提供：

- 通用 release discipline 判断框架
- 通用版本语义决策
- 通用 release notes 模板
- 通用发版 checklist
- 用户个人偏好（例如偏向 milestone 驱动、仓库内 canonical source、私有 GitHub release 仍有意义）

---

## 3. 非目标

本设计当前**不直接包含**以下内容：

- 现在立刻接完整的 notarization / stapling 正式发行链
- 现在立刻变成收费版或 App Store 发布流程
- 把所有历史提交 retroactively 全部重构成过去版本
- 把 skill 做成 SpokenAnyWhere 专属 repo-local skill

这次优先级是先把 release discipline 建起来，并把通用方法沉淀为用户级 skill。

---

## 4. 版本语义

本项目从现在开始采用：

```text
v0.X.Y
```

并明确采用 pre-1.0 阶段的 milestone-driven 版本策略。

### 4.1 正式起点

正式起点固定为：

```text
v0.1.0
```

原因：

- 虽然项目已有大量开发积累，但“正式发版纪律”是从现在开始建立
- 从 `0.1.0` 起步，能清楚表达“现在开始进入有纪律的版本化阶段”
- 避免为了补历史而把现阶段的发布语义弄复杂

### 4.2 `X` 的含义

`X` 代表新的**里程碑阶段**。

只有当满足以下条件时，才升级到新的 `v0.X.0`：

- 一批功能已经形成明确、可讲述的阶段性成果
- 这批功能已经达到“可交付”的程度
- 结构和交互已经基本稳定，不再处于高速抖动期
- 团队愿意把这一版作为一个阶段性的稳定基线来记录

`X` **绝不**由 commit 数量决定。

### 4.3 `Y` 的含义

`Y` 代表同一正式里程碑上的**补丁发布**。

适用场景：

- 修 bug
- 做稳定性修复
- 做小幅 polish
- 不改变这个里程碑本身的阶段定义

也就是说：

- `v0.2.0`：某个新的正式里程碑
- `v0.2.1`：该里程碑发布后的补丁
- `v0.2.2`：继续补丁修复

`Y` 也**绝不**由 commit 数量决定。

### 4.4 Beta 的语义

当下一阶段功能已经有可用雏形，但还没有达到正式收口标准时，使用：

```text
v0.X.0-beta.N
```

例如：

- `v0.2.0-beta.1`
- `v0.2.0-beta.2`

Beta 适用条件：

- 功能已经可试用
- 功能边界已大体成形
- 但仍在明显打磨中
- 当前不愿意把它当成“正式阶段基线”

Beta 的作用是：

- 不让半成品污染正式版历史
- 保留版本节奏
- 允许在 private release / 内测中提前编号和归档

### 4.5 Unreleased

`CHANGELOG.md` 顶部长期保留：

```text
Unreleased
```

日常开发中的变更先进入 `Unreleased`，待决定发 `beta` 或 `stable` 时再收口。

---

## 5. Release 类型定义

### 5.1 Stable Release

形态：

```text
v0.X.0
v0.X.Y
```

语义：

- 当前阶段的正式可交付版本
- 可以作为未来补丁和回滚的稳定锚点

### 5.2 Beta Release

形态：

```text
v0.X.0-beta.N
```

语义：

- 已经值得被编号和记录
- 但还不应该作为正式稳定版

### 5.3 Private GitHub Release 的定位

即使仓库是 private，GitHub Release 依然保留，并定义为：

```text
内部版本账本
```

它的价值不是公开传播，而是：

- 保留版本锚点
- 保留当时的产物
- 保留 release notes 快照
- 支持内部回看、对比、回滚

因此：

- `beta` release 也可以创建 GitHub Release，并标记为 `prerelease`
- `stable` release 创建正式 GitHub Release

---

## 6. Release Notes 分层

### 6.1 Canonical Source

canonical source 放在仓库内。

建议分层如下：

```text
CHANGELOG.md
docs/releases/
  v0.1.0.md
  v0.2.0-beta.1.md
  v0.2.0.md
```

### 6.2 各自职责

`CHANGELOG.md`

- 长期总览
- 保留 `Unreleased`
- 作为全局历史索引

`docs/releases/<version>.md`

- 单个版本的正式 release notes
- 内容完整、结构清楚
- 作为 GitHub Release body 的上游来源

`GitHub Release`

- 作为对某个 tag 的发布快照
- 与仓库内单版本 note 内容同步
- private repo 中也保留

---

## 7. Release Notes 结构

展示层参考 Trancy 风格，保持清晰分类和可读性；但会增加工程上下文。

建议模板结构：

```text
Title
Date
Release Type

Summary

New
Improvements
Fixes
Known Issues
Upgrade Notes
Artifacts
```

其中：

- `New`：新增能力
- `Improvements`：体验、结构或性能改进
- `Fixes`：bug 修复
- `Known Issues`：已知未解问题
- `Upgrade Notes`：升级注意事项，如权限、迁移、行为变化
- `Artifacts`：DMG / ZIP / 内部定位说明

---

## 8. 用户级 Skill 的边界

### 8.1 Skill 放置位置

这个 skill 不放在仓库内，而放在用户级 skills 目录，例如：

```text
/Users/bigdan/.claude/skills/
```

### 8.2 Skill 的职责

该 skill 应当是通用 release discipline skill，而不是 SpokenAnyWhere 专属 skill。

它应该包含：

- 版本号升级决策框架
- `stable / beta / patch` 判定方法
- canonical source 与 GitHub Release 的分层方法
- release note 模板
- 发版 checklist
- 用户偏好

### 8.3 SpokenAnyWhere 项目内仍保留的内容

项目内仍然保留：

- `CHANGELOG.md`
- `docs/releases/*.md`
- 项目特有的 release workflow 和构建脚本
- 项目特有的版本号 source 和 bundle / artifact 规则

### 8.4 偏好应写入 skill 的内容

需要写入用户级 skill 的偏好包括：

- milestone-driven release，而不是 commit-driven
- `v0.1.0` 可作为“开始正规发版”的第一版
- 未成熟但值得编号的阶段用 `beta`
- canonical source 优先放仓库内
- GitHub private release 依然有意义，作为内部版本账本
- notes 结构偏好为：`New / Improvements / Fixes`，并允许附加工程上下文

---

## 9. 项目内实现方向

在 SpokenAnyWhere 仓库中，后续实现应当至少做到以下几点：

### 9.1 统一版本号来源

版本号需要收敛为单一来源。

当前推荐来源：

```text
spoke/Bundler.toml
```

后续 release workflow、本地 build-release 脚本、以及生成的 release metadata，都应该从这一来源读取，而不是分别写死。

### 9.2 统一 release 入口

建议继续以 tag 驱动 release：

```text
v0.1.0
v0.2.0-beta.1
v0.2.0
```

并让：

- GitHub workflow 生成 release artifact
- GitHub Release 使用对应版本的 notes

### 9.3 统一历史维护方法

每次开发过程：

1. 先写进 `Unreleased`
2. 决定发 beta / stable 时收口成单版本 note
3. 再同步到 GitHub Release

---

## 10. 推荐工作流

```text
[ 日常开发 ]
Unreleased 累积变更
        │
        ├─ 仍在打磨 -> 保持 Unreleased
        │
        ├─ 已可试用但未收口 -> v0.X.0-beta.N
        │
        └─ 已形成阶段性交付 -> v0.X.0
                                 │
                                 └─ 后续修复 -> v0.X.Y
```

---

## 11. 本设计的推荐结论

当前正式结论如下：

- SpokenAnyWhere 从 `v0.1.0` 开始建立正式 release discipline
- `X` 表示里程碑，`Y` 表示补丁，`beta` 表示未正式收口但值得编号的阶段
- `CHANGELOG.md` 顶部保留 `Unreleased`
- 单版本 notes 存放于 `docs/releases/`
- GitHub private release 保留，作为内部版本账本
- 将通用方法抽象为用户级通用 skill，而不是 SpokenAnyWhere repo-local skill

---

## 12. 下一步

在该设计确认后，下一步应进入 implementation plan，并执行两条并行主线：

1. SpokenAnyWhere 仓库内 release 纪律落地
2. 用户级通用 release skill 创建与验证

