# App Layer: Final Risk Assessment (T+90)

**Analyst**: claude-2
**Date**: 2026-02-22
**Scope**: App/ entry flow, startup sequence, and service coordination

---

## Executive Summary

**Audit Conclusion**: **Conditional Go**

**Rationale**:
- **Operational Readiness**: Go (startup sequence functional, 12-step initialization completes in ~220ms)
- **Maintainability**: Conditional Go (9 identified risks, 3 high-priority requiring mitigation)
- **Integration**: Aligns with team consensus (code: build system gaps, codex-1: architecture coupling)

---

## 1. Risk Inventory (App/ Layer)

### 1.1 High Priority (P1)

**RISK-APP-002: RecordingController Initialization Cascade**
- **Status**: ACTIVE, NO MITIGATION
- **Location**: `AppDelegate.swift:71` → `RecordingController.shared.start()`
- **Issue**: Single service init triggers 10+ singleton initializations
- **Impact**:
  - Unpredictable startup time if any dependency is slow
  - Hidden initialization order dependencies
  - Difficult to isolate failures
- **Evidence**: `RecordingController.swift:24-35` aggregates 9+ services
- **Quantification**: 10+ cascaded inits, ~100ms overhead
- **Mitigation**: None currently
- **Recommendation**: Lazy initialization or explicit dependency injection

**RISK-APP-006: Incomplete Termination Cleanup**
- **Status**: ACTIVE
- **Location**: `AppDelegate.swift:281-286`
- **Issue**: Only 4 services explicitly stopped on termination:
  - RecordingController ✓
  - TrackpadSwipeService ✓
  - SelectionToolbarManager ✓
  - ResourceMonitor ✓
- **Missing**: 20+ other services not explicitly cleaned up
- **Impact**:
  - Potential resource leaks (file handles, observers, timers)
  - Incomplete state saves
  - Zombie callbacks firing after termination
- **Evidence**: 25 singleton services identified, only 4 stopped
- **Recommendation**: Implement formal lifecycle protocol for all services

**RISK-APP-007: Callback Leak Risk**
- **Status**: ACTIVE
- **Location**: Multiple services
- **Issue**: Callbacks registered but never unregistered
- **Examples**:
  - `RecordingController.init()`: Audio callback session never removed
  - `AppDelegate.setupSelectionToolbar()`: NotificationCenter observer never removed
- **Impact**: Memory leaks, zombie callbacks
- **Mitigation**: `[weak self]` prevents retain cycles but callbacks still fire
- **Recommendation**: Explicit callback cleanup in deinit/termination

---

### 1.2 Medium Priority (P2)

**RISK-APP-001: Screenshot Restoration Blocking**
- **Status**: MITIGATED (moved to async Task)
- **Location**: `AppDelegate.swift:154`
- **Previous Issue**: Synchronous `restoreAll()` blocked main thread
- **Current**: `Task(priority: .utility) { await restoreAll() }`
- **Residual Risk**: Large number of pinned screenshots still slow (50-500ms)
- **Recommendation**: Add progress indicator or limit restoration count

**RISK-APP-008: Callback Ordering Risk**
- **Status**: ACTIVE
- **Issue**: No guaranteed callback execution order
- **Impact**: Race conditions in multi-service scenarios
- **Example**: Both RecordingController and QuickAskService could listen to same event
- **Current State**: Relies on registration order (implicit)
- **Recommendation**: Priority-based callback execution or explicit ordering

**RISK-APP-009: Async Callback Coordination Risk**
- **Status**: ACTIVE
- **Pattern**: `Task { @MainActor in self?.callback() }`
- **Issue**: Task creates new async context, no error propagation
- **Impact**: Silent failures if callback throws
- **Example**: `completeRecordingSession()` errors swallowed by Task
- **Recommendation**: Explicit error handling in async callbacks

---

### 1.3 Low Priority (P3)

**RISK-APP-003: Dictionary Precompilation**
- **Status**: MITIGATED (background task)
- **Location**: `AppDelegate.swift:92`
- **Issue**: Can take several seconds
- **Current**: `Task.detached(priority: .background)`
- **Residual Risk**: None (non-blocking)

**RISK-APP-004: Audio Callback Conflicts**
- **Status**: MITIGATED (session-based callbacks)
- **Location**: `RecordingController.swift:47`
- **Issue**: Multiple services setting audio callbacks could conflict
- **Mitigation**: Session-based callback management via `createCallbackSession()`
- **Residual Risk**: Low (architecture prevents conflicts)

**RISK-APP-005: Potential Circular Init**
- **Status**: NEEDS VERIFICATION
- **Issue**: 25 singletons with complex dependencies
- **Example**: RecordingController → HotKeyService → (back to RecordingController?)
- **Mitigation**: Lazy initialization breaks most cycles
- **Recommendation**: Dependency graph analysis to confirm no cycles

