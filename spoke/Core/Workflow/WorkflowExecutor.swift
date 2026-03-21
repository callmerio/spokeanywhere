import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "WorkflowExecutor")

@MainActor
struct WorkflowExecutorDependencies {
    let availableProfiles: () -> [ProviderProfile]
    let chatProfileId: () -> UUID?
    let summaryProfileId: () -> UUID?
    let selectedProfileId: () -> UUID?
    let executeChat: (String, ProviderProfile) async -> Result<LLMResponse, LLMError>
    let markAsRecent: (String) -> Void
    let currentDateString: () -> String
    let currentLocaleIdentifier: () -> String
    let copyText: (String) -> Void
}

@MainActor
extension WorkflowExecutorDependencies {
    static let live = makeLive(
        settings: .shared,
        pipeline: .shared,
        workflowConfigService: .shared,
        pasteboard: .general,
        dateProvider: Date.init,
        localeProvider: { .current }
    )

    static func makeLive(
        settings: LLMSettings,
        pipeline: LLMPipeline,
        workflowConfigService: WorkflowConfigService,
        pasteboard: NSPasteboard,
        dateProvider: @escaping () -> Date,
        localeProvider: @escaping () -> Locale
    ) -> WorkflowExecutorDependencies {
        WorkflowExecutorDependencies(
            availableProfiles: { settings.profiles },
            chatProfileId: { settings.chatProfileId },
            summaryProfileId: { settings.summaryProfileId },
            selectedProfileId: { settings.selectedProfileId },
            executeChat: { prompt, profile in
                await pipeline.chat(prompt, profile: profile)
            },
            markAsRecent: { workflowId in
                workflowConfigService.markAsRecent(workflowId)
            },
            currentDateString: { dateProvider().formatted() },
            currentLocaleIdentifier: { localeProvider().identifier },
            copyText: { text in
                copyTextToPasteboard(text, pasteboard: pasteboard)
            }
        )
    }

    func profile(matching id: UUID) -> ProviderProfile? {
        availableProfiles().first { $0.id == id }
    }

    private static func copyTextToPasteboard(_ text: String, pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

/// Workflow 执行器
/// 负责变量替换、模型选择、LLM 调用、输出处理
@MainActor
final class WorkflowExecutor {
    private enum OutputAction {
        case handledByCaller
        case copyToClipboard
    }
    
    // MARK: - Singleton
    
    static let shared = WorkflowExecutor(dependencies: .live)
    
    // MARK: - Dependencies
    
    private let dependencies: WorkflowExecutorDependencies
    
    private init(
        dependencies: WorkflowExecutorDependencies
    ) {
        self.dependencies = dependencies
    }
    
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
        let result = await dependencies.executeChat(prompt, profile)
        
        // 4. 处理结果
        switch result {
        case .success(let response):
            logger.info("🔄 [WorkflowExecutor] LLM 调用成功 | 响应长度: \(response.text.count)")

            await handleSuccessfulExecution(
                response.text,
                workflow: workflow,
                context: context
            )

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
            return dependencies.profile(matching: profileId)
        }


        if let preferredProfileId = preferredProfileID(for: workflow.modelHint) {
            return dependencies.profile(matching: preferredProfileId)
        }

        if requiresExplicitProfile(for: workflow.modelHint) {
            return nil
        }

        // 3. 回退到默认选中的 Profile
        if let selectedProfileId = dependencies.selectedProfileId() {
            return dependencies.profile(matching: selectedProfileId)
        }

        return dependencies.availableProfiles().first
    }
    
    // MARK: - Prompt Building
    
    /// 构建 Prompt
    /// 白名单精确替换，不使用泛 regex
    private func buildPrompt(workflow: WorkflowAction, context: WorkflowContext) -> String {
        return PromptRenderer.replacingPlaceholders(
            in: workflow.promptTemplate,
            replacements: promptReplacements(for: context)
        )
    }
    
    // MARK: - Output Handling
    
    /// 处理输出
    private func handleOutput(_ text: String, mode: WorkflowOutputMode, context: WorkflowContext) async {
        switch resolvedOutputAction(for: mode, context: context) {
        case .handledByCaller:
            break
        case .copyToClipboard:
            copyToClipboard(text)
        }
    }
    
    /// 复制到剪贴板
    private func copyToClipboard(_ text: String) {
        dependencies.copyText(text)
        logger.info("🔄 [WorkflowExecutor] 已复制到剪贴板 | 长度: \(text.count)")
    }

    private func handleSuccessfulExecution(
        _ text: String,
        workflow: WorkflowAction,
        context: WorkflowContext
    ) async {
        dependencies.markAsRecent(workflow.id)
        await handleOutput(text, mode: workflow.outputMode, context: context)
    }

    private func preferredProfileID(for modelHint: WorkflowModelHint) -> UUID? {
        switch modelHint {
        case .fast:
            return dependencies.chatProfileId()
        case .advanced:
            return dependencies.summaryProfileId()
        case .default, .imageGen, .code:
            return nil
        }
    }

    private func requiresExplicitProfile(for modelHint: WorkflowModelHint) -> Bool {
        switch modelHint {
        case .imageGen, .code:
            return true
        case .default, .fast, .advanced:
            return false
        }
    }

    private func promptReplacements(
        for context: WorkflowContext
    ) -> [(placeholder: String, value: String)] {
        [
            (WorkflowPlaceholder.input, context.userInput),
            (WorkflowPlaceholder.context, context.screenContext ?? ""),
            (WorkflowPlaceholder.selected, context.selectedText ?? ""),
            (WorkflowPlaceholder.voice, context.voiceTranscription ?? ""),
            (WorkflowPlaceholder.clipboard, context.clipboardContent ?? ""),
            (WorkflowPlaceholder.date, dependencies.currentDateString()),
            (WorkflowPlaceholder.lang, dependencies.currentLocaleIdentifier())
        ]
    }

    private func resolvedOutputAction(
        for mode: WorkflowOutputMode,
        context: WorkflowContext
    ) -> OutputAction {
        switch mode {
        case .panel, .append:
            return .handledByCaller
        case .clipboard:
            return .copyToClipboard
        case .replace:
            // 当前仍未实现直接替换选中文本，因此统一回退到剪贴板。
            return .copyToClipboard
        }
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

    var failureReason: String? {
        switch self {
        case .profileNotConfigured(let hint):
            return "\(hint)功能需要专用的 LLM Profile，但当前未配置"
        case .llmError(let error):
            return error.failureReason
        case .cancelled:
            return "用户主动取消了工作流执行"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .profileNotConfigured(let hint):
            return "请在设置 > LLM > Profiles 中为\(hint)创建专用配置"
        case .llmError(let error):
            return error.recoverySuggestion
        case .cancelled:
            return nil
        }
    }
}
