# Spec: Screenshot Upscaling Configuration & AI Integration

## 1. Overview
Allow users to configure the screenshot upscaling behavior in Settings. Provide two modes:
1.  **Basic (Default)**: Current Lanczos + Sharpen implementation.
2.  **AI Enhanced**: Real-ESRGAN CoreML model (requires download).

## 2. Requirements

### 2.1 Settings UI
- New Tab/Section: **Screenshot** in `SettingsView`.
- **Upscaling Mode** selection:
  - `None`: Disable upscaling.
  - `Basic`: Lanczos + Sharpen.
  - `AI (Real-ESRGAN)`: Deep learning based super-resolution.
- **AI Model Management**:
  - If "AI" is selected but not downloaded: Show "Download Model" button.
  - Show download progress bar.
  - Manage model state: `Not Downloaded`, `Downloading`, `Compiled`, `Ready`.
  - Delete model option.

### 2.2 Core Logic
- **Download Manager**:
  - Download `.mlmodel` from HuggingFace (`TheMurusTeam/coreml-upscaler-realesrgan512`).
  - Compile using `MLModel.compileModel(at:)`.
  - Move compiled `.mlmodelc` to `~/Library/Application Support/Spoke/Models/`.
- **Enhancement Service**:
  - Update `ImageEnhancementService` to check settings.
  - If `.ai` mode is active and model is ready:
    - Load CoreML model.
    - Perform inference (Vision `VNCoreMLRequest`).
    - Fallback to `.basic` if model fails or not ready.

### 2.3 User Experience
- **Debounce**: Keep existing 300ms debounce.
- **Feedback**: When using AI mode (slower), consider showing a loading indicator on the screenshot window if inference takes > 500ms. (Out of scope for this task, keep it simple first).

## 3. Implementation Plan

1.  **ScreenshotSettings**: create `ScreenshotSettings` struct (ObservableObject) backed by `UserDefaults`.
2.  **ModelManager**: Create `ImageUpscalerModelManager` to handle download/compile.
3.  **Service Update**: Modify `ImageEnhancementService` to integrate `ModelManager` and execute CoreML prediction.
4.  **UI**: Create `ScreenshotSettingsView` and add to main settings.

## 4. Technical Constraints
- Model Size: ~50MB.
- Interface: Swift/SwiftUI.
- OS: macOS 12+.

## 5. Out of Scope
- Multiple AI models (start with one).
- GPU customization (auto-select Neural Engine).
