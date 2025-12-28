import Foundation
@testable import SpokenAnyWhere
import Testing

// MARK: - TranscriptionModelManager Tests

@Suite("TranscriptionModelManager 测试")
@MainActor
struct TranscriptionModelManagerTests {
    
    // MARK: - Singleton
    
    @Test("shared 单例应存在且始终一致")
    func sharedInstanceConsistent() {
        let manager1 = TranscriptionModelManager.shared
        let manager2 = TranscriptionModelManager.shared
        
        // 同一引用
        #expect(manager1 === manager2)
    }
    
    // MARK: - Model Selection
    
    @Test("allModels 应返回所有已定义模型")
    func allModelsReturnsAllDefinitions() {
        let manager = TranscriptionModelManager.shared
        let models = manager.allModels
        
        #expect(models.count >= 2, "至少应有 2 个模型定义")
        
        // 验证包含核心模型
        let ids = models.map { $0.id }
        #expect(ids.contains("apple-dictation"))
        #expect(ids.contains("apple-speech-transcriber"))
    }
    
    @Test("availableModels 应只返回可用模型")
    func availableModelsFiltered() {
        let manager = TranscriptionModelManager.shared
        let available = manager.availableModels
        
        // 所有返回的模型都应该是可用的
        for model in available {
            #expect(model.isAvailable, "\(model.id) 标记为可用但 isAvailable=false")
        }
    }
    
    @Test("selectModel 应更新 selectedModelId")
    func selectModelUpdatesSelection() {
        let manager = TranscriptionModelManager.shared
        let originalId = manager.settings.selectedModelId
        
        // 选择 apple-dictation
        manager.selectModel("apple-dictation")
        #expect(manager.settings.selectedModelId == "apple-dictation")
        
        // 恢复原始选择
        manager.selectModel(originalId)
    }
    
    @Test("selectModel 应忽略未知模型 ID")
    func selectModelIgnoresUnknown() {
        let manager = TranscriptionModelManager.shared
        let originalId = manager.settings.selectedModelId
        
        manager.selectModel("nonexistent-model-xyz")
        
        // 应保持不变
        #expect(manager.settings.selectedModelId == originalId)
    }
    
    @Test("selectedModel 应返回当前选中模型定义")
    func selectedModelReturnsDefinition() {
        let manager = TranscriptionModelManager.shared
        
        manager.selectModel("apple-dictation")
        
        let selected = manager.selectedModel
        #expect(selected != nil)
        #expect(selected?.id == "apple-dictation")
        #expect(selected?.type == .dictation)
    }
    
    // MARK: - Settings
    
    @Test("setLocale 应更新当前模型的语言设置")
    func setLocaleUpdatesSettings() {
        let manager = TranscriptionModelManager.shared
        manager.selectModel("apple-dictation")
        
        let originalLocale = manager.currentModelSettings.locale
        
        manager.setLocale("en-US")
        #expect(manager.currentModelSettings.locale == "en-US")
        
        // 恢复
        manager.setLocale(originalLocale)
    }
    
    @Test("setPrecompiledLMEnabled 应更新预编译 LM 开关")
    func setPrecompiledLMUpdatesSettings() {
        let manager = TranscriptionModelManager.shared
        manager.selectModel("apple-dictation")
        
        let original = manager.currentModelSettings.enablePrecompiledLM
        
        manager.setPrecompiledLMEnabled(!original)
        #expect(manager.currentModelSettings.enablePrecompiledLM == !original)
        
        // 恢复
        manager.setPrecompiledLMEnabled(original)
    }
    
    @Test("updateSettings 不同模型设置应独立")
    func perModelSettingsIndependent() {
        let manager = TranscriptionModelManager.shared
        
        // 设置 dictation 的 locale
        manager.updateSettings(for: "apple-dictation") { s in
            s.locale = "zh-Hans"
        }
        
        // 设置 speech-transcriber 的 locale
        manager.updateSettings(for: "apple-speech-transcriber") { s in
            s.locale = "en-US"
        }
        
        // 验证独立
        let dictSettings = manager.settings.settings(for: "apple-dictation")
        let stSettings = manager.settings.settings(for: "apple-speech-transcriber")
        
        #expect(dictSettings.locale == "zh-Hans")
        #expect(stSettings.locale == "en-US")
    }
    
    // MARK: - Role Management
    
    @Test("setModelRole 应正确设置转录角色")
    func setModelRoleTranscription() {
        let manager = TranscriptionModelManager.shared
        
        manager.setModelRole("apple-dictation", as: .transcription)
        
        let model = manager.model(for: .transcription)
        #expect(model?.id == "apple-dictation")
    }
    