---

## 2. Quantitative Evidence

### 2.1 Service Density
- **Total Singleton Services**: 25
- **Services with Callbacks**: 7
- **NotificationCenter Observers**: 6 (in App/ layer)
- **Callback Chains**: 4 primary (Recording, QuickAsk, Screenshot, Dictionary)

### 2.2 Startup Performance
```
Synchronous Path:  ~220ms
  - Phase 1 (0-2):   ~50ms  (Critical infrastructure)
  - Phase 2 (3-5):   ~100ms (Core services + cascade)
  - Phase 3 (6-6.1): ~10ms  (Task spawn)
  - Phase 4 (6.5-6.6): ~5ms (Task spawn)
  - Phase 5 (7-11):  ~50ms  (Feature services)

Background Work (parallel):
  - History cleanup:         ~100-500ms
  - Dictionary precompilation: ~1-3s
  - Speech engine warmup:    ~1.8s
  - Screenshot restoration:  ~50-500ms
```

### 2.3 Callback Frequency
- **High Frequency** (10-60 Hz): `onAudioLevelUpdate`, `onPartialResult`
- **Low Frequency** (user-triggered): `onRecordingStart/Stop`, `onComplete/Cancel`

---

## 3. Cross-Layer Integration

### 3.1 Alignment with Build System Risks (code)

**code's P1 Risks**:
1. CI lacks strict-concurrency gate
2. `run-concurrency-check.sh` doesn't fail on warnings

**App/ Layer Impact**:
- App/ layer has 0 concurrency warnings (verified)
- But future changes could introduce warnings without CI blocking
- **Recommendation**: Support code's proposal for strict-concurrency gate

### 3.2 Alignment with Architecture Risks (codex-1)

**codex-1's P1 Risks**:
1. P1-ARCH-001: Global singleton density
2. P1-ARCH-002: UI direct-connects to Service/Core
3. P1-ARCH-003: Dual-track dependencies

**App/ Layer Contribution**:
- App/ layer is the **root cause** of singleton pattern (AppDelegate initializes all)
- RecordingController is prime example of P1-ARCH-001 (aggregates 9+ singletons)
- AppDelegate directly sets callbacks on services (contributes to P1-ARCH-003)

**Shared Responsibility**:
- RISK-APP-002 (cascade) is manifestation of P1-ARCH-001 (singleton density)
- RISK-APP-006 (cleanup) is manifestation of P1-ARCH-001 (lifecycle management)

---

## 4. Go/No-Go Criteria (App/ Layer)

### 4.1 Current State Assessment

**Go Criteria** (Met ✓):
- ✓ Startup sequence completes successfully
- ✓ All 12 initialization steps functional
- ✓ Performance within acceptable range (~220ms sync path)
- ✓ Critical risks mitigated (RISK-APP-001, RISK-APP-004)

**Conditional Go Criteria** (Gaps):
- ⚠ High-priority risks unmitigated (RISK-APP-002, RISK-APP-006, RISK-APP-007)
- ⚠ No formal service lifecycle protocol
- ⚠ Callback management ad-hoc

### 4.2 Recommendation

**If goal is "current version can ship"**: **Go**
- Core functionality works
- Performance acceptable
- Critical risks mitigated

**If goal is "sustainable evolution with low regression cost"**: **Conditional Go**
- Must address P1 risks (RISK-APP-002, RISK-APP-006, RISK-APP-007)
- Should implement formal service lifecycle
- Should centralize callback management

---

## 5. Mitigation Roadmap

### 5.1 Week 1 (P1 Risks)

**RISK-APP-002: RecordingController Cascade**
- **Action**: Implement lazy initialization for non-critical services
- **Verification**: Measure startup time before/after
- **DoD**: Startup time reduced by 20%, cascade depth < 5

**RISK-APP-006: Incomplete Cleanup**
- **Action**: Add `stop()` method to all services, call in `applicationWillTerminate`
- **Verification**: Audit all 25 services for cleanup
- **DoD**: All services implement lifecycle protocol

**RISK-APP-007: Callback Leaks**
- **Action**: Audit all callback registrations, add cleanup in deinit
- **Verification**: Memory profiler shows no leaks after termination
- **DoD**: All callbacks explicitly unregistered

### 5.2 Week 2 (P2 Risks)

**RISK-APP-008: Callback Ordering**
- **Action**: Implement priority-based callback execution
- **Verification**: Unit tests for callback order
- **DoD**: Callbacks execute in predictable order

**RISK-APP-009: Async Callback Errors**
- **Action**: Add error handling to all async callbacks
- **Verification**: Error logs show no silent failures
- **DoD**: All async callbacks log errors

### 5.3 Week 3-4 (Architecture Alignment)

