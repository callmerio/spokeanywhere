import AppKit
import OSLog

@MainActor
struct ClipboardPipelineServiceDependencies {
    let messagePanelManager: () -> MessagePanelManager
    let currentSourceApp: () -> SourceAppInfo?
    let pasteboardText: () -> String?
}

/// 剪贴板 Pipeline 服务
/// 从剪贴板读取内容，处理后添加到 MessagePanel
@MainActor
final class ClipboardPipelineService {
    
    // MARK: - Singleton
    
    static let shared = ClipboardPipelineService(dependencies: .live)
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ClipboardPipeline")
    private let dependencies: ClipboardPipelineServiceDependencies
    
    // MARK: - Constants
    
    /// 剪贴板内容最大长度
    private let maxContentLength = 10000
    
    // MARK: - Init
    
    private init(
        dependencies: ClipboardPipelineServiceDependencies
    ) {
        self.dependencies = dependencies
    }
    
    // MARK: - Public API
    
    /// 触发剪贴板 Pipeline
    /// 读取剪贴板内容，获取当前聚焦应用作为来源，添加到 MessagePanel
    func trigger() {
        logger.info("📋 [ClipboardPipeline] 触发")
        
        guard let payload = makeClipboardPipelinePayload(
            maxContentLength: maxContentLength,
            pasteboardText: dependencies.pasteboardText,
            currentSourceApp: dependencies.currentSourceApp
        ) else {
            logger.warning("📋 [ClipboardPipeline] 剪贴板为空或不包含文本")
            return
        }

        if payload.wasTruncated {
            logger.info("📋 [ClipboardPipeline] 内容过长，已截断至 \(self.maxContentLength) 字符")
        }

        logger.info("📋 [ClipboardPipeline] 添加内容: \(payload.content.prefix(50))... | 来源: \(payload.sourceApp?.name ?? "unknown")")

        let messagePanelManager = dependencies.messagePanelManager()
        
        // 添加到 MessagePanel
        messagePanelManager.addClipboardContent(
            content: payload.content,
            sourceApp: payload.sourceApp
        )
        
        // 显示 MessagePanel（如果未显示）
        if !messagePanelManager.isVisible {
            messagePanelManager.show()
        }
    }
}
