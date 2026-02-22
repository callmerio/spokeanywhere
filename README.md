# Project Summary: SpokenAnyWhere

## Overview
**SpokenAnyWhere** is a macOS desktop application designed for creators and knowledge workers. It provides a unified, efficient pipeline for **voice-to-text transcription** followed by **AI-powered text processing**.

## Core Value Proposition
*   **Unified Workflow**: Audio -> Transcription -> Text -> AI Prompt -> Output/Clipboard.
*   **Hybrid Intelligence**: Integrates local models (Apple STT, Whisper) for privacy/speed and remote APIs (Gemini) for complex processing.
*   **System Integration**: Global hotkey (⌥ + R) support to work seamlessly across any application.
*   **Customization**: Users can switch models and AI providers as easily as changing input methods.

## Target Audience
*   **Content Creators**: For transcribing spoken drafts to text.
*   **Knowledge Workers**: For meeting minutes and note-taking.
*   **Developers/Writers**: For dictating code comments or structured documentation.

## Key Features
*   **Transcription**: Support for Apple STT, Whisper, and remote ASR.
*   **AI Processing**: Clean up text, summarize, format, or apply custom prompts.
*   **UI**: Minimalist HUD, floating capsule, and quick-ask panel.
*   **Platform**: Native macOS application (macOS 14+).

## Documentation Entry Points
*   **Project Constitution**: `PROJECT.md` (current goals, constraints, DoD, verification commands).
*   **Architecture Overview**: `spoke/docs/architecture/overview.md` (system layers and major modules).
*   **Code Navigation Index**: `spoke/docs/architecture/quick-reference.md` (feature -> file -> type mapping).
*   **Quality Gate Playbook**: `docs/quality-playbook.md` (build/test/concurrency/sanitizer workflow).
*   **Contribution Workflow**: `CONTRIBUTING.md` (setup, standards, PR checks).

## Logic Location Quick Map
| Capability | Entry File | Core Implementation |
|---|---|---|
| Voice input | `spoke/Services/RecordingController.swift` | `spoke/Core/Audio/AudioRecorderService.swift`, `spoke/Core/Transcription/TranscriptionManager.swift` |
| Quick Ask | `spoke/Services/QuickAskService.swift` | `spoke/Core/LLM/LLMPipeline.swift`, `spoke/Core/LLM/OpenAICompatibleProvider.swift` |
| Screenshot OCR | `spoke/Core/Screenshot/ScreenshotManager.swift` | `spoke/Core/Attachment/ScreenCaptureService.swift`, `spoke/Services/ImageEnhancementService.swift` |
| Live Caption | `spoke/Core/LiveCaption/LiveCaptionManager.swift` | `spoke/Core/LiveCaption/SystemAudioCaptureService.swift`, `spoke/Core/LiveCaption/LiveCaptionTranscriber.swift` |
| Hotkey routing | `spoke/Services/HotKeyService.swift` | `spoke/Services/HotKey/Handlers/VoiceHandler.swift`, `spoke/Services/HotKey/Handlers/QuickAskHandler.swift` |