    @Test("setModelRole 应正确设置实时字幕角色")
    func setModelRoleLiveCaption() {
        let manager = TranscriptionModelManager.shared
        
        // SpeechTranscriber 支持流式
        manager.setModelRole("apple-speech-transcriber", as: .liveCaption)
        
        let model = manager.model(for: .liveCaption)
        #expect(model?.id == "apple-speech-transcriber")
    }
    
    @Test("roles(for:) 应返回模型的所有角色")
    func rolesForModelReturnsAllRoles() {
        let manager = TranscriptionModelManager.shared
        
        // 设置同一模型为两种角色
        manager.setModelRole("apple-dictation", as: .transcription)
        manager.setModelRole("apple-dictation", as: .liveCaption)
        
        let roles = manager.roles(for: "apple-dictation")
        #expect(roles.contains(.transcription))
        #expect(roles.contains(.liveCaption))
    }
    
    @Test("canSetRole 应检查流式支持")
    func canSetRoleChecksStreaming() {
        let manager = TranscriptionModelManager.shared
        
        // Dictation 支持流式
        #expect(manager.canSetRole(.liveCaption, for: "apple-dictation") == true)
        
        // Whisper API 不支持流式（如果存在的话）
        if let whisper = TranscriptionModelDefinition.find(by: "openai-whisper") {
            if !whisper.supportsStreaming {
                #expect(manager.canSetRole(.liveCaption, for: "openai-whisper") == false)
            }
        }
    }
    
    // MARK: - Download State
    
    @Test("downloadState 内置模型应为 notNeeded")
    func downloadStateBuiltinNotNeeded() {
        let manager = TranscriptionModelManager.shared
        
        let state = manager.downloadState(for: "apple-dictation")
        #expect(state == .notNeeded)
    }
    
    @Test("isModelReady 内置模型应始终就绪")
    func isModelReadyBuiltinAlwaysReady() {
        let manager = TranscriptionModelManager.shared
        
        #expect(manager.isModelReady("apple-dictation") == true)
    }
    
    @Test("isModelReady 未知模型应返回 false")
    func isModelReadyUnknownReturnsFalse() {
        let manager = TranscriptionModelManager.shared
        
        #expect(manager.isModelReady("nonexistent") == false)
    }
    
    // MARK: - Provider Configuration
    
    @Test("getProviderConfiguration 应返回正确配置")
    func getProviderConfigurationCorrect() {
        let manager = TranscriptionModelManager.shared
        
        manager.selectModel("apple-dictation")
        manager.setLocale("zh-Hans")
        manager.setPrecompiledLMEnabled(true)
        
        let config = manager.getProviderConfiguration()
        
        #expect(config.modelType == .dictation)
        #expect(config.locale.identifier == "zh-Hans")
        #expect(config.enablePrecompiledLM == true)
        #expect(config.enableContextualStrings == true)
    }
    
    @Test("getProviderConfiguration 应根据模型能力调整")
    func getProviderConfigurationRespectsCapabilities() {
        let manager = TranscriptionModelManager.shared
        
        // SpeechTranscriber 不支持预编译 LM
        manager.selectModel("apple-speech-transcriber")
        manager.setPrecompiledLMEnabled(true) // 用户启用
        
        let config = manager.getProviderConfiguration()
        
        // 但实际配置应该是 false（因为模型不支持）
        let model = TranscriptionModelDefinition.appleSpeechTranscriber
        if !model.supportsPrecompiledLM {
            #expect(config.enablePrecompiledLM == false)
        }
    }
}

// MARK: - TranscriptionModelRole Tests

@Suite("TranscriptionModelRole 测试")
struct TranscriptionModelRoleTests {
    
    @Test("rawValue 应正确映射")
    func rawValuesCorrect() {
        #expect(TranscriptionModelRole.transcription.rawValue == "transcription")
        #expect(TranscriptionModelRole.liveCaption.rawValue == "liveCaption")
    }
    
    @Test("allCases 应包含所有角色")
    func allCasesComplete() {
        let all = TranscriptionModelRole.allCases
        #expect(all.count == 2)
        #expect(all.contains(.transcription))
        #expect(all.contains(.liveCaption))
    }
}

// MARK: - Notification Tests

@Suite("Transcription 通知测试")
struct TranscriptionNotificationTests {
    
    @Test("通知名称应正确定义")
    func notificationNamesExist() {
        let modelChanged = Notification.Name.transcriptionModelChanged
        let roleChanged = Notification.Name.transcriptionModelRoleChanged
        
        #expect(modelChanged.rawValue == "transcriptionModelChanged")
        #expect(roleChanged.rawValue == "transcriptionModelRoleChanged")
    }
}
