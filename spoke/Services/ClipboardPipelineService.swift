import AppKit
import OSLog

/// 剪贴板 Pipeline 服务
/// 从剪贴板读取内容，处理后添加到 MessagePanel
@MainActor
final class ClipboardPipelineService {
    
    // MARK: - Singleton
    
    static let shared = ClipboardPipelineService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ClipboardPipeline")
    
    // MARK: - Constants
    
    /// 剪贴板内容最大长度
    private let maxContentLength = 10000
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 触发剪贴板 Pipeline
    /// 读取剪贴板内容，获取当前聚焦应用作为来源，添加到 MessagePanel
    func trigger() {
        logger.info("📋 [ClipboardPipeline] 触发")
        
        // 读取剪贴板文本内容
        guard let content = readClipboardText() else {
            logger.warning("📋 [ClipboardPipeline] 剪贴板为空或不包含文本")
            return
        }
        
        // 检查内容长度
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            logger.warning("📋 [ClipboardPipeline] 剪贴板内容为空")
            return
        }
        
        // 截断过长内容
        let finalContent: String
        if trimmedContent.count > maxContentLength {
            finalContent = String(trimmedContent.prefix(maxContentLength)) + "..."
            logger.info("📋 [ClipboardPipeline] 内容过长，已截断至 \(self.maxContentLength) 字符")
        } else {
            finalContent = trimmedContent
        }
        
        // 获取当前聚焦应用作为来源
        let sourceApp = SourceAppInfo.fromFrontmost()
        
        logger.info("📋 [ClipboardPipeline] 添加内容: \(finalContent.prefix(50))... | 来源: \(sourceApp?.name ?? "unknown")")
        
        // 添加到 MessagePanel
        MessagePanelManager.shared.addClipboardContent(
            content: finalContent,
            sourceApp: sourceApp
        )
        
        // 显示 MessagePanel（如果未显示）
        if !MessagePanelManager.shared.isVisible {
            MessagePanelManager.shared.show()
        }
    }
    
    // MARK: - Private
    
    /// 从剪贴板读取文本内容
    private func readClipboardText() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
}
