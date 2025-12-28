import Foundation
@testable import SpokenAnyWhere
import Testing

// MARK: - TranscriptionModelDefinition Tests

@Suite("TranscriptionModelDefinition 测试")
struct TranscriptionModelDefinitionTests {
    
    @Test("所有模型定义应有唯一 ID")
    func allModelsHaveUniqueIds() {
        let models = TranscriptionModelDefinition.allModels
        let ids = models.map { $0.id }
        let uniqueIds = Set(ids)
        
        #expect(ids.count == uniqueIds.count, "存在重复的模型 ID")
    }
    
    @Test("默认模型 ID 应存在于模型列表中")
    func defaultModelIdExists() {
        let defaultId = TranscriptionModelDefinition.defaultModelId
        let found = TranscriptionModelDefinition.find(by: defaultId)
        
        #expect(found != nil, "默认模型 ID 不存在: \(defaultId)")
    }
    
    @Test("find(by:) 应正确查找模型")
    func findByIdWorks() {
        let dictation = TranscriptionModelDefinition.find(by: "apple-dictation")
        #expect(dictation != nil)
        #expect(dictation?.type == .dictation)
        
        let notFound = TranscriptionModelDefinition.find(by: "nonexistent")
        #expect(notFound == nil)
    }
    
    @Test("sizeString 应正确格式化大小")
    func sizeStringFormat() {
        // 内置模型无大小
        let dictation = TranscriptionModelDefinition.appleDictation
        #expect(dictation.sizeString == nil)
        
        // MB 格式
        let whisperLocal = TranscriptionModelDefinition.whisperLocal
        #expect(whisperLocal.sizeString == "547 MB")
        
        // GB 格式
        let speechTranscriber = TranscriptionModelDefinition.appleSpeechTranscriber
        #expect(speechTranscriber.sizeString == "2.1 GB")
    }
    
    @Test("needsLanguageSelection 应正确判断")
    func needsLanguageSelectionLogic() {
        // 单语言模型需要选择
        let dictation = TranscriptionModelDefinition.appleDictation
        #expect(dictation.needsLanguageSelection == true)
        
        // 多语言模型不需要选择
        let whisperAPI = TranscriptionModelDefinition.openAIWhisper
        #expect(whisperAPI.needsLanguageSelection == false)
    }
    
    @Test("UI 属性应返回有效值")
    func uiPropertiesExist() {
        for model in TranscriptionModelDefinition.allModels {
            #expect(!model.displayName.isEmpty, "\(model.id) displayName 为空")
            #expect(!model.subtitle.isEmpty, "\(model.id) subtitle 为空")
            #expect(!model.iconName.isEmpty, "\(model.id) iconName 为空")
        }
    }
}

// MARK: - TranscriptionModelUserSettings Tests

@Suite("TranscriptionModelUserSettings 测试")
struct TranscriptionModelUserSettingsTests {
    
    @Test("默认设置应使用默认模型 ID")
    func defaultSettingsUseDefaultModelId() {
        let settings = TranscriptionModelUserSettings.default
        #expect(settings.selectedModelId == TranscriptionModelDefinition.defaultModelId)
    }
    
    @Test("settings(for:) 应为未知模型返回默认值")
    func settingsForUnknownModelReturnsDefault() {
        let settings = TranscriptionModelUserSettings.default
        let perSettings = settings.settings(for: "unknown-model")
        
        #expect(perSettings.locale == TranscriptionDefaults.locale)
        #expect(perSettings.enablePrecompiledLM == false)
        #expect(perSettings.isDownloaded == false)
    }
    
    @Test("settings(for:) 应为已知模型返回正确默认值")
    func settingsForKnownModelReturnsModelDefaults() {
        let settings = TranscriptionModelUserSettings.default
        let perSettings = settings.settings(for: "apple-dictation")
        
        #expect(perSettings.locale == "zh-Hans")
        #expect(perSettings.enablePrecompiledLM == true) // Dictation 支持预编译 LM
        #expect(perSettings.isDownloaded == true) // 内置模型无需下载
    }
}

// MARK: - ModelDownloadState Tests

@Suite("ModelDownloadState 测试")
struct ModelDownloadStateTests {
    
    @Test("isReady 应正确判断就绪状态")
    func isReadyLogic() {
        #expect(ModelDownloadState.notNeeded.isReady == true)
        #expect(ModelDownloadState.downloaded.isReady == true)
        #expect(ModelDownloadState.notDownloaded.isReady == false)
        #expect(ModelDownloadState.downloading(progress: 0.5).isReady == false)
        #expect(ModelDownloadState.failed(error: "test").isReady == false)
    }
}

// MARK: - TranscriptionRating Tests

@Suite("TranscriptionRating 测试")
struct TranscriptionRatingTests {
    
    @Test("评级 rawValue 应正确映射")
    func ratingRawValues() {
        #expect(TranscriptionRating.low.rawValue == 1)
        #expect(TranscriptionRating.belowAverage.rawValue == 2)
        #expect(TranscriptionRating.average.rawValue == 3)
        #expect(TranscriptionRating.good.rawValue == 4)
        #expect(TranscriptionRating.excellent.rawValue == 5)
    }
}

// MARK: - TranscriptionProviderConfig Tests

@Suite("TranscriptionProviderConfig 测试")
struct TranscriptionProviderConfigTests {
    
    @Test("配置应正确初始化")
    func configInitialization() {
        let config = TranscriptionProviderConfig(
            modelType: .dictation,
            locale: Locale(identifier: "zh-Hans"),
            enablePrecompiledLM: true,
            enableContextualStrings: true
        )
        
        #expect(config.modelType == .dictation)
        #expect(config.locale.identifier == "zh-Hans")
        #expect(config.enablePrecompiledLM == true)
        #expect(config.enableContextualStrings == true)
    }
}
