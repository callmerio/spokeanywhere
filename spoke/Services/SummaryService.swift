import Foundation
import OSLog

/// 总结服务
/// 负责生成卡片内容的智能摘要
@MainActor
final class SummaryService {
    
    // MARK: - Singleton
    
    static let shared = SummaryService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "SummaryService")
    
    // MARK: - Public API
    
    /// 为卡片生成总结
    /// - Parameters:
    ///   - cardId: 卡片 ID
    ///   - regenerate: 是否重新生成（忽略已有总结）
    func generateSummary(for cardId: UUID, regenerate: Bool = false) async {
        let state = MessagePanelState.shared
        
        guard let card = state.cards[id: cardId] else {
            logger.warning("⚠️ Card not found: \(cardId)")
            return
        }
        
        // 检查是否需要总结
        if !regenerate && card.hasSummary {
            logger.info("ℹ️ Card already has summary, skipping")
            return
        }
        
        // 检查是否正在生成
        if card.summaryStatus.isInProgress {
            logger.info("ℹ️ Summary generation in progress, skipping")
            return
        }
        
        // 更新状态为 pending
        state.cards[id: cardId]?.summaryStatus = .pending
        state.objectWillChange.send()
        
        do {
            // 根据内容类型选择处理策略
            let content = try await prepareContent(for: card)
            
            // 更新状态为 generating
            state.cards[id: cardId]?.summaryStatus = .generating
            state.objectWillChange.send()
            
            // 调用 LLM 生成总结
            let summary = try await callLLM(content: content)
            
            // 更新总结内容
            state.cards[id: cardId]?.summary = summary
            state.cards[id: cardId]?.summaryStatus = .completed
            state.objectWillChange.send()
            
            // 保存
            state.saveCards()
            
            logger.info("✅ Summary generated for card: \(cardId)")
            
        } catch {
            // 更新状态为失败
            state.cards[id: cardId]?.summaryStatus = .failed
            state.objectWillChange.send()
            
            logger.error("❌ Summary generation failed: \(error.localizedDescription)")
        }
    }
    
    /// 清除卡片的总结
    func clearSummary(for cardId: UUID) {
        let state = MessagePanelState.shared
        
        guard state.cards[id: cardId] != nil else { return }
        
        state.cards[id: cardId]?.summary = nil
        state.cards[id: cardId]?.summaryStatus = .none
        state.objectWillChange.send()
        state.saveCards()
        
        logger.info("🗑️ Summary cleared for card: \(cardId)")
    }
    
    // MARK: - Private Methods
    
    /// 准备用于总结的内容
    private func prepareContent(for card: MessageCard) async throws -> String {
        switch card.contentType {
        case .text:
            return card.content
            
        case .image:
            // TODO: 使用多模态模型处理图片
            // 暂时返回占位文本
            return "[图片内容]"
            
        case .url:
            // 提取 URL 并抓取内容
            return try await fetchURLContent(from: card.content)
            
        case .mixed:
            // 混合内容：文本 + 图片描述
            return card.content
        }
    }
    
    /// 抓取 URL 内容
    private func fetchURLContent(from text: String) async throws -> String {
        // 提取 URL
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return text
        }
        
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard let match = matches.first,
              let range = Range(match.range, in: text),
              let url = URL(string: String(text[range])) else {
            return text
        }
        
        // 使用 URLSession 抓取内容
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SummaryError.fetchFailed
        }
        
        // 解析 HTML 提取文本
        if let html = String(data: data, encoding: .utf8) {
            return extractTextFromHTML(html)
        }
        
        return text
    }
    
    /// 从 HTML 提取纯文本
    private func extractTextFromHTML(_ html: String) -> String {
        // 简单的 HTML 标签移除
        var text = html
        
        // 移除 script 和 style 标签及其内容
        text = text.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )
        
        // 移除所有 HTML 标签
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        
        // 解码 HTML 实体
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        
        // 清理多余空白
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // 限制长度（避免 token 过多）
        let maxLength = 4000
        if text.count > maxLength {
            text = String(text.prefix(maxLength)) + "..."
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 调用 LLM 生成总结
    private func callLLM(content: String) async throws -> String {
        let settings = LLMSettings.shared
        
        // 获取总结模型（优先 summaryProfile，其次 selectedProfile）
        guard let profile = settings.summaryProfile ?? settings.selectedProfile,
              let provider = settings.createProvider(for: profile) else {
            throw SummaryError.noProvider
        }
        
        let prompt = LLMPrompt(
            systemPrompt: LLMSettings.summaryPrompt,
            userMessage: content
        )
        
        let response = try await provider.complete(prompt: prompt)
        
        let summary = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if summary.isEmpty {
            throw SummaryError.emptyResult
        }
        
        return summary
    }
}

// MARK: - Summary Error

enum SummaryError: LocalizedError {
    case noProvider
    case fetchFailed
    case emptyResult
    
    var errorDescription: String? {
        switch self {
        case .noProvider:
            return "未配置总结模型"
        case .fetchFailed:
            return "网页内容抓取失败"
        case .emptyResult:
            return "总结结果为空"
        }
    }
}

