# Research Summary: 截图放大优化配置流程

## 📁 Code Context
1.  `UI/Settings/TranscriptionModelSettingsView.swift` - 参考现有的模型下载和配置 UI 模式。
2.  `Services/ImageEnhancementService.swift` - 现有的增强服务，需要扩展支持 AI 模型。
3.  `Core/Screenshot/ScreenshotManager.swift` - 截图流程管理。

## 📜 Memory Context
- **T075**: 截图放大增强 (Lanczos+Sharpen) 已实现。
- **Download Manager**: 之前在 Transcription 模块有相关经验 (ModelDownloadState)。

## 🌐 External Research
1.  **CoreML Model Source**: 
    - HuggingFace: `TheMurusTeam/coreml-upscaler-realesrgan512`
    - URL (估计): `https://huggingface.co/TheMurusTeam/coreml-upscaler-realesrgan512/resolve/main/RealESRGAN512.mlmodel` (需验证文件名)
2.  **Swift Implementation**:
    - 下载: `URLSessionDownloadTask` (断点续传/进度监控).
    - 编译: `MLModel.compileModel(at:)` -> 产生临时 `.mlmodelc` -> 移动到 App Support 目录持久化或缓存。
    - 加载: `MLModel(contentsOf:)`.

## 💡 Key Takeaways
1.  **设置位置**: 新建 `ScreenshotSettingsView`，集成到 `SettingsView`。
2.  **功能选项**:
    - **Optimization Mode**: 
        - `Basic (Lanczos + Sharpen)` [默认]
        - `AI Enhanced (Real-ESRGAN)` [需下载]
3.  **模型管理**:
    - 类似于语音模型，需要状态机: `notDownloaded`, `downloading`, `compiled`, `ready`.
    - 只有当状态为 `ready` 时，AI 选项才可用（或自动选中）。
4.  **实现路径**:
    - 扩展 `ImageEnhancementService` 支持 CoreML 调用。
    - 添加 `ImageUpscaleModelManager` 负责下载和编译。
    - 开发 `ScreenshotSettingsView` UI。

## ⚠️ 风险点
- **包体积**: AI 模型约 50-100MB，必须按需下载。
- **性能**: Real-ESRGAN 推理需耗时（可能几秒），与 Lanczos (50ms) 差距巨大，需要 Loading 状态或特定交互（如用户停止缩放 1s 后触发，显示"Enhancing..."）。
