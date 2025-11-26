import AppKit
import SwiftUI

/// 悬浮胶囊管理器
/// 负责胶囊窗口的生命周期和状态绑定
@MainActor
final class FloatingHUDManager {
    
    // MARK: - Singleton
    
    static let shared = FloatingHUDManager()
    
    // MARK: - Properties
    
    private var panel: FloatingPanel?
    private let state: RecordingState
    
    private var hideTimer: Timer?
    
    /// 完成录音回调（用户点击"完成录音"按钮）
    var onComplete: (() -> Void)?
    /// 取消录音回调（用户点击"取消录音"按钮）
    var onCancel: (() -> Void)?
    
    // MARK: - Init
    
    private init() {
        self.state = RecordingState()
    }
    
    // MARK: - Public API
    
    /// 获取当前录音状态
    var recordingState: RecordingState { state }
    
    /// 显示胶囊（开始录音时调用）
    func show(targetApp: TargetAppInfo?) {
        createPanelIfNeeded()
        
        state.startRecording(targetApp: targetApp)
        
        panel?.orderFront(nil)
        panel?.positionAtTopCenter()
    }
    
    /// 更新录音时长
    func updateDuration(_ duration: TimeInterval) {
        state.updateDuration(duration)
    }
    
    /// 更新音频电平
    func updateAudioLevel(_ level: Float) {
        state.updateAudioLevel(level)
    }
    
    /// 更新实时转写文本
    func updatePartialText(_ text: String) {
        // 先预计算新高度并扩展窗口
        preExpandPanelForText(text)
        
        // 稍微延迟更新文字，让窗口先扩展
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.state.updatePartialText(text)
        }
    }
    
    /// 预先扩展窗口以容纳新文字
    private func preExpandPanelForText(_ text: String) {
        guard let panel = panel,
              let contentView = panel.contentView else { return }
        
        // 临时更新状态以计算新高度
        let oldText = state.partialText
        state.partialText = text
        
        // 获取新的 fitting size
        let fittingSize = contentView.fittingSize
        let newHeight = max(fittingSize.height, 60)
        
        // 恢复旧文字（稍后会正式更新）
        state.partialText = oldText
        
        let oldFrame = panel.frame
        guard abs(oldFrame.height - newHeight) > 1 else { return }
        
        var newFrame = oldFrame
        newFrame.size.height = newHeight
        
        // 使用动画扩展窗口
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }
    
    /// 更新窗口大小（底部固定，向上扩展，带动画）
    private func updatePanelSize() {
        guard let panel = panel,
              let contentView = panel.contentView else { return }
        
        // 重新计算合适尺寸
        let fittingSize = contentView.fittingSize
        let newHeight = max(fittingSize.height, 60)
        
        let oldFrame = panel.frame
        guard abs(oldFrame.height - newHeight) > 1 else { return } // 避免无意义更新
        
        // macOS 窗口原点在左下角
        // 底部固定 = origin.y 不变，只改变高度
        var newFrame = oldFrame
        newFrame.size.height = newHeight
        // origin.y 保持不变，窗口自然向上扩展
        
        // 使用动画平滑过渡
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }
    
    /// 切换到处理状态
    func startProcessing() {
        state.startProcessing()
    }
    
    /// 完成处理
    func complete(with text: String) {
        state.complete(with: text)
        scheduleHide(after: 1.5)
    }
    
    /// 处理失败
    func fail(with message: String) {
        state.fail(with: message)
        scheduleHide(after: 3.0)
    }
    
    /// 隐藏胶囊
    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
                self?.panel?.alphaValue = 1
                self?.state.reset()
            }
        }
    }
    
    // MARK: - Private
    
    private func createPanelIfNeeded() {
        guard panel == nil else { return }
        
        var contentView = FloatingCapsuleView(state: state)
        contentView.onComplete = { [weak self] in
            self?.onComplete?()
        }
        contentView.onCancel = { [weak self] in
            self?.onCancel?()
        }
        contentView.onHoverChange = { [weak self] hovering in
            // Hover 状态变化可能需要更新 UI（比如触发动画），但现在使用 overlay 覆盖整个视图
            // 所以不需要重新计算窗口大小
        }
        
        let framedView = contentView.frame(width: 340) // 固定宽度
        let hostingView = NSHostingView(rootView: framedView)
        
        // 让 hostingView 根据内容自动调整大小
        hostingView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        hostingView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        
        // 获取合适的初始尺寸
        let fittingSize = hostingView.fittingSize
        let initialSize = NSSize(width: 340, height: max(fittingSize.height, 60))
        let frame = NSRect(origin: .zero, size: initialSize)
        
        let newPanel = FloatingPanel(contentRect: frame)
        newPanel.contentView = hostingView
        
        self.panel = newPanel
    }
    
    private func scheduleHide(after delay: TimeInterval) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }
}
