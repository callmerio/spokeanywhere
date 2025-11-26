import AppKit
import SwiftUI

/// 悬浮胶囊管理器
/// 负责胶囊窗口的生命周期和状态绑定
@MainActor
final class FloatingHUDManager {
    
    // MARK: - Constants
    
    /// 窗口固定高度（足够容纳最大内容，内容从底部向上扩展）
    private static let fixedWindowHeight: CGFloat = 300
    private static let fixedWindowWidth: CGFloat = 340
    
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
        panel?.positionAtBottomCenter()
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
        state.updatePartialText(text)
        // 不再需要更新窗口大小，窗口是固定的
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
        contentView.onHoverChange = { _ in }
        
        // 固定宽度，内容从底部向上扩展
        let framedView = contentView
            .frame(width: Self.fixedWindowWidth, height: Self.fixedWindowHeight, alignment: .bottom)
        
        let hostingView = NSHostingView(rootView: framedView)
        
        // 固定窗口大小
        let frame = NSRect(
            origin: .zero,
            size: NSSize(width: Self.fixedWindowWidth, height: Self.fixedWindowHeight)
        )
        
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
