import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "SelectionToolbarState")

// MARK: - 工具栏显示状态

/// 工具栏显示阶段
enum SelectionToolbarPhase: Equatable {
    /// 空闲 - 隐藏状态
    case idle
    /// 显示中 - 工具栏可见
    case showing
    /// 执行动作中
    case executing(SelectionToolbarActionType)
    /// 显示结果中 (查询/翻译/总结的结果面板)
    case showingResult
    /// 显示词典结果（工具栏原地变换）
    case showingDictionary
}

// MARK: - 工具栏配置

/// 工具栏配置
struct SelectionToolbarConfig {
    /// 启用的按钮列表 (按顺序显示)
    var enabledActions: [SelectionToolbarActionType] = [.speak, .lookup, .translate, .summarize]
    
    /// 自动隐藏延迟 (秒)
    var autoHideDelay: TimeInterval = 5.0
    
    /// 是否显示按钮文字
    var showButtonText: Bool = true
    
    /// 工具栏与选中文本的间距
    var toolbarOffset: CGFloat = 8.0
    
    /// 是否启用 OCR 上下文
    var enableOCRContext: Bool = true
    
    /// OCR 上下文最大长度
    var ocrContextMaxLength: Int = 2000
}

// MARK: - 状态管理

/// 选择工具栏状态管理
@MainActor
final class SelectionToolbarState: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SelectionToolbarState()
    
    // MARK: - Published Properties
    
    /// 当前阶段
    @Published var phase: SelectionToolbarPhase = .idle
    
    /// 当前选中上下文
    @Published var currentContext: SelectionContext?
    
    /// 当前执行的动作阶段
    @Published var actionPhase: SelectionActionPhase = .idle
    
    /// 当前正在执行的动作 ID
    @Published var executingActionId: String?
    
    /// 最近一次执行的结果
    @Published var lastResult: String?
    
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 词典查询结果
    @Published var dictionaryResult: DictionaryData?
    
    /// 词典查询错误
    @Published var dictionaryError: DictionaryAPIError?
    
    /// 当前查词的单词是否在生词本中
    @Published var isWordInVocabulary: Bool = false
    
    /// 当前操作的生词本单词（优先使用选中文本）
    @Published var targetVocabularyWord: String?
    
    // MARK: - Configuration
    
    /// 工具栏配置
    @Published var config = SelectionToolbarConfig()
    
    // MARK: - Computed Properties
    
    /// 工具栏是否可见
    var isVisible: Bool {
        phase != .idle
    }
    
    /// 是否正在执行动作
    var isExecuting: Bool {
        if case .executing = phase { return true }
        return false
    }
    
    /// 当前选中的文本
    var selectedText: String {
        currentContext?.selectedText ?? ""
    }
    
    /// 工具栏应该显示的位置
    var toolbarPosition: CGPoint {
        guard let context = currentContext else {
            return .zero
        }
        
        // 默认显示在选中文本下方中央
        let bounds = context.selectionBounds
        return CGPoint(
            x: bounds.midX,
            y: bounds.maxY + config.toolbarOffset
        )
    }
    
    // MARK: - Init
    
    private init() {
        loadConfig()
    }
    
    // MARK: - Public API
    
    /// 显示工具栏
    func show(with context: SelectionContext) {
        guard !context.isEmpty else {
            logger.debug("📋 [SelectionToolbar] 选中文本为空，忽略")
            return
        }
        
        currentContext = context
        phase = .showing
        errorMessage = nil
        
        logger.info("📋 [SelectionToolbar] 显示工具栏 | 文本长度: \(context.textLength) | 来源: \(context.sourceAppName ?? "unknown")")
        
        // 发送显示通知
        NotificationCenter.default.post(name: .selectionToolbarDidShow, object: nil)
    }
    
    /// 隐藏工具栏
    func hide() {
        guard phase != .idle else { return }
        
        phase = .idle
        currentContext = nil
        actionPhase = .idle
        lastResult = nil
        
        logger.debug("📋 [SelectionToolbar] 隐藏工具栏")
        
        // 发送隐藏通知
        NotificationCenter.default.post(name: .selectionToolbarDidHide, object: nil)
    }
    
    /// 执行动作 (旧版，兼容)
    func executeAction(_ action: SelectionToolbarActionType) {
        guard let context = currentContext else {
            logger.warning("📋 [SelectionToolbar] 无选中上下文，无法执行动作")
            return
        }
        
        phase = .executing(action)
        actionPhase = .preparing
        
        logger.info("📋 [SelectionToolbar] 执行动作: \(action.displayName)")
        
        NotificationCenter.default.post(
            name: .selectionToolbarActionRequested,
            object: nil,
            userInfo: [
                "action": action,
                "context": context
            ]
        )
    }
    
    /// 执行工具栏动作 (新版，支持自定义动作)
    func executeToolbarAction(_ action: ToolbarAction) {
        guard let context = currentContext else {
            logger.warning("📋 [SelectionToolbar] 无选中上下文，无法执行动作")
            return
        }
        
        executingActionId = action.id
        actionPhase = .preparing
        
        logger.info("📋 [SelectionToolbar] 执行工具栏动作: \(action.name)")
        
        NotificationCenter.default.post(
            name: .selectionToolbarActionRequested,
            object: nil,
            userInfo: [
                "toolbarAction": action,
                "context": context
            ]
        )
    }
    
    /// 更新动作执行状态
    func updateActionPhase(_ phase: SelectionActionPhase) {
        actionPhase = phase
        
        switch phase {
        case .completed:
            logger.debug("📋 [SelectionToolbar] 动作完成")
        case .failed(let message):
            errorMessage = message
            logger.error("📋 [SelectionToolbar] 动作失败: \(message)")
        default:
            break
        }
    }
    
    /// 显示结果面板
    func showResult(_ result: String) {
        lastResult = result
        phase = .showingResult
    }
    
    /// 显示词典结果（工具栏原地变换）
    func showDictionaryResult(_ data: DictionaryData, forText: String? = nil) {
        dictionaryResult = data
        dictionaryError = nil
        phase = .showingDictionary
        actionPhase = .completed
        executingActionId = nil
        
        // 确定要添加的词：优先使用明确传递的文本，否则尝试上下文，最后回退到字典词头
        let wordToAdd = forText?.trimmingCharacters(in: .whitespacesAndNewlines) 
            ?? currentContext?.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? data.word
            
        // 只有非空才使用选中词，否则用字典词
        let finalWord = wordToAdd.isEmpty ? data.word : wordToAdd
        self.targetVocabularyWord = finalWord
        
        // 自动添加到生词本
        VocabularyService.shared.add(finalWord)
        isWordInVocabulary = true
        
        logger.info("📋 [SelectionToolbar] 显示词典结果: \(data.word), 添加生词: \(finalWord)")
    }
    
    /// 显示词典错误
    func showDictionaryError(_ error: DictionaryAPIError, word: String) {
        dictionaryResult = nil
        dictionaryError = error
        phase = .showingDictionary
        actionPhase = .failed(message: error.localizedDescription)
        executingActionId = nil
        isWordInVocabulary = false
        logger.warning("📋 [SelectionToolbar] 词典查询失败: \(word) - \(error.localizedDescription)")
    }
    
    /// 切换生词本收藏状态
    func toggleVocabulary() {
        guard let word = targetVocabularyWord ?? dictionaryResult?.word else {
            logger.warning("📋 [SelectionToolbar] toggleVocabulary: 无有效单词")
            return
        }
        
        logger.info("📋 [SelectionToolbar] toggleVocabulary: word=\(word), isWordInVocabulary=\(self.isWordInVocabulary)")
        
        if isWordInVocabulary {
            // 从生词本移除
            if let item = VocabularyService.shared.items.first(where: { $0.word.lowercased() == word.lowercased() }) {
                VocabularyService.shared.remove(item.id)
                logger.info("📋 [SelectionToolbar] 从生词本移除: \(word)")
            } else {
                // Lemma fallback
                if let lemma = dictionaryResult?.word, 
                   let item = VocabularyService.shared.items.first(where: { $0.word.lowercased() == lemma.lowercased() }) {
                    VocabularyService.shared.remove(item.id)
                    logger.info("📋 [SelectionToolbar] 从生词本移除(Lemma): \(lemma)")
                } else {
                    logger.warning("📋 [SelectionToolbar] 生词本中找不到: \(word)")
                }
            }
            isWordInVocabulary = false
        } else {
            // 添加到生词本
            if VocabularyService.shared.add(word) != nil {
                logger.info("📋 [SelectionToolbar] 添加到生词本成功: \(word)")
            } else {
                logger.warning("📋 [SelectionToolbar] 添加到生词本失败: \(word)")
            }
            isWordInVocabulary = true
        }
    }
    
    /// 从结果返回工具栏
    func backToToolbar() {
        phase = .showing
        lastResult = nil
        dictionaryResult = nil
        dictionaryError = nil
        isWordInVocabulary = false
    }
    
    // MARK: - Configuration
    
    /// 加载配置
    private func loadConfig() {
        // TODO: 从 UserDefaults 加载配置
    }
    
    /// 保存配置
    func saveConfig() {
        // TODO: 保存配置到 UserDefaults
    }
    
    /// 设置启用的按钮
    func setEnabledActions(_ actions: [SelectionToolbarActionType]) {
        config.enabledActions = actions
        saveConfig()
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// 工具栏显示
    static let selectionToolbarDidShow = Notification.Name("selectionToolbarDidShow")
    /// 工具栏隐藏
    static let selectionToolbarDidHide = Notification.Name("selectionToolbarDidHide")
    /// 请求执行动作
    static let selectionToolbarActionRequested = Notification.Name("selectionToolbarActionRequested")
    /// 动作执行完成
    static let selectionToolbarActionCompleted = Notification.Name("selectionToolbarActionCompleted")
}
