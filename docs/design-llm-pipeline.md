# LLM Pipeline 设计文档

> 创建时间: 2025-11-27
> 状态: 已审查，待实现

## L1 - 架构层

### 需求概述

在现有语音转文字流程后，新增 LLM 处理管线。用户可配置多种 LLM Provider（本地 Ollama / 云端 API），自定义 Prompt 进行文本精炼。HUD 增加"思考中"流光动画，处理完成后文字模糊过渡+新文字覆盖。

### 模块划分

```
RecordingController
    ↓ (转写完成)
LLMPipeline
    ├── LLMProvider (协议)
    │   ├── OllamaProvider (本地)
    │   ├── OpenAIProvider (云端)
    │   ├── AnthropicProvider
    │   ├── GoogleGeminiProvider
    │   ├── GroqProvider
    │   └── OpenAICompatibleProvider (通用)
    ├── PromptBuilder (Prompt 组装)
    └── LLMSettings (用户配置)
    ↓ (精炼完成)
FloatingHUDManager
    ├── RecordingPhase.thinking (新增)
    └── GlowingBorderEffect (流光动画)
```

### 数据流向

```
[音频] → [TranscriptionProvider] → [原始文本]
                                        ↓
                               [写入剪贴板 #1]
                                        ↓
                            [LLMPipeline.refine()]
                                        ↓
                                  [精炼文本]
                                        ↓
                               [写入剪贴板 #2]
```

## L2 - 逻辑层

### LLM 处理流程

```pseudo
// RecordingController.processTranscription()
等待转写最终结果

if (文本为空) 
  显示失败
  return

// [决策点] 第一次写入剪贴板
写入剪贴板(原始文本)

// [决策点] 检查是否启用 AI
if (未配置 AI Provider)
  显示成功(原始文本)
  return

// 切换到 thinking 状态
HUD.startThinking()

// [优化] 异步调用 LLM
result = await LLMPipeline.refine(原始文本)

if (失败)
  显示失败
  return

// 第二次写入剪贴板
写入剪贴板(精炼文本)

// 显示成功（带模糊过渡动画）
HUD.completeWithTransition(原始文本, 精炼文本)
```

### LLM Provider 调用

```pseudo
// LLMPipeline.refine()
provider = LLMSettings.currentProvider

// [边界] Provider 未配置
if (provider == nil) return 原始文本

prompt = PromptBuilder.build(
  systemPrompt: LLMSettings.systemPrompt,
  userText: 原始文本,
  contextApp: ContextService.currentApp  // 可选
)

// [优化] 使用原生 URLSession + async/await
response = await provider.complete(prompt)

return response.text
```

### HUD 流光动画

```pseudo
// FloatingCapsuleView - thinking 状态
if (phase == .thinking)
  显示流光边框动画(GlowingBorderEffect)
  显示旋转指示器(在波形和品牌之间)
  
// GlowingBorderEffect 实现
// [决策点] 使用 AngularGradient + rotation animation
struct GlowingBorderView:
  @State rotationAngle = 0
  
  body:
    RoundedRectangle
      .stroke(
        AngularGradient(colors: [紫, 蓝, 青, 绿, 黄, 橙, 红, 紫])
        center: .center
        angle: rotationAngle
      )
      .blur(radius: 4)
      .onAppear:
        withAnimation(.linear.repeatForever):
          rotationAngle = 360

// 完成时的过渡
func completeWithTransition(oldText, newText):
  // [动画] 旧文字模糊淡出
  withAnimation(.easeOut):
    oldText.blur = 10
    oldText.opacity = 0
  
  // [动画] 新文字淡入
  withAnimation(.easeIn):
    newText.opacity = 1
  
  // [动画] 流光向上扩散消失
  glowEffect.animateUpward()
```

## L3 - 接口层

### LLMProvider 协议

```swift
protocol LLMProvider {
    var identifier: String { get }
    var displayName: String { get }
    var isConfigured: Bool { get }
    
    func complete(prompt: LLMPrompt) async throws -> LLMResponse
    func testConnection() async -> Bool
}

struct LLMPrompt {
    let systemPrompt: String
    let userMessage: String
    let contextAppName: String?
}

struct LLMResponse {
    let text: String
    let usage: TokenUsage?
}
```

### LLMSettings 配置

```swift
@Observable
class LLMSettings {
    // Provider 配置
    var selectedProviderType: LLMProviderType?
    var providers: [LLMProviderType: ProviderConfig]
    
    // Prompt 配置
    var systemPrompt: String  // 用户自定义
    var includeClipboard: Bool
    var includeActiveApp: Bool
    
    // Model 参数
    var temperature: Double
    var maxTokens: Int?
}

enum LLMProviderType: String, CaseIterable {
    case ollama
    case openai
    case anthropic
    case googleGemini
    case groq
    case openRouter
    case openAICompatible
}

struct ProviderConfig: Codable {
    var apiKey: String?      // 存储在 Keychain
    var baseURL: String?
    var modelName: String
}
```

### RecordingPhase 扩展

```swift
enum RecordingPhase: Equatable {
    case idle
    case recording
    case processing      // 转写处理中
    case thinking        // LLM 思考中
    case success
    case failure(String)
}
```

### KeychainService

```swift
// [决策点] 使用 Security framework 原生 API
struct KeychainService {
    static func save(key: String, value: String) throws
    static func load(key: String) -> String?
    static func delete(key: String) throws
}
```

## L4 - 验证层

### 测试用例

| 用例 | 预期 |
|-----|------|
| 未配置 Provider | 跳过 LLM，直接输出原始文本 |
| Provider 配置错误 | 显示错误，保留原始文本在剪贴板 |
| LLM 请求超时 | 3s 超时，降级到原始文本 |
| 空响应 | 保留原始文本 |
| 流光动画 | phase 切换时动画平滑 |

## L5 - 风险评估

| 风险 | 等级 | 缓解措施 |
|-----|------|---------|
| LLM 延迟高 | 中 | 超时机制 + 用户可配置超时时间 |
| API Key 泄露 | 高 | Keychain 存储 |
| 流光动画卡顿 | 低 | SwiftUI 原生动画 |
| Provider 兼容性 | 中 | OpenAI Compatible 作为通用后备 |

## 实现顺序

1. `LLMProvider` 协议 + `LLMPrompt/LLMResponse` 数据结构
2. `OpenAICompatibleProvider` (通用实现，覆盖大多数 Provider)
3. `LLMSettings` 配置 + `KeychainService`
4. `LLMPipeline` 处理管线
5. `RecordingController` 集成
6. `RecordingPhase.thinking` + HUD 流光动画
7. 设置界面 LLM 配置 Tab
