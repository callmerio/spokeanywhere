import Foundation
import OSLog

// MARK: - Caption Item

/// 字幕项（对应一句话）
struct CaptionItem: Identifiable, Equatable {
    let id: UUID
    var original: String
    var translation: String?
    
    init(id: UUID = UUID(), original: String, translation: String? = nil) {
        self.id = id
        self.original = original
        self.translation = translation
    }
}

// MARK: - Caption Line Buffer

/// 字幕缓冲区管理
/// 采用"原文先行，译文跟进"的策略
@MainActor
final class CaptionLineBuffer: ObservableObject {
    
    // MARK: - State
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "CaptionLineBuffer")
    
    /// 已确定的字幕项列表（保留最近的 N 条）
    @Published private(set) var items: [CaptionItem] = []
    
    /// 当前正在输入的流式文本（不稳定）
    @Published private(set) var pendingText: String = ""
    
    /// 流式文本的实时翻译
    @Published private(set) var pendingTranslation: String = ""
    
    /// 最大保留条数（用于 UI 显示）
    private let maxItems = 10
    
    /// 当前流式文本的版本号（用于解决翻译竞态）
    private var volatileVersion: Int = 0
    
    // MARK: - Public API
    
    /// 添加已确定的文本段落
    /// - Parameter text: 新增的 finalized 文本
    /// - Returns: 新创建的 Item ID，用于后续更新翻译；空文本返回 nil
    func addFinalized(text: String) -> UUID? {
        // 版本号递增，废弃旧的流式翻译
        volatileVersion += 1
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        
        let item = CaptionItem(original: cleaned)
        items.append(item)
        
        // 保持列表长度
        if items.count > maxItems {
            items.removeFirst(items.count - maxItems)
        }
        
        // 清除 pending，因为 volatile 应该紧接着 finalized
        // 但注意：有些引擎输出 finalized 后 volatile 可能会重置或包含新内容
        // 这里我们暂时不清空 pendingText，由 updateVolatile 覆盖
        
        return item.id
    }
    
    /// 更新正在输入的流式文本
    func updateVolatile(text: String) {
        pendingText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 更新流式文本的翻译
    /// - Parameters:
    ///   - translation: 翻译结果
    ///   - version: 发起翻译时的版本号
    func updatePendingTranslation(_ translation: String, version: Int) {
        // 只有当版本号匹配时才更新，防止旧任务覆盖新状态
        guard version == volatileVersion else {
            logger.debug("Discarding outdated translation (v\(version) vs v\(self.volatileVersion))")
            return
        }
        pendingTranslation = translation
    }
    
    /// 获取当前版本号
    var currentVolatileVersion: Int {
        volatileVersion
    }
    
    /// 清空流式状态（当 finalized 后调用）
    func clearPending() {
        pendingText = ""
        pendingTranslation = ""
        // 注意：这里不增加 version，因为 clearPending 通常和 addFinalized 一起调用，后者会处理 version
    }
    
    /// 更新指定 Item 的翻译
    func updateTranslation(id: UUID, translation: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].translation = translation
    }
    
    /// 清空所有内容
    func clear() {
        items.removeAll()
        pendingText = ""
        pendingTranslation = ""
        volatileVersion += 1
        logger.info("🧹 CaptionLineBuffer cleared")
    }
    
    // MARK: - Deprecated API
    
    @available(*, deprecated, message: "Use items + pendingText instead")
    var displayText: String {
        // 简单拼接最后一条原文 + pending
        if let last = items.last {
            return last.original + (pendingText.isEmpty ? "" : "\n" + pendingText)
        }
        return pendingText
    }
    
    @available(*, deprecated, message: "Use items.last?.translation instead")
    var translatedText: String {
        items.last?.translation ?? ""
    }
    
    @available(*, deprecated, message: "No longer used")
    var stableTextForTranslation: String? { nil }
    
    @available(*, deprecated, message: "Use updateTranslation(id:translation:) instead")
    func updateTranslation(_ translation: String) {}
    
    @available(*, deprecated, message: "Use addFinalized + updateVolatile instead")
    func update(finalizedText: String, volatileText: String) {
        logger.warning("⚠️ Deprecated update() called")
    }
    
    @available(*, deprecated, message: "Use updateTranslation(id:translation:) instead")
    func updateLastTranslation(_ translation: String) {
        if !items.isEmpty {
            items[items.count - 1].translation = translation
        }
    }
    
    @available(*, deprecated, message: "Use addFinalized + updateTranslation instead")
    func append(text: String, translation: String? = nil) {
        guard addFinalized(text: text) != nil else { return }
        if let t = translation { updateLastTranslation(t) }
    }
}
