import AppKit
import Foundation
import os
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Attachment Manager

/// 处理状态
enum ProcessingState: Equatable {
    case idle
    case processing(current: Int, total: Int, fileName: String)
    
    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }
    
    var progress: Double {
        if case .processing(let current, let total, _) = self, total > 0 {
            return Double(current) / Double(total)
        }
        return 0
    }
    
    var statusText: String {
        switch self {
        case .idle: return ""
        case .processing(let current, let total, let fileName):
            return "正在处理 \(current)/\(total): \(fileName)"
        }
    }
}

/// 通用附件管理器
/// 处理拖拽、文件选择、截屏、图库等附件添加操作
/// 可复用于 QuickAsk、HUD 等多个入口
@MainActor
final class AttachmentManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AttachmentManager()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "AttachmentManager")
    
    // MARK: - Published State
    
    /// 处理状态（用于显示进度）
    @Published var processingState: ProcessingState = .idle
    
    // MARK: - Services
    
    private let textExtractor = TextExtractionService.shared
    private let screenCapture = ScreenCaptureService.shared
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Drop Handling
    
    /// 处理拖拽项目
    /// - Parameters:
    ///   - providers: 拖拽的数据提供者
    ///   - onAdd: 添加附件的回调
    func handleDrop(providers: [NSItemProvider], onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        for provider in providers {
            logger.info("📥 Processing drop provider: \(provider.registeredTypeIdentifiers)")
            
            // 优先处理文件 URL（包括文件夹、ZIP、普通文件）
            // 注意：必须先检查 fileURL，因为图片文件同时符合 image 和 fileURL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                    if let error = error {
                        self.logger.error("❌ Failed to load file URL: \(error)")
                        return
                    }
                    
                    // 尝试多种方式解析 URL
                    var url: URL?
                    
                    if let data = data as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let urlData = data as? URL {
                        url = urlData
                    } else if let string = data as? String {
                        url = URL(fileURLWithPath: string)
                    }
                    
                    guard let fileURL = url else {
                        self.logger.warning("⚠️ Could not parse URL from drop data")
                        return
                    }
                    
                    self.logger.info("📂 Handling dropped file: \(fileURL.path)")
                    
                    Task { @MainActor in
                        await self.handleFileURL(fileURL, source: .drop, onAdd: onAdd)
                    }
                }
                continue
            }
            
            // 处理直接拖拽的图片（如从浏览器拖拽）
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadObject(ofClass: NSImage.self) { image, error in
                    if let error = error {
                        self.logger.error("❌ Failed to load image: \(error)")
                        return
                    }
                    
                    if let image = image as? NSImage {
                        Task { @MainActor in
                            self.addImage(image, source: .drop, onAdd: onAdd)
                        }
                    }
                }
            }
        }
    }
    
    /// 处理文件 URL（自动识别类型）
    func handleFileURL(_ url: URL, source: AttachmentSource, onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) async {
        // 确保是文件 URL
        let fileURL = url.isFileURL ? url : URL(fileURLWithPath: url.path)
        logger.info("🔍 Processing URL: \(fileURL.path)")
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            logger.warning("⚠️ File not found: \(fileURL.path)")
            return
        }
        
        logger.info("📁 isDirectory: \(isDirectory.boolValue), extension: \(fileURL.pathExtension)")
        
        // 文件夹
        if isDirectory.boolValue {
            logger.info("📂 Handling as folder")
            await handleFolder(fileURL, onAdd: onAdd)
            return
        }
        
        // ZIP 文件（检查多种方式）
        let ext = fileURL.pathExtension.lowercased()
        if ext == "zip" {
            logger.info("📦 Handling as ZIP (by extension)")
            await handleZIP(fileURL, onAdd: onAdd)
            return
        }
        
        if let uti = UTType(filenameExtension: ext), uti.conforms(to: .zip) {
            logger.info("📦 Handling as ZIP (by UTType)")
            await handleZIP(fileURL, onAdd: onAdd)
            return
        }
        
        // 图片文件
        if let uti = UTType(filenameExtension: ext), uti.conforms(to: .image) {
            if let image = NSImage(contentsOf: fileURL) {
                logger.info("🖼️ Handling as image")
                addImage(image, source: source, onAdd: onAdd)
                return
            }
        }
        
        // 普通文件
        logger.info("📄 Handling as regular file")
        addFile(fileURL, onAdd: onAdd)
    }
    
    // MARK: - Image Handling
    
    /// 添加图片附件（异步生成缩略图）
    func addImage(_ image: NSImage, source: AttachmentSource, onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        let id = UUID()
        let attachmentType: Attachment = source == .screenshot
            ? .screenshot(image, nil, id)
            : .image(image, nil, id)
        
        // 先添加占位
        onAdd(attachmentType)
        
        // 后台生成缩略图
        Task.detached(priority: .userInitiated) {
            let thumbnail = Attachment.makeThumbnail(from: image)
            await MainActor.run {
                // 通知更新缩略图（需要外部实现更新逻辑）
                let updated: Attachment = source == .screenshot
                    ? .screenshot(image, thumbnail, id)
                    : .image(image, thumbnail, id)
                // 这里通过 NotificationCenter 通知更新
                NotificationCenter.default.post(
                    name: .attachmentThumbnailUpdated,
                    object: nil,
                    userInfo: ["id": id, "attachment": updated]
                )
            }
        }
    }
    
    /// 添加截图
    func addScreenshot(_ image: NSImage, onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        addImage(image, source: .screenshot, onAdd: onAdd)
    }
    
    // MARK: - File Handling
    
    /// 添加普通文件
    func addFile(_ url: URL, onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        let attachment = Attachment.file(url, UUID())
        onAdd(attachment)
    }
    
    // MARK: - Folder Handling
    
    /// 处理文件夹（提取文本）
    func handleFolder(_ url: URL, onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) async {
        logger.info("📂 Processing folder: \(url.lastPathComponent)")
        
        // 显示初始状态
        processingState = .processing(current: 0, total: 1, fileName: url.lastPathComponent)
        
        let result = await textExtractor.extractFromFolder(url) { [weak self] progress in
            Task { @MainActor in
                self?.processingState = .processing(
                    current: progress.current,
                    total: progress.total,
                    fileName: progress.currentFile
                )
            }
        }
        
        // 恢复空闲状态
        processingState = .idle
        
        switch result {
        case .success(let bundle):
            let attachment = Attachment.textBundle(
                bundle.content,
                url.lastPathComponent,
                bundle.fileCount,
                UUID()
            )
            onAdd(attachment)
            logger.info("✅ Folder processed: \(bundle.fileCount) files, \(bundle.content.count) chars")
            
        case .failure(let error):
            logger.error("❌ Folder processing failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ZIP Handling
    
    /// 处理 ZIP 文件（解压并提取文本）
    func handleZIP(_ url: URL, onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) async {
        logger.info("📦 Processing ZIP: \(url.lastPathComponent)")
        
        // 显示解压状态
        processingState = .processing(current: 0, total: 1, fileName: "解压中...")
        
        let result = await textExtractor.extractFromZIP(url)
        
        // 恢复空闲状态
        processingState = .idle
        
        switch result {
        case .success(let bundle):
            let attachment = Attachment.textBundle(
                bundle.content,
                url.lastPathComponent,
                bundle.fileCount,
                UUID()
            )
            onAdd(attachment)
            logger.info("✅ ZIP processed: \(bundle.fileCount) files, \(bundle.content.count) chars")
            
        case .failure(let error):
            logger.error("❌ ZIP processing failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Picker Actions
    
    /// 打开文件选择器（从设备上传）
    func pickFiles(onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "选择要添加的文件"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                Task {
                    await handleFileURL(url, source: .picker, onAdd: onAdd)
                }
            }
        }
    }
    
    /// 打开文件夹选择器
    func pickFolder(onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "选择要导入的文件夹（将提取所有文本文件）"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await handleFolder(url, onAdd: onAdd)
            }
        }
    }
    
    /// 打开 ZIP 选择器
    func pickZIP(onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = "选择要导入的 ZIP 文件（将解压并提取所有文本文件）"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await handleZIP(url, onAdd: onAdd)
            }
        }
    }
    
    // MARK: - Screenshot
    
    /// 截取当前屏幕
    func captureScreen(onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        Task {
            if let image = await screenCapture.captureCurrentScreen() {
                addScreenshot(image, onAdd: onAdd)
            }
        }
    }
    
    // MARK: - Photos Library
    
    /// 打开图库选择器
    func pickFromPhotos(onAdd: @escaping @MainActor @Sendable (Attachment) -> Void) {
        // 使用 NSOpenPanel 打开 Pictures 目录作为临时方案
        // 后续可以集成 PHPickerViewController
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        panel.message = "从图库选择图片"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    addImage(image, source: .photos, onAdd: onAdd)
                }
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// 附件缩略图更新通知
    static let attachmentThumbnailUpdated = Notification.Name("attachmentThumbnailUpdated")
}
