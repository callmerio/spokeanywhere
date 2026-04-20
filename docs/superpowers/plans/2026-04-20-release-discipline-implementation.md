# Release Discipline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:super-40-subagent-driven-development (recommended) or superpowers:super-41-executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 SpokenAnyWhere 仓库内落地正式 release discipline，并同时创建一个用户级通用 `release-discipline` skill，使后续各项目都能复用同一套发版与 release notes 方法。

**Architecture:** 这次实现拆成两条线。项目内这条线负责版本源统一、`CHANGELOG + docs/releases` 分层、release workflow 对齐和 `v0.1.0` 首版 notes 准备。用户级这条线负责创建通用 `release-discipline` skill，把 milestone/beta/patch 判定、notes 模板、以及 private GitHub release 的定位抽象为可复用方法。

**Tech Stack:** SwiftPM, Swift Bundler, GitHub Actions, shell scripts, Markdown, user-level Codex skills

---

### Task 1: 建立仓库内 release notes 骨架

**Files:**
- Modify: `CHANGELOG.md`
- Create: `docs/releases/v0.1.0.md`

- [ ] **Step 1: 在 `CHANGELOG.md` 顶部加入 `Unreleased` 区块**

要求：
- 保留现有历史内容，不重写旧条目
- 在文件顶部新增 `Unreleased`
- 用统一分类：`New` / `Improvements` / `Fixes`

- [ ] **Step 2: 为 `v0.1.0` 新建首版 release notes 文件**

路径：
- `docs/releases/v0.1.0.md`

内容要求：
- 标题、日期、release type
- `Summary`
- `New`
- `Improvements`
- `Fixes`
- `Known Issues`
- `Upgrade Notes`
- `Artifacts`

- [ ] **Step 3: 在 `CHANGELOG.md` 中为 `v0.1.0` 建立索引入口**

要求：
- `Unreleased` 保留在最上方
- 新增 `v0.1.0` 版本区块
- 文案与 `docs/releases/v0.1.0.md` 保持同一语义

- [ ] **Step 4: 检查 Markdown 结构是否清晰、无空标题、无 placeholder**

Run:

```bash
sed -n '1,220p' CHANGELOG.md
sed -n '1,220p' docs/releases/v0.1.0.md
```

Expected:
- `Unreleased` 存在
- `v0.1.0` 存在
- 单版本 notes 结构完整

### Task 2: 统一项目版本号来源

**Files:**
- Modify: `scripts/build-release.sh`
- Modify: `.github/workflows/release.yml`
- Reference: `spoke/Bundler.toml`
- Reference: `spoke/App/AppIdentity.swift`

- [ ] **Step 1: 新增一个从 `spoke/Bundler.toml` 读取版本号的脚本**

建议路径：
- `scripts/read-spoke-version.sh`

要求：
- 输出 `spoke/Bundler.toml` 中 `version = "..."`
- 失败时给出清晰错误

- [ ] **Step 2: 让本地 release 脚本改用统一版本号来源**

要求：
- `scripts/build-release.sh` 不再写死 `1.0.0`
- `CFBundleShortVersionString` 使用脚本读取结果
- `CFBundleIdentifier` 使用 `com.spokeanywhere`
- `codesign --identifier` 使用 `com.spokeanywhere`

- [ ] **Step 3: 让 GitHub release workflow 改用统一版本号来源**

要求：
- `.github/workflows/release.yml` 中不再硬编码 `1.0.0`
- `Create App Bundle` 时读取脚本输出
- `Get Version` 继续使用 tag 名作为 release version 展示

- [ ] **Step 4: 校验本地版本读取逻辑**

Run:

```bash
bash scripts/read-spoke-version.sh
```

Expected:
- 输出当前 `spoke/Bundler.toml` version

### Task 3: 统一 release notes 入口与 GitHub Release 对接

**Files:**
- Modify: `.github/workflows/release.yml`
- Create: `scripts/resolve-release-notes.sh`
- Reference: `docs/releases/`

- [ ] **Step 1: 新增 release notes 定位脚本**

建议路径：
- `scripts/resolve-release-notes.sh`

要求：
- 输入参数：版本名，例如 `v0.1.0`
- 输出对应文件路径，例如 `docs/releases/v0.1.0.md`
- 如果文件不存在，返回非零并打印清晰错误

- [ ] **Step 2: 让 GitHub release workflow 使用仓库内 notes 作为 body source**

