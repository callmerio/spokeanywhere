# Test Matrix: Milestone 1 (Quality & Stability)

This document outlines the test coverage required for M1 to ensure stability baseline and risk convergence.

## 1. Recording Pipeline (US-001)
| Scenario | Input | Expected Outcome | Verification |
| :--- | :--- | :--- | :--- |
| Normal Start/Stop | Global Hotkey (Hold/Toggle) | Audio captured, HUD shows recording status. | ✅ Unit (RecordingPipelineTests) |
| Device Disconnect | Pull microphone during recording | HUD shows `.noInputDevice` error with recovery suggestion. | ✅ Unit (AudioRecoveryPolicyTests) |
| Permission Denied | Revoke Mic permission | HUD shows `.permissionDenied` error. | ✅ Unit (RecordingStateTests) |
| Silent Recording | Record without speaking | HUD shows `.emptySpeech` error after stop. | ✅ Unit (RecordingPipelineTests) |

## 2. Audio Callback Routing (US-002)
| Scenario | Input | Expected Outcome | Verification |
| :--- | :--- | :--- | :--- |
| Concurrent Entry | Start Quick Ask while Recording | Recording session terminates cleanly; Quick Ask takes over. | ✅ Unit (AudioCallbackRouterTests) |
| Fast Switching | Rapidly toggle hotkey | No callback overrides; state remains consistent. | ✅ Unit (AudioCallbackRouterTests) |
| Session Cleanup | Finish session | All timers/observers/tasks released. | Sanitizer/Leak Check (⚠️ Environment Blocked) |

## 3. AI Pipeline & Fallback (G1/US-001)
| Scenario | Input | Expected Outcome | Verification |
| :--- | :--- | :--- | :--- |
| LLM Network Error | Disconnect internet after ASR | HUD shows LLM error; Raw text is preserved and copied. | ✅ Unit (RecordingPipelineTests) |
| LLM Timeout | Mock slow LLM response | System fallbacks to raw text; HUD indicates AI failure. | Integration (Manual Verified) |
| Gemini Refinement | Valid ASR + Gemini API | Text refined and copied to clipboard. | E2E (Manual Verified) |

## 4. UI Stability & Concurrency (US-003)
| Scenario | Input | Expected Outcome | Verification |
| :--- | :--- | :--- | :--- |
| MainActor Isolation | State updates from background | No "Publishing from background thread" warnings. | ✅ Unit (RecordingStateTests) |
| HUD Lifecycle | Rapid Show/Hide/Fail | HUD panel orders in/out correctly without crashing. | Stress Test (Manual Verified) |
| Floating UI Re-position | Drag/Resize (if enabled) | Panel remains interactive and correctly positioned. | Manual Verified |

## 5. Regression Checklist (Critical Points)
- [x] `AppAudioCaptureService.swift:203`: Rolled back to `DispatchQueue.main.async` (Correct implementation).
- [ ] `ServiceContainer.swift:245`: ⚠️ 1 Concurrency warning remains (static shared property).
- [x] `RecordingController.swift:200`: Verified no callback overlap via `AudioCallbackRouter`.

---
*Updated by gemini-1 on 2026-02-22. M1 Stability Baseline: 90% Verified.*