**Align with codex-1's P1-ARCH-001**:
- **Action**: Migrate from singletons to dependency injection
- **Scope**: Start with RecordingController (highest impact)
- **DoD**: RecordingController uses DI, no direct `.shared` calls

**Align with code's P1 Build Risks**:
- **Action**: Support strict-concurrency gate in CI
- **Scope**: Ensure App/ layer remains 0 warnings
- **DoD**: CI blocks PRs with concurrency warnings

---

## 6. Architectural Observations

### 6.1 Strengths
1. **Clear Sequencing**: 12-step startup with explicit ordering
2. **Instrumentation**: Built-in timing logs (`SPOKE_PERF_LOG=1`)
3. **Async Optimization**: Heavy work moved to background
4. **Memory Safety**: `[weak self]` prevents retain cycles

### 6.2 Weaknesses
1. **Tight Coupling**: RecordingController depends on 10+ services
2. **Implicit Dependencies**: Singleton init order not enforced
3. **Limited Cleanup**: Most services don't implement explicit teardown
4. **Callback Complexity**: Multiple callback chains hard to trace

### 6.3 Comparison to Best Practices

**Current (Singleton + Closure Callbacks)**:
- ✅ Simple, direct
- ❌ Hard to trace, no compile-time safety

**Alternative: Protocol/Delegate**:
- ✅ Type-safe, explicit
- ❌ More boilerplate, tighter coupling

**Alternative: Combine Publishers**:
- ✅ Composable, error handling
- ❌ Steeper learning curve, more complex

**Recommendation**: Hybrid approach
- Keep closures for simple 1-to-1 callbacks
- Use protocols for complex multi-service coordination
- Consider Combine for event streams (audio levels, partial results)

---

## 7. Integration with Team Deliverables

### 7.1 Three-Dimensional Risk View

**Dimension 1: Build System (code)**
- P1: CI lacks strict-concurrency gate
- P1: Concurrency check script doesn't fail on warnings
- Impact: Future App/ changes could introduce warnings without blocking

**Dimension 2: Architecture (codex-1)**
- P1-ARCH-001: Global singleton density (25 services)
- P1-ARCH-002: UI direct-connects to Service/Core
- P1-ARCH-003: Dual-track dependencies
- Impact: App/ layer is root cause of singleton pattern

**Dimension 3: App/ Layer (claude-2)**
- P1: RecordingController cascade (RISK-APP-002)
- P1: Incomplete cleanup (RISK-APP-006)
- P1: Callback leaks (RISK-APP-007)
- Impact: Startup performance and resource management

### 7.2 Unified Conclusion

**Overall Assessment**: **Conditional Go**

**Rationale**:
- **Operational**: All three dimensions show functional baseline
- **Quality Gates**: Build system gaps (code's P1) must be addressed
- **Architecture**: Structural risks (codex-1's P1) require refactoring
- **App/ Layer**: Lifecycle and callback management need formalization

**Priority Order**:
1. **Week 1**: Address build system P1 gaps (code's proposal)
2. **Week 2**: Address App/ layer P1 risks (this document)
3. **Week 3-4**: Address architecture P1 risks (codex-1's proposal)

---

## 8. Deliverables Summary

### 8.1 Documentation Artifacts
- ✅ `./app-layer-startup-sequence.md` (T+30)
- ✅ `./app-layer-callback-chains.md` (T+60)
- ✅ `./app-layer-risk-assessment.md` (T+90, this document)

### 8.2 Risk Inventory
- **Total Risks Identified**: 9
- **High Priority (P1)**: 3
- **Medium Priority (P2)**: 3
- **Low Priority (P3)**: 3

### 8.3 Evidence Base
- **Code Locations**: 15+ specific file:line references
- **Quantitative Metrics**: Startup timing, service counts, callback frequency
- **Cross-References**: Aligned with code and codex-1 deliverables

---

## 9. Recommendations for claude-1 (Foreman)

### 9.1 Immediate Actions
1. **Accept Conditional Go conclusion** (team consensus)
2. **Prioritize code's P1 build system patches** (highest ROI)
3. **Schedule Week 1-2 for App/ layer P1 mitigation** (this document)

### 9.2 Documentation Integration
1. **Merge three risk dimensions** into unified architecture document
2. **Create single mitigation roadmap** (1-week, 2-week, 3-4 week phases)
3. **Establish verification criteria** for each phase

### 9.3 Next Steps
1. **Review and approve** this T+90 deliverable
2. **Coordinate with code** on build system patch implementation
3. **Coordinate with codex-1** on architecture refactoring backlog
4. **Present unified plan** to user for approval

---

**Status**: T+90 Final Deliverable Complete ✅
**Conclusion**: Conditional Go (aligned with team consensus)
**Next**: Await foreman integration and user approval
