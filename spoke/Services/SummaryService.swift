import AppKit
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
            let (content, images) = try await prepareContent(for: card)
            
            // 更新状态为 generating
            state.cards[id: cardId]?.summaryStatus = .generating
            state.objectWillChange.send()
            
            // 调用 LLM 生成总结（传入原文长度和图片）
            let summary = try await callLLM(content: content, images: images, originalLength: card.content.count)
            
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
    
    /// 准备用于总结的内容和图片
    private func prepareContent(for card: MessageCard) async throws -> (text: String, images: [Data]) {
        var images: [Data] = []
        
        // 加载附件图片
        for attachment in card.attachments {
            if let nsImage = CardAttachmentStorage.shared.loadOriginal(for: attachment),
               let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                images.append(pngData)
            }
        }
        
        switch card.contentType {
        case .text:
            return (card.content, images)
            
        case .image:
            // 图片内容：文本可能为空，依赖多模态处理
            let text = card.content.isEmpty ? "请描述这张图片的内容" : card.content
            return (text, images)
            
        case .url:
            // 提取 URL 并抓取内容
            let text = try await fetchURLContent(from: card.content)
            return (text, images)
            
        case .mixed:
            // 混合内容：文本 + 图片
            return (card.content, images)
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
    private func callLLM(content: String, images: [Data], originalLength: Int) async throws -> String {
        let settings = LLMSettings.shared
        
        // 获取总结模型（优先 summaryProfile，其次 selectedProfile）
        guard let profile = settings.summaryProfile ?? settings.selectedProfile,
              let provider = settings.createProvider(for: profile) else {
            throw SummaryError.noProvider
        }
        
        // 动态生成 prompt（包含原文长度限制）
        let systemPrompt = LLMSettings.summaryPrompt(originalLength: originalLength)
        
        let prompt = LLMPrompt(
            systemPrompt: systemPrompt,
            userMessage: content,
            images: images,
            originalTextLength: originalLength
        )
        
        let response = try await provider.complete(prompt: prompt)
        
        var summary = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if summary.isEmpty {
            throw SummaryError.emptyResult
        }
        
        // 强制截断：如果 LLM 还是返回了超长内容
        if summary.count > originalLength && originalLength > 0 {
            summary = String(summary.prefix(originalLength))
            logger.warning("⚠️ Summary truncated to \(originalLength) chars")
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

    var failureReason: String? {
        switch self {
        case .noProvider:
            return "未配置或选择用于总结的 LLM Provider"
        case .fetchFailed:
            return "无法从目标 URL 获取网页内容"
        case .emptyResult:
            return "LLM 返回了空的总结结果"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noProvider:
            return "请在设置中配置总结专用的 LLM Profile"
        case .fetchFailed:
            return "请检查网络连接和 URL 是否有效，或稍后重试"
        case .emptyResult:
            return "请尝试重新总结，或检查输入内容是否有效"
        }
    }
}
