import Foundation
import SwiftData

@Model
class HistoryItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var rawText: String
    var processedText: String?
    var audioPath: String? // Relative path in sandbox/container
    var appBundleId: String?
    var tags: [String] // Requires ValueTransformer if complex, but basic arrays of string are supported in recent SwiftData
    
    @Relationship(deleteRule: .nullify)
    var providerConfig: AIProviderConfig?
    
    init(id: UUID = UUID(), createdAt: Date = Date(), rawText: String, processedText: String? = nil, audioPath: String? = nil, appBundleId: String? = nil, tags: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.rawText = rawText
        self.processedText = processedText
        self.audioPath = audioPath
        self.appBundleId = appBundleId
        self.tags = tags
    }
}

@Model
class AppRule {
    @Attribute(.unique) var bundleId: String
    var appName: String
    var extraPrompt: String
    var isEnabled: Bool
    
    init(bundleId: String, appName: String, extraPrompt: String, isEnabled: Bool = true) {
        self.bundleId = bundleId
        self.appName = appName
        self.extraPrompt = extraPrompt
        self.isEnabled = isEnabled
    }
}

@Model
class AIProviderConfig {
    @Attribute(.unique) var providerId: String // e.g. "gemini-user-1"
    var displayName: String
    var apiKeyReference: String // Keychain Key Identifier
    var baseURL: String?
    var defaultModelId: String
    var isDefault: Bool
    
    init(providerId: String, displayName: String, apiKeyReference: String, baseURL: String? = nil, defaultModelId: String, isDefault: Bool = false) {
        self.providerId = providerId
        self.displayName = displayName
        self.apiKeyReference = apiKeyReference
        self.baseURL = baseURL
        self.defaultModelId = defaultModelId
        self.isDefault = isDefault
    }
}
