# Project SpokenAnyWhere: The Constitution

## Vision
SpokenAnyWhere is a macOS desktop application designed for creators and knowledge workers, providing a unified, efficient pipeline for voice-to-text transcription followed by AI-powered text processing.
*(Long-term Vision: Floating "Dynamic Island" style capsule and real-time caption overlay.)*

## Goals (Current Phase: M2 Convergence)
- **G1: Reliability**: (M1 Baseline Established ✅)
- **G2: Concurrency**: Reach 100% Swift 6 strict concurrency compliance; zero high-priority warnings.
- **G3: Quality Gate**: Harden CI/CD with blocking concurrency checks and resolved sanitizer paths.

## Scope (M2 Alignment)
- **In-Scope**: Resolve all remaining 20+ concurrency warnings (Group A-D), fix environment blockers for sanitizers, structural optimization for safety.
- **Out-of-Scope**: No new UI/API features (e.g., Whisper Local, redesigns).

## Milestones
- **Milestone 1**: Stability baseline + risk convergence (Done ✅).
- **Milestone 2 (Current)**: **Structural optimization + enhanced quality gates (US-004/005)**.
    - Resolve all Group A-D concurrency warnings.
    - Standardize local and CI verification workflows.

## Constraints
- **Platform**: macOS 14.0+ (Native Swift/AppKit/SwiftUI).
- **Language**: Swift 5.9+ (Targeting Swift 6 strict concurrency).
- **Quality**: No high-priority concurrency warnings; zero-tolerance for random test failures.
- **Privacy**: Local-first processing; explicit consent for remote AI.

## Risks & Critical Points
- **Concurrency Isolation**: Actor/MainActor boundary issues (e.g., `ServiceContainer.swift:245`).
- **Audio Callbacks**: Risks of callback overrides between Recording and Quick Ask (e.g., `RecordingController.swift:200`).
- **UI Scheduling**: Regression risks when changing dispatch semantics (e.g., `AppAudioCaptureService.swift:203`).
- **Resource Management**: Reliable cleanup of observers/timers/tasks at session boundaries.

## Definition of Done (DoD)
- [ ] **Build**: `cd spoke && swift build` (Swift 6) passes with **0 new high-priority warnings**.
- [ ] **Test**: `cd spoke && swift test --parallel` passes 100%.
- [ ] **Concurrency**: `cd spoke && ./Tests/run-concurrency-check.sh` passes without high-priority warnings.
- [ ] **Sanitizer (Thread)**: CI workflow `sanitizer.yml/sanitizer-thread` passes (CI-only due to macOS dyld policy).
- [ ] **Sanitizer (Address)**: CI workflow `sanitizer.yml/sanitizer-address` passes (CI-only due to macOS dyld policy).
- [ ] **Feature Verification**: Verified manually or via scripts in targeted macOS environment.
- [ ] **Documentation**: README, PROJECT.md, and relevant task logs updated.

**Note on Sanitizers**: Thread/Address Sanitizers are verified in CI only. Local execution is blocked by macOS dyld platform policy (`Sanitizer load violates platform policy`) due to SIP/Hardened Runtime restrictions. This is an environment constraint, not a code issue. See `docs/quality-playbook.md` for details.

## Verification Commands

**Local verification** (executable on developer machines):
```bash
cd spoke
swift build
swift test --parallel
./Tests/run-concurrency-check.sh
```

**CI-only verification** (blocked locally by macOS dyld policy):
```bash
# These commands are CI-only due to environment constraints
# Local execution fails with: "Sanitizer load violates platform policy"
cd spoke
swift test --sanitize=thread --parallel   # CI: sanitizer.yml/sanitizer-thread
swift test --sanitize=address --parallel  # CI: sanitizer.yml/sanitizer-address
```

## Team Roles
- **Foreman (claude-1)**: Orchestration, architecture, and core outcomes.
- **Peer (codex-1)**: Backend, models, data persistence, and quality gates.
- **Peer (gemini-1)**: UI/UX (Floating Capsule, Settings), Remote API integration, and user-facing features.

---
*Updated by gemini-1 on 2026-02-22 based on team feedback.*
