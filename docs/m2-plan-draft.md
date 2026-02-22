# Milestone 2 Plan Draft: Convergence & Quality Gate

This draft outlines the proposed updates for `PROJECT.md` and `ROADMAP.md` to transition from M1 (Stability Baseline) to M2 (Convergence).

## 1. Proposed Update for `PROJECT.md`

### Current Focus (M2 Update)
- **M2: Concurrency & Sanitizer Convergence**:
    - [ ] Resolve all remaining 20+ concurrency warnings (Group A-D).
    - [ ] Fix environment blockers for Thread/Address Sanitizers in CI/CLI.
    - [ ] Reach 100% "Strict Concurrency" safety across all modules.
- **M2: CI Quality Gate Hardening**:
    - [ ] Integrate `run-concurrency-check.sh` as a blocking gate in CI.
    - [ ] Standardize local verification workflow for all team members.

### Milestones (M2 Update)
- **Milestone 1**: Stability baseline + risk convergence (Done ✅).
- **Milestone 2 (Current)**: **Structural optimization + enhanced quality gates (US-004/005)**.
    - Focus on Group A (Static Shared) and Group C (Data Races).
    - Resolve Sanitizer platform policy violations.

---

## 2. Proposed Update for `ROADMAP.md`

### ✅ 已完成功能 (Add M1 Achievements)
- **工程质量 (M1)**:
    - [x] 全量错误处理增强 (11/11 错误类型带恢复建议)
    - [x] HUD 详细错误反馈 UI
    - [x] 核心录音链路稳定性基线
    - [x] 调度语义风险回滚 (AppAudioCaptureService:203)

### 🔄 进行中 (M2 Stability)
- **稳定性收敛 (M2)**:
    - [ ] **并发警告清零** - 专项治理 20+ 存量警告
    - [ ] **Sanitizer 解阻** - 修复 CLI 环境下的权限/策略问题
    - [ ] **CI 门禁增强** - 并发检查作为强制 Gate

---

## 3. Execution Order for M2
1. **Phase 1: Easy Wins (Group A)**: Mass-apply `@MainActor` or `MainActor` isolation to singleton `.shared` properties.
2. **Phase 2: Environment (Sanitizers)**: Investigate why `Sanitizer load violates platform policy` occurs in CLI and fix it (likely signing or entitlement issue).
3. **Phase 3: Complex Races (Group C)**: Refactor `AppSettings` and `ImageEnhancementService` closure captures.
4. **Phase 4: Verification**: Run all tests with sanitizers active and verify zero warnings.

---
*Drafted by gemini-1 on 2026-02-22.*
