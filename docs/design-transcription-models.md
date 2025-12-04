# Transcription Model Selector Design

## Goal

1. Support multiple transcription models (DictationTranscriber, SpeechTranscriber, Whisper, etc.)
2. Modular dictionary injection (contextualStrings + Precompiled LM as composable steps)
3. Apple HIG compliant UI design

## Model Comparison (from code)

| Model ID                   | API Class              | Source   | Size   | contextualStrings | Precompiled LM | Multilingual |
| -------------------------- | ---------------------- | -------- | ------ | ----------------- | -------------- | ------------ |
| `apple-dictation`          | `DictationTranscriber` | Built-in | -      | ✅                | ✅             | ❌           |
| `apple-speech-transcriber` | `SpeechTranscriber`    | Download | ~2GB   | ✅                | ❌             | ✅           |
| `openai-whisper`           | API                    | Cloud    | -      | ❌                | ❌             | ✅           |
| `whisper-local`            | whisper.cpp            | Download | ~500MB | ❌                | ❌             | ✅           |

## UI Design

### Model Card Layout

```
┌────────────────────────────────────────────────────────────────┐
│  ○  Apple Dictation                                        ✓  │
│      Built-in, offline, privacy-first                         │
│                                                                │
│  Language: [zh-Hans ▼]    ☑ Precompiled LM                    │
│                                                                │
│  ◉ Active   Accuracy ●●●○○   Speed ●●●●○   🏠 Local           │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  ○  Apple SpeechTranscriber                          [Download]│
│      Next-gen on-device recognition, requires macOS 26+        │
│                                                                │
│  Language: [zh-Hans ▼]    (no extra options)                   │
│                                                                │
│  Accuracy ●●●●●   Speed ●●●●●   📦 2.1 GB   🏠 Local           │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  ○  OpenAI Whisper                              [Coming Soon]  │
│      Cloud processing, high accuracy, requires API Key         │
│                                                                │
│  🌐 Multilingual                                               │
│                                                                │
│  Accuracy ●●●●●   Speed ●●●○○   ☁️ Cloud                       │
└────────────────────────────────────────────────────────────────┘
```

### Key UI Points

1. **Language selector**: Left side, only for single-language models
2. **Model-specific options**: Right side of language selector
   - `apple-dictation`: ☑ Precompiled LM checkbox
   - `apple-speech-transcriber`: (none)
   - Whisper models: (none, multilingual)
3. **Stats row**: Accuracy, Speed, Size, Source (Local/Cloud)
4. **Download button**: For models that require download

## Data Structures

```swift
// MARK: - Model Type
enum TranscriptionModelType: String, Codable, CaseIterable {
    case dictation           // DictationTranscriber (built-in)
    case speechTranscriber   // SpeechTranscriber (download ~2GB)
    case whisperAPI          // OpenAI Whisper API (cloud)
    case whisperLocal        // whisper.cpp (download ~500MB)
}

// MARK: - Model Source
enum TranscriptionModelSource: String, Codable {
    case builtin    // No download needed
    case download   // Requires model download
    case api        // Cloud API
}

// MARK: - Model Definition (Static)
struct TranscriptionModelDefinition: Identifiable, Codable {
    let id: String
    let type: TranscriptionModelType
    let source: TranscriptionModelSource
    let downloadSizeMB: Int?
    let defaultLocale: String
    let supportedLocales: [String]
    let accuracy: Int  // 1-5
    let speed: Int     // 1-5

    // Capabilities
    let supportsContextualStrings: Bool
    let supportsPrecompiledLM: Bool
    let supportsMultilingual: Bool

    // Availability
    let isAvailable: Bool       // true = can use now
    let isComingSoon: Bool      // true = show "Coming Soon"
    let minimumOS: String?      // e.g., "macOS 26"
}

// MARK: - User Settings (Mutable)
struct TranscriptionModelUserSettings: Codable {
    var selectedModelId: String
    var perModelSettings: [String: PerModelSettings]
}

struct PerModelSettings: Codable {
    var locale: String
    var enablePrecompiledLM: Bool  // Only used if model supports it
    var isDownloaded: Bool
}
```

## Default Model Definitions

