import AppKit
import os

/// 剪贴板历史服务
/// 底层静默保存用户剪贴板历史，作为 LLM 上下文
@MainActor
final class ClipboardHistoryService {
    
    // MARK: - Singleton
    
    static let shared = ClipboardHistoryService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ClipboardHistory")
    
    // MARK: - Constants
    
    /// 默认保存条数
    private static let defaultLimit = 30
    /// 单条最大长度
    private static let maxItemLength = 500
    /// 检查间隔（秒）
    private static let checkInterval: TimeInterval = 1.0
    /// 存储 Key
    private static let storageKey = "ClipboardHistory"
    
    // MARK: - Properties
    
    /// 历史记录
    private(set) var history: [ClipboardItem] = []
    
    /// 上次剪贴板变化计数
    private var lastChangeCount: Int = 0
    
    /// 定时器
    private var timer: Timer?
    
    /// 是否正在运行
    private(set) var isRunning = false
    
    // MARK: - Init
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Public API
    
    /// 启动监听
    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboard()
            }
        }
        
        logger.info("📋 ClipboardHistoryService started")
    }
    
    /// 停止监听
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        logger.info("📋 ClipboardHistoryService stopped")
    }
    
    /// 获取历史文本（用于 LLM 上下文）
    func getHistoryForContext(limit: Int = 20) -> [String] {
        return history.prefix(limit).map { $0.content }
    }
    
    /// 格式化为 Prompt 上下文
    func formatForPrompt(limit: Int = 20) -> String {
        let items = getHistoryForContext(limit: limit)
        guard !items.isEmpty else { return "" }
        
        var result = "<剪贴板历史>\n"
        for (index, item) in items.enumerated() {
            // 保留更多内容，最多 500 字符
            let truncated = item.count > 500 ? String(item.prefix(500)) + "..." : item
            result += "\(index + 1). \(truncated)\n"
        }
        result += "</剪贴板历史>"
        return result
    }
    
    /// 调试：打印完整历史
    func debugPrintHistory() {
        print("📋 === CLIPBOARD HISTORY DEBUG ===")
        print("📋 Total items: \(history.count)")
        for (index, item) in history.prefix(10).enumerated() {
            print("📋 [\(index + 1)] \(item.content)")
        }
        print("📋 === END HISTORY ===")
    }
    
    /// 清空历史
    func clearHistory() {
        history.removeAll()
        saveHistory()
        logger.info("📋 History cleared")
    }
    
    // MARK: - Private
    
    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // 获取剪贴板文本
        guard let content = NSPasteboard.general.string(forType: .string),
              !content.isEmpty else { return }
        
        // 过滤敏感内容
        if isSensitive(content) {
            logger.debug("📋 Skipped sensitive content")
            return
        }
        
        // 截断过长内容
        let truncated = content.count > Self.maxItemLength
            ? String(content.prefix(Self.maxItemLength))
            : content
        
        // 去重：如果最近一条相同则跳过
        if let lastItem = history.first, lastItem.content == truncated {
            return
        }
        
        // 添加到历史
        let item = ClipboardItem(content: truncated, timestamp: Date())
        history.insert(item, at: 0)
        
        // 限制条数
        let limit = AppSettings.shared.clipboardHistoryLimit
        if history.count > limit {
            history = Array(history.prefix(limit))
        }
        
        // 持久化
        saveHistory()
        
        logger.info("📋 Added to history: \(truncated.prefix(80))...")
        print("📋 Clipboard history count: \(history.count), latest: \(truncated.prefix(80))...")
    }
    
    /// 检测敏感内容
    private func isSensitive(_ content: String) -> Bool {
        let lowercased = content.lowercased()
        
        // 密码模式
        if lowercased.contains("password") || lowercased.contains("passwd") {
            return true
        }
        
        // API Key 模式
        if lowercased.contains("api_key") || lowercased.contains("apikey") ||
           lowercased.contains("secret") || lowercased.contains("token") {
            return true
        }
        
        // 看起来像密钥的长字符串（全是字母数字，无空格，超过 30 字符）
        if content.count > 30 &&
           !content.contains(" ") &&
           content.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            return true
        }
        
        return false
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            logger.error("❌ Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            history = try JSONDecoder().decode([ClipboardItem].self, from: data)
            logger.info("📋 Loaded \(self.history.count) history items")
        } catch {
            logger.error("❌ Failed to load history: \(error)")
        }
    }
}

// MARK: - ClipboardItem

struct ClipboardItem: Codable, Identifiable {
    let id: UUID
    let content: String
    let timestamp: Date
    
    init(content: String, timestamp: Date) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
    }
}
