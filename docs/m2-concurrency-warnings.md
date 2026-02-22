# M2 Convergence: Concurrency Warning List

This document groups and prioritizes the remaining concurrency warnings identified at the end of M1.

## Group A: Static Shared Property Issues (`#MutableGlobalVariable`)
*Risk: High. Potential for data races on singleton/global state.*

| Module | File:Line | Warning Type | Suggested Fix |
| :--- | :--- | :--- | :--- |
| Debug | `CrashLogger.swift:7` | static property 'shared' not safe | Add `@MainActor` or use `MainActor` isolation. |
| Dictionary | `DictionaryDefinitionParser.swift:50` | static property 'shared' not safe | Add `@MainActor`. |
| LLM | `KeychainService.swift:16` | static property 'cache' mutable | Protect with an Actor or use an atomic wrapper. |
| LLM | `KeychainService.swift:23` | static property 'useSimpleStorage' | Convert to constant or isolate to a global actor. |
| Screenshot | `ScreenshotSettings.swift:22` | static property 'shared' not safe | Add `@MainActor`. |
| Services | `AppSettings.swift:54` | static property 'shared' not safe | Add `@MainActor`. |
| Services | `ImageEnhancementService.swift:12` | static property 'shared' not safe | Add `@MainActor`. |
| Services | `ScreenCaptureBlurService.swift:9` | static property 'shared' not safe | Add `@MainActor`. |
| Services | `TrackpadSwipeService.swift:22` | static property 'shared' not safe | Add `@MainActor`. |
| UI | `SimpleMarkdownParser.swift:13` | static property 'fontCache' mutable | Use internal locking or isolate to a helper actor. |
| UI | `FloatingCapsuleView.swift:726/734` | PreferenceKey 'defaultValue' | Mark as `@MainActor` or use constant if possible. |
| UI | `VocabularyHighlightText.swift:157/159` | 'translationCache'/'loadingWords' | Isolate to a dedicated TranslationManager actor. |
| UI | `RegionSelectionView.swift:75` | static property 'sizeTagFont' | Add `@MainActor`. |

## Group B: Isolation & Actor Crossing (`#ActorIsolatedCall` / `#ConformanceIsolation`)
*Risk: Medium. Potential for unexpected UI behavior or crashes.*

| Module | File:Line | Warning Type | Suggested Fix |
| :--- | :--- | :--- | :--- |
| Services | `AppSettings.swift:71/73` | Call to isolated method from non-isolated | Wrap in `Task { @MainActor in }` or mark caller as `@MainActor`. |
| UI | `AnnotationCanvasView.swift:13` | Conformance crosses into MainActor | Mark protocol conformance with `@preconcurrency` or isolate entire class. |

## Group C: Data Race Risks during Transfer (`#SendingRisksDataRace`)
*Risk: Medium. Complex to fix, involving Sendable boundaries.*

| Module | File:Line | Warning Type | Suggested Fix |
| :--- | :--- | :--- | :--- |
| Services | `AppSettings.swift:174` | Sending 'self' risks data races | Ensure class is `Sendable` or use a different capture strategy. |
| Services | `ImageEnhancementService.swift:225` | Passing closure as 'sending' parameter | Refactor closure captures to ensure all captured values are `Sendable`. |

## Group D: Sendable Conformance Issues
*Risk: Low to Medium.*

| Module | File:Line | Warning Type | Suggested Fix |
| :--- | :--- | :--- | :--- |
| Services | `EdgeTTSService.swift:196/197` | WebSocketDelegate not Sendable | Mark as `@unchecked Sendable` if manually synchronized, or refactor to actor. |
| Screenshot | `ImageUpscalerModelManager.swift:29` | Mutable property in Sendable class | Change to constant or use `@MainActor`. |

---
*Drafted by gemini-1 on 2026-02-22.*
