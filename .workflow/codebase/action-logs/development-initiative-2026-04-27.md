# Development Initiative Brief — 2026-04-27

## Status

SpokenAnyWhere 当前开发状态可以归纳为：产品叙事已经从“语音转写 + AI 精炼”升级为“桌面理解层 + 工作流层”；工程主线正在围绕 overlay / floating surfaces 的可靠性、可验证性和上下文流转体验收敛。

本文件把 Git 历史、工作树状态、文档时间线、Serena 记忆、Maestro 文档、旧 CCW/.agent 遗留资料与 `docs/superpowers/` 计划串起来，作为后续 Maestro 快速加载的立项入口。

## Source Priority

后续加载上下文时，按这个顺序读：

1. `.workflow/project.md` — 当前 Maestro 项目定义、约束、已登记进度入口。
2. `.workflow/codebase/action-logs/development-progress-2026-04-27.md` — Git/worktree 进度快照。
3. `.workflow/codebase/action-logs/development-initiative-2026-04-27.md` — 本文件，解释立项脉络与资料迁移策略。
4. `ROADMAP.md` — 当前产品主线骨架。
5. `ROADMAP.detail.md` — 2026-04-18/19 产品能力地图展开稿。
6. `docs/superpowers/specs/*` and `docs/superpowers/plans/*` — 2026-04-11 到 2026-04-21 的功能级设计/实施计划。
7. Git history for deleted `.agent/` and `.workflow/.ccw-session/` — 仅作历史证据，不作为当前执行系统。

## Timeline Interpretation

| Date | Evidence | Interpretation |
|------|----------|----------------|
| 2025-12-10 | `ROADMAP.md` first added | 项目开始有工程路线图。 |
| 2025-12-20/21 | `.workflow/.ccw-session/*`, `.agent/*` added | CCW/agent 框架开始承接截图、审查、AI workflow 等开发编排。 |
| 2025-12-29 | `.workflow/.ccw-session/review-report.md` updated | Live Caption 滚动性能与风险分析进入历史知识库。 |
| 2026-04-11 | screenshot text annotation specs/plans | 截图从 capture 走向标注、文字、后续动作。 |
| 2026-04-13 to 2026-04-18 | `ROADMAP.md` product capability updates | 产品叙事从工程任务转向能力地图与桌面上下文。 |
| 2026-04-19 | `ROADMAP.md`, `ROADMAP.detail.md`, pinned-text docs | PinnedText/桌面对象化成为产品杠杆，Roadmap 分成主文档和展开稿。 |
| 2026-04-20 | overlay contract + release discipline | PinnedText/Screenshot 开始收敛为统一 overlay 合同，同时建立 release discipline。 |
| 2026-04-21 | live-caption handoff + collapsed visibility plan | Live Caption collapsed focus 进入明确 bug/contract 修复阶段。 |
| 2026-04-22 | 11 commits after `origin/main` | collapsed focus anchor/probe/bootstrap 修复形成已提交工程切片。 |
| 2026-04-27 | `.workflow/` Maestro docs generated | 当前进入 Maestro 作为主 workflow 文档系统。 |

## Current Initiative Framing

### Product Thesis

SpokenAnyWhere 的核心不是继续堆单点功能，而是把桌面上正在发生的内容快速变成可提问、可加工、可沉淀、可流转的上下文。

当前立项主轴：

- Long-term axis: `跨应用流转`
- Breakout path: `看屏即问`
- Engineering convergence: overlay-like surfaces 的稳定性、可验证性、上下文返回能力

### Capability Maturity

