import AppKit
import Combine

/// 上下文感知服务
/// 监听当前活动 App，提供 Prompt 拼接
@MainActor
final class ContextService {
    
    // MARK: - Singleton
    
    static let shared = ContextService()
    
    // MARK: - Properties
    
    /// 当前活动 App
    private(set) var currentApp: TargetAppInfo?
    
    /// App 切换通知
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    private init() {
        setupObservers()
        updateCurrentApp()
    }
    
    // MARK: - Public API
    
    /// 获取当前活动 App 信息
    func getCurrentTargetApp() -> TargetAppInfo? {
        return currentApp
    }
    
    /// 根据当前 App 拼接 Prompt
    /// - Parameter globalPrompt: 全局 Prompt
    /// - Parameter appRules: App 规则列表（从 SwiftData 查询）
    /// - Returns: 拼接后的完整 Prompt
    func assemblePrompt(globalPrompt: String, appRules: [AppRule]) -> String {
        guard let currentApp = currentApp else {
            return globalPrompt
        }
        
        // 查找匹配的 App 规则
        let matchedRule = appRules.first { rule in
            rule.bundleId == currentApp.bundleIdentifier && rule.isEnabled
        }
        
        if let rule = matchedRule {
            return """
            \(globalPrompt)
            
            [当前应用: \(currentApp.name)]
            \(rule.extraPrompt)
            """
        }
        
        return globalPrompt
    }
    
    // MARK: - Private
    
    private func setupObservers() {
        // 监听 App 激活通知
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAppActivation(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleAppActivation(_ notification: Notification) {
        updateCurrentApp()
    }
    
    private func updateCurrentApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            currentApp = nil
            return
        }
        
        // 排除自身
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        
        currentApp = TargetAppInfo.from(frontApp)
    }
}
