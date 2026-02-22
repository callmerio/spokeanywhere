import AppKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.spokeanywhere", category: "DictionaryResultManager")

@MainActor
final class DictionaryResultManager {
    
    // MARK: - Singleton
    
    static let shared = DictionaryResultManager()
    
    // MARK: - Properties
    
    private var resultWindow: NSPanel?
    private var currentData: DictionaryData?
    private var currentError: DictionaryAPIError?
    private var currentWord: String?
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    func show(data: DictionaryData, anchorPoint: CGPoint) {
        currentData = data
        currentError = nil
        currentWord = data.word
        showWindow(at: anchorPoint, isError: false)
    }
    
    func showError(word: String, error: DictionaryAPIError, anchorPoint: CGPoint) {
        currentData = nil
        currentError = error
        currentWord = word
        showWindow(at: anchorPoint, isError: true)
    }
    
    /// 显示统一查词结果（支持 UnifiedDictionaryResult）
    func showResult(_ result: UnifiedDictionaryResult, at anchorPoint: CGPoint) {
        // 转换为 DictionaryData 并复用现有逻辑
        let senses = result.senses.map { sense in
            DictionarySense(
                pos: sense.pos,
                chinese: sense.chinese,
                english: sense.english,
                examples: sense.examples.isEmpty ? nil : sense.examples
            )
        }
        
        let data = DictionaryData(
            word: result.word,
            phonetic: result.phonetic,
            senses: senses,
            lemma: result.lemma,
            lemmaInfo: nil
        )
        
        show(data: data, anchorPoint: anchorPoint)
        logger.info("📖 [DictionaryResult] 显示统一查词结果 | 单词: \(result.word) | 来源: \(result.source.rawValue)")
    }
    
    func hide() {
        resultWindow?.orderOut(nil)
        resultWindow = nil
        currentData = nil
        currentError = nil
        currentWord = nil
        logger.debug("📖 [DictionaryResult] 隐藏词典结果")
    }
    
    // MARK: - Private
    
    private func showWindow(at anchorPoint: CGPoint, isError: Bool) {
        if resultWindow == nil {
            createWindow()
        }
        
        guard let window = resultWindow else { return }
        
        let contentView: AnyView
        if isError, let error = currentError, let word = currentWord {
            contentView = AnyView(
                DictionaryResultView(
                    word: word,
                    data: nil,
                    error: error,
                    onDismiss: { [weak self] in self?.hide() }
                )
            )
        } else if let data = currentData {
            contentView = AnyView(
                DictionaryResultView(
                    word: data.word,
                    data: data,
                    error: nil,
                    onDismiss: { [weak self] in self?.hide() }
                )
            )
        } else {
            return
        }
        
        window.contentView = NSHostingView(rootView: contentView)
        
        let windowSize = estimateWindowSize(data: currentData, isError: isError)
        let windowOrigin = calculateWindowOrigin(anchorPoint: anchorPoint, windowSize: windowSize)
        
        window.setFrame(NSRect(origin: windowOrigin, size: windowSize), display: true, animate: true)
        window.orderFrontRegardless()
        
        logger.info("📖 [DictionaryResult] 显示词典结果 | 单词: \(self.currentWord ?? "")")
    }
    
    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        
        resultWindow = panel
    }
    
    private func estimateWindowSize(data: DictionaryData?, isError: Bool) -> NSSize {
        if isError {
            return NSSize(width: 300, height: 60)
        }
        
        guard let data = data else {
            return NSSize(width: 400, height: 80)
        }
        
        let senseCount = min(data.senses.count, 3)
        let baseHeight: CGFloat = 50
        let senseHeight: CGFloat = CGFloat(senseCount) * 28
        let totalHeight = baseHeight + senseHeight
        
        let maxChineseLength = data.senses.prefix(3).compactMap { $0.chinese?.count }.max() ?? 20
        let estimatedWidth = min(max(CGFloat(maxChineseLength) * 14 + 100, 300), 600)
        
        return NSSize(width: estimatedWidth, height: totalHeight)
    }
    
    private func calculateWindowOrigin(anchorPoint: CGPoint, windowSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(x: anchorPoint.x - windowSize.width / 2, y: anchorPoint.y - windowSize.height - 8)
        }
        
        var x = anchorPoint.x - windowSize.width / 2
        var y = anchorPoint.y - windowSize.height - 8
        
        let screenFrame = screen.visibleFrame
        
        if x < screenFrame.minX {
            x = screenFrame.minX + 10
        } else if x + windowSize.width > screenFrame.maxX {
            x = screenFrame.maxX - windowSize.width - 10
        }
        
        if y < screenFrame.minY {
            y = anchorPoint.y + 8
        }
        
        return NSPoint(x: x, y: y)
    }
}