```swift
extension TranscriptionModelDefinition {
    static let allModels: [TranscriptionModelDefinition] = [
        // 1. Apple Dictation (Default)
        TranscriptionModelDefinition(
            id: "apple-dictation",
            type: .dictation,
            source: .builtin,
            downloadSizeMB: nil,
            defaultLocale: "zh-Hans",
            supportedLocales: ["zh-Hans", "zh-Hant", "en-US", "en-GB", "ja-JP", "ko-KR"],
            accuracy: 3,
            speed: 4,
            supportsContextualStrings: true,
            supportsPrecompiledLM: true,
            supportsMultilingual: false,
            isAvailable: true,
            isComingSoon: false,
            minimumOS: nil
        ),

        // 2. Apple SpeechTranscriber (Stronger, needs download)
        TranscriptionModelDefinition(
            id: "apple-speech-transcriber",
            type: .speechTranscriber,
            source: .download,
            downloadSizeMB: 2100,
            defaultLocale: "zh-Hans",
            supportedLocales: ["zh-Hans", "en-US", "ja-JP", "de-DE", "fr-FR", "es-ES"],
            accuracy: 5,
            speed: 5,
            supportsContextualStrings: true,
            supportsPrecompiledLM: false,
            supportsMultilingual: true,
            isAvailable: true,
            isComingSoon: false,
            minimumOS: "macOS 26"
        ),

        // 3. OpenAI Whisper API (Coming Soon)
        TranscriptionModelDefinition(
            id: "openai-whisper",
            type: .whisperAPI,
            source: .api,
            downloadSizeMB: nil,
            defaultLocale: "multilingual",
            supportedLocales: ["multilingual"],
            accuracy: 5,
            speed: 3,
            supportsContextualStrings: false,
            supportsPrecompiledLM: false,
            supportsMultilingual: true,
            isAvailable: false,
            isComingSoon: true,
            minimumOS: nil
        ),

        // 4. Whisper.cpp Local (Coming Soon)
        TranscriptionModelDefinition(
            id: "whisper-local",
            type: .whisperLocal,
            source: .download,
            downloadSizeMB: 547,
            defaultLocale: "multilingual",
            supportedLocales: ["multilingual"],
            accuracy: 4,
            speed: 3,
            supportsContextualStrings: false,
            supportsPrecompiledLM: false,
            supportsMultilingual: true,
            isAvailable: false,
            isComingSoon: true,
            minimumOS: nil
        )
    ]

    static let defaultModelId = "apple-dictation"
}
```

## Dictionary Injection Pipeline

```
User Dictionary Data
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│              DictionaryInjectionPipeline                     │
│                                                              │
│  Step 1: Collect Data                                        │
│     ├── getAllWords() → ["Claude", "Anthropic", ...]         │
│     └── getAllTrainingPhrases() → ["Claude is an AI", ...]   │
│                                                              │
│  Step 2: Build contextualStrings (if supported)              │
│     └── words + trainingPhrases → merged array               │
│                                                              │
│  Step 3: Precompiled LM (if enabled AND supported)           │
│     └── Only DictationTranscriber supports this              │
│                                                              │
│  Step 4: Inject to Transcriber                               │
│     ├── SpeechTranscriber: setContext(contextualStrings)     │
│     └── DictationTranscriber: setContext() + LM contentHints │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Data Structures & Settings

1. [ ] Create `TranscriptionModelDefinition` struct
2. [ ] Create `TranscriptionModelUserSettings` struct
3. [ ] Create `TranscriptionModelManager` service
4. [ ] Persist to UserDefaults

### Phase 2: Provider Abstraction

5. [ ] Abstract `DictionaryInjectionPipeline` module
6. [ ] Refactor `SpeechAnalyzerProvider` to support both Transcribers
7. [ ] Add model switching logic in `TranscriptionManager`

### Phase 3: UI

8. [ ] Create `ModelCardView` component
9. [ ] Refactor Settings > Transcription Model page
10. [ ] Add download status & progress UI
11. [ ] Add per-model configuration UI (language, precompiled LM toggle)

### Phase 4: Testing & Polish

12. [ ] Test model switching
13. [ ] Test dictionary injection for both models
14. [ ] Performance optimization