| Layer | Current State | Direction |
|-------|---------------|-----------|
| Capture / Ingest | 强：Screenshot, OCR, Selection, Clipboard, Voice, Live Caption, PinnedText source | 收束成统一 context package，而不是继续加入口。 |
| Understanding | 中：Quick Ask, Translation, Dictionary, AI processing | 强化“看屏即问”和多来源上下文拼装。 |
| Action | 中：Answer Panel, Message Panel, Toolbar actions, Screenshot actions | 统一动作语言，减少入口差异感。 |
| Return / Persistence | 高潜力：PinnedText, History, desktop objects | 把结果送回用户手边，而不是一次性回答后消失。 |
| Personalization | 中高：Settings, AppRule, AIProviderConfig, Dictionary | 从设置堆栈演进为个人上下文系统。 |

## Git-Based Current Progress

### Committed Slice

`origin/main..HEAD` 有 11 个提交，主题明确：Live Caption collapsed-focus stabilization。

该切片已经包括：

- collapsed focus anchor semantics tests
- collapsed focus geometry helpers
- scroll delta clamp
- latest Chinese block anchoring
- production-path probes
- probe diagnostics in open launch flow
- probe bootstrap lifecycle cleanup
- prevention of collapsed captions re-following document bottom

### Uncommitted Slice

当前工作树混合了 5 类内容：

1. Maestro workflow/docs initialization.
2. Roadmap/product docs rewrite and backups.
3. Live Caption runtime/debug/test follow-up.
4. App lifecycle/runtime helper extraction.
5. Cleanup/deletion of old CCW/.agent/scratch/demo artifacts.

这个混合状态不适合一次性 commit。后续应该按语义拆分。

## Legacy CCW / `.agent` Migration Decision

### What `.agent` Was

`.agent` 是旧 CCW 框架的运行入口与角色/规则/模板目录：

- dispatcher: `/ccw`
- workflows: fix, plan, lifecycle, review, tdd, brainstorm
- roles: PM, architect, QA, UX, Codex/Gemini/Qwen 等
- schemas/templates: context package, plan schema, tech-stack templates

### Current Decision

`.agent` 不应继续作为当前执行框架保留。原因：

1. 当前项目已经切到 Maestro workflow 文档系统。
2. `.agent` 里大部分内容是“执行框架”，不是项目事实。
3. 继续保留会制造双 workflow 来源：CCW vs Maestro。
4. 旧框架的价值应迁移为历史知识、风险、决策和计划，而不是保留旧入口。

### What To Preserve

从旧 CCW 里值得迁移到 Maestro 的内容：

- `IMPL_PLAN.md` 中的截图重构思路：自建 region selection、annotation toolbar、resize handles。
- `review-report.md` 中的 Live Caption scroll 性能风险：`invalidateIntrinsicContentSize()`, timer/frame/bounds 多重触发, animation scroll risk。
- `mac-app-store-risk-review.md` 中的 App Store / TCC / private API 风险点。
- `context-package.json` 中能代表当时项目状态的上下文摘要。
- `.agent` rules 里仍适用的角色视角：architect/reviewer/test strategist/UX，但只作为 review lens，不作为执行框架。

### What Can Be Cleaned

可以清理或不恢复：

- `.agent/workflows/*` — 旧运行编排，已被 Maestro 替代。
- `.agent/templates/tech-stacks/*` — 通用模板，不是本项目事实。
- `.agent/schemas/*` — 旧 CCW 数据结构，不应与 Maestro state/doc-index 混用。
- `.workflow/.ccw-session/*` — 迁移后作为 historical source，不再作为 active state。
- `.workflow/.lite-fix/*` — 旧诊断 scratch，迁移结论即可。

### Cleanup Guardrail

不要直接删除历史价值未迁移的内容。推荐顺序：

1. 先把旧 CCW 关键结论迁移进 Maestro action logs/spec entries。
2. 再把 `.agent/` 与旧 `.workflow/.ccw-session/` 删除作为单独 cleanup commit。
3. cleanup commit message 明确说明：旧 CCW 框架 retired，知识已迁移到 Maestro docs。

## Superpowers Docs Migration

`docs/superpowers/` 不是废弃材料，它是 2026-04 功能级设计/实施记录，应该作为 Maestro 的 feature history 来源。