要求：
- 不再使用 workflow 里写死的 release body
- 先校验 `docs/releases/<tag>.md` 存在
- 再把它传给 GitHub Release action

- [ ] **Step 3: 标记 beta release 为 prerelease**

要求：
- 如果 tag 包含 `-beta.`
- 则 GitHub Release 使用 `prerelease: true`
- 否则为 `false`

- [ ] **Step 4: 校验 workflow 文本是否已从“硬编码 body”迁移到“body_path / 文件来源”**

Run:

```bash
sed -n '1,220p' .github/workflows/release.yml
sed -n '1,200p' scripts/resolve-release-notes.sh
```

Expected:
- workflow 不再手写 release notes 正文
- release body 来源明确来自 `docs/releases/<version>.md`

### Task 4: 创建用户级通用 release skill

**Files:**
- Create: `/Users/bigdan/.claude/skills/release-discipline/SKILL.md`
- Create: `/Users/bigdan/.claude/skills/release-discipline/references/versioning-policy.md`
- Create: `/Users/bigdan/.claude/skills/release-discipline/assets/release-note-template.md`

- [ ] **Step 1: 创建 skill 目录骨架**

路径：

```text
/Users/bigdan/.claude/skills/release-discipline/
```

子目录：

```text
references/
assets/
```

- [ ] **Step 2: 编写 `SKILL.md`**

要求：
- skill 名称为 `release-discipline`
- 描述是“何时使用”，不是流程摘要
- 内容包含：
  - 什么时候该发 stable / beta / patch
  - 什么时候升 `X`，什么时候升 `Y`
  - canonical source 放仓库内的分层建议
  - private GitHub release 的定位
  - 如何维护 `Unreleased`

- [ ] **Step 3: 编写 `references/versioning-policy.md`**

要求：
- 用规则板形式总结版本号判定
- 包括 `v0.X.Y`、`beta`、`stable`、`patch`
- 不绑定 SpokenAnyWhere 名字

- [ ] **Step 4: 编写 `assets/release-note-template.md`**

要求：
- 提供单版本 release notes 模板
- 包含：
  - version
  - date
  - release type
  - summary
  - new
  - improvements
  - fixes
  - known issues
  - upgrade notes
  - artifacts

- [ ] **Step 5: 检查 skill 内容是否保持通用，不包含 SpokenAnyWhere 私有硬编码**

Run:

```bash
sed -n '1,240p' /Users/bigdan/.claude/skills/release-discipline/SKILL.md
sed -n '1,240p' /Users/bigdan/.claude/skills/release-discipline/references/versioning-policy.md
sed -n '1,240p' /Users/bigdan/.claude/skills/release-discipline/assets/release-note-template.md
```

Expected:
- skill 是通用方法论，不写死 SpokenAnyWhere 特定路径或 bundle id

### Task 5: 最终验证与收口

**Files:**
- Modify: `.draft.md`
- Verify: `CHANGELOG.md`
- Verify: `docs/releases/v0.1.0.md`
- Verify: `.github/workflows/release.yml`
- Verify: `scripts/build-release.sh`
- Verify: `scripts/read-spoke-version.sh`
- Verify: `scripts/resolve-release-notes.sh`
- Verify: `/Users/bigdan/.claude/skills/release-discipline/*`

- [ ] **Step 1: 运行项目侧基础验证**

Run:

```bash
bash scripts/read-spoke-version.sh
bash scripts/resolve-release-notes.sh v0.1.0
swift build
```

Expected:
- 版本读取成功
- `v0.1.0` notes 解析成功
- 项目仍可构建

- [ ] **Step 2: 复查 release 入口是否已经统一**

检查点：
- 版本号来源来自 `spoke/Bundler.toml`
- 本地 release script 不再使用旧 bundle id
- GitHub workflow 使用仓库内单版本 notes

- [ ] **Step 3: 同步 `.draft.md` 并总结本轮 release discipline 已落地点**

- [ ] **Step 4: 准备提交**

建议提交拆分：

```bash
git add CHANGELOG.md docs/releases/v0.1.0.md .github/workflows/release.yml scripts/build-release.sh scripts/read-spoke-version.sh scripts/resolve-release-notes.sh docs/superpowers/specs/2026-04-20-release-discipline-design.md docs/superpowers/plans/2026-04-20-release-discipline-implementation.md
git commit -m "feat: establish release discipline"
```

用户级 skill 建议单独提交说明或独立记录，不混入项目仓库提交语义。

