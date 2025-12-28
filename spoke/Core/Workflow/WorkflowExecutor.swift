import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "WorkflowExecutor")

/// Workflow 执行器
/// 负责变量替换、模型选择、LLM 调用、输出处理
@MainActor
final class WorkflowExecutor {
    
    // MARK: - Singleton
    
    static let shared = WorkflowExecutor()
    
    // MARK: - Dependencies
    
    private let configService = WorkflowConfigService.shared
    private let llmPipeline = LLMPipeline.shared
    private let llmSettings = LLMSettings.shared
    
    private init() {}
    
    // MARK: - Execute
    
    /// 执行 Workflow
    /// - Parameters:
    ///   - workflow: 要执行的 Workflow
    ///   - context: 执行上下文
    ///   - onUpdate: 流式更新回调
    /// - Returns: 执行结果
    func execute(
        _ workflow: WorkflowAction,
        context: WorkflowContext,
        onUpdate: ((String) -> Void)? = nil
    ) async -> Result<String, WorkflowError> {
        
        logger.info("🔄 [WorkflowExecutor] 开始执行 | keyword: \(workflow.keyword)")
        
        // 1. 选择 Profile
        guard let profile = selectProfile(for: workflow) else {
            let error = WorkflowError.profileNotConfigured(workflow.modelHint.displayName)
            logger.error("🔄 [WorkflowExecutor] Profile 未配置: \(error.localizedDescription)")
            return .failure(error)
        }
        
        // 2. 构建 Prompt
        let prompt = buildPrompt(workflow: workflow, context: context)
        logger.info("🔄 [WorkflowExecutor] Prompt 构建完成 | 长度: \(prompt.count) | 内容: \(String(prompt.prefix(300)), privacy: .public)")
        
        // 3. 调用 LLM
        let result = await llmPipeline.chat(prompt, profile: profile)
        
        // 4. 处理结果
        switch result {
        case .success(let response):
            logger.info("🔄 [WorkflowExecutor] LLM 调用成功 | 响应长度: \(response.text.count)")
            
            // 标记为最近使用
            configService.markAsRecent(workflow.id)
            
            // 处理输出
            await handleOutput(response.text, mode: workflow.outputMode, context: context)
            
            return .success(response.text)
            
        case .failure(let error):
            logger.error("🔄 [WorkflowExecutor] LLM 调用失败: \(error.localizedDescription)")
            return .failure(.llmError(error))
        }
    }
    
    // MARK: - Profile Selection
    
    /// 选择 Profile
    /// 复用现有 LLMSettings + ProviderProfile 体系
    private func selectProfile(for workflow: WorkflowAction) -> ProviderProfile? {
        // 1. 优先使用指定 Profile
        if let profileId = workflow.profileId {
            return llmSettings.profiles.first { $0.id == profileId }
        }
        
        // 2. 根据 modelHint 选择角色 Profile
        switch workflow.modelHint {
        case .fast:
            if let id = llmSettings.chatProfileId {
                return llmSettings.profiles.first { $0.id == id }
            }
        case .advanced:
            if let id = llmSettings.summaryProfileId {
                return llmSettings.profiles.first { $0.id == id }
            }
        case .imageGen, .code:
            // 需要用户显式指定 profileId
            return nil
        case .default:
            break
        }
        
        // 3. 回退到默认选中的 Profile
        if let id = llmSettings.selectedProfileId {
            return llmSettings.profiles.first { $0.id == id }
        }
        return llmSettings.profiles.first
    }
    
    // MARK: - Prompt Building
    
    /// 构建 Prompt
    /// 白名单精确替换，不使用泛 regex
    private func buildPrompt(workflow: WorkflowAction, context: WorkflowContext) -> String {
        var prompt = workflow.promptTemplate
        
        let replacements: [(String, String?)] = [
            (WorkflowPlaceholder.input, context.userInput),
            (WorkflowPlaceholder.context, context.screenContext),
            (WorkflowPlaceholder.selected, context.selectedText),
            (WorkflowPlaceholder.voice, context.voiceTranscription),
            (WorkflowPlaceholder.clipboard, context.clipboardContent),
            (WorkflowPlaceholder.date, Date().formatted()),
            (WorkflowPlaceholder.lang, Locale.current.identifier)
        ]
        
        for (placeholder, value) in replacements {
            prompt = prompt.replacingOccurrences(of: placeholder, with: value ?? "")
        }
        
        return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Output Handling
    
    /// 处理输出
    private func handleOutput(_ text: String, mode: WorkflowOutputMode, context: WorkflowContext) async {
        switch mode {
        case .panel:
            // 显示在 AnswerPanel（由调用方处理）
            break
            
        case .clipboard:
            copyToClipboard(text)
            
        case .replace:
            // Quick Ask 场景下回退到 clipboard
            if context.selectedText == nil {
                copyToClipboard(text)
            } else {
                // TODO: 实现替换选中文本（需要 Accessibility）
                copyToClipboard(text)
            }
            
        case .append:
            // 追加到输入（由调用方处理）
            break
        }
    }
    
    /// 复制到剪贴板
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.info("🔄 [WorkflowExecutor] 已复制到剪贴板 | 长度: \(text.count)")
    }
}

// MARK: - Error

enum WorkflowError: LocalizedError {
    case profileNotConfigured(String)
    case llmError(LLMError)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .profileNotConfigured(let hint):
            return "请先在设置中配置\(hint)专用 Profile"
        case .llmError(let error):
            return error.localizedDescription
        case .cancelled:
            return "已取消"
        }
    }
}