Recommended mapping:

| Source | Maestro Destination | Status |
|--------|---------------------|--------|
| `2026-04-11-screenshot-text-annotation-*` | Screenshot feature history / future roadmap input | Preserve as reference |
| `2026-04-19-pinned-text-hover-zoom-*` | Desktop object / PinnedText feature history | Preserve as reference |
| `2026-04-20-overlay-unified-contract-*` | Overlay architecture decision input | Convert to ADR later |
| `2026-04-20-release-discipline-*` | Release discipline / quality rules | Convert to spec or release docs later |
| `2026-04-21-live-caption-*` | Live Caption current workstream source | Keep high priority |

## Recommended Commit/Workstream Split

1. `chore(maestro): initialize workflow docs and codebase map`
   - `.workflow/project.md`
   - `.workflow/state.json`
   - `.workflow/config.json`
   - `.workflow/specs/*`
   - `.workflow/codebase/*`

2. `docs: refresh product roadmap around desktop context workflows`
   - `ROADMAP.md`
   - `ROADMAP.detail.md`
   - relevant roadmap backups only if intentionally kept

3. `feat/debug: add live caption debug simulation runtime`
   - `LiveCaptionDebugSimulationRuntimeHelpers.swift`
   - `livecaption-mock-stream.sh`
   - related tests

4. `fix/live-caption: continue collapsed focus runtime stabilization`
   - live caption manager/transcriber/view/window/helper changes
   - caption line buffer tests

5. `refactor(app): extract app runtime helper seams`
   - AppDelegate/AppLifecycle/AppRuntimeHelpers/PinnedTextRuntime/ScreenshotRuntime changes
   - app runtime tests

6. `chore: retire legacy CCW agent framework`
   - `.agent/` deletions
   - `.workflow/.ccw-session/` deletions
   - `.workflow/.lite-fix/` deletions
   - old `.tldr`, Excalidraw, demo docs if confirmed

## Validation Plan

Before code commits:

```bash
cd spoke
swift build
swift test --filter LiveCaption
swift test --filter AppLifecyclePlanTests
swift test --filter AppRuntimeHelpersTests
swift test --filter CaptionLineBufferTests
```

Before shipping or tagging:

```bash
cd spoke
swift test --parallel
bash Tests/run-concurrency-check.sh
./dev.sh
```

Manual validation still needed for overlay/window work:

- Live Caption collapsed mode with long previous sentence and latest Chinese translation.
- PinnedText hover/zoom/opacity interactions.
- Screenshot pin/overlay interactions.
- Debug simulation path does not leak into normal user runtime.

## Open Risks

1. `.agent/` deletion is reasonable, but only after CCW conclusions are migrated.
2. Worktree currently mixes docs, workflow setup, code, tests, debug tooling, and cleanup; commit boundaries need enforcement.
3. Debug simulation helpers must be checked for release safety.
4. Live Caption collapsed behavior remains visually sensitive and should not be accepted on tests alone.
5. Existing `.workflow/state.json` is initialized but does not yet contain milestones/roadmap phases; next Maestro step should generate or curate roadmap phases from this initiative.

## Recommended Next Maestro Step

Create a Maestro roadmap or milestone plan from this initiative with 1-2 phases:

1. Phase 1: Stabilize Desktop Overlay Runtime
   - Live Caption collapsed focus
   - PinnedText/Screenshot overlay contract
   - debug simulation and runtime helper seams
   - focused tests and manual UI validation

2. Phase 2: Consolidate Workflow Documentation and Release Hygiene
   - migrate CCW/superpowers conclusions
   - retire legacy framework files
   - finalize roadmap/state artifacts
   - run full quality gates

---
*Generated from Git history, worktree status, document mtimes, Serena memories, Maestro docs, deleted CCW/.agent sources via Git, and `docs/superpowers/` references on 2026-04-27.*
