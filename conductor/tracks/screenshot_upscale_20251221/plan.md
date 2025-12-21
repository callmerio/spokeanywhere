# Plan: Screenshot Upscaling Settings & AI

## Phase 1: Infrastructure (Settings & Model Manager)
- [ ] **Task 1.1**: Create `ScreenshotSettings.swift`
  - [ ] Define `UpscalingMode` enum (none, basic, ai).
  - [ ] Persist settings using `AppStorage` or `UserDefaults`.
- [ ] **Task 1.2**: Create `ImageUpscalerModelManager.swift`
  - [ ] Define `ModelDownloadState` enum.
  - [ ] Implement `downloadModel()` using `URLSession`.
  - [ ] Implement `compileModel()` using `MLModel.compileModel`.
  - [ ] Manage file paths (Application Support).

## Phase 2: Core Implementation (AI Enhancement)
- [ ] **Task 2.1**: Update `ImageEnhancementService`
  - [ ] Add `Vision` framework support.
  - [ ] Implement `enhanceWithAI(image:)` method.
  - [ ] Load compiled model dynamically.
  - [ ] Integrate mode switching logic (`enhance` method checks settings).

## Phase 3: User Interface
- [ ] **Task 3.1**: Create `ScreenshotSettingsView.swift`
  - [ ] UI for selecting Upscaling Mode.
  - [ ] UI for Model Download (Button, Progress Bar, State Label).
- [ ] **Task 3.2**: Integrate into `SettingsView.swift`
  - [ ] Add new Tab item "Screenshot".

## Phase 4: Verification
- [ ] **Task 4.1**: Manual Test
  - [ ] Verify Basic mode works as before.
  - [ ] Verify Download flow works.
  - [ ] Verify AI mode works (visually check result).
