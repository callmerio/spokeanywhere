import AppKit
import os
import SwiftUI

private let scrollLogger = Logger(subsystem: "app.spokenly", category: "LiveCaptionScroll")

// MARK: - NSScrollView Bridge

/// NSScrollView 桥接，用于精确检测滚动位置
struct AppKitScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    @Binding var isAtBottom: Bool
    let scrollTrigger: Int  // 当此值变化时滚动到底部
    
    /// 底部检测容差（增大以容忍布局计算误差）
    private let bottomThreshold: CGFloat = CaptionDesign.scrollBottomThreshold
    
    init(isAtBottom: Binding<Bool>, scrollTrigger: Int, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._isAtBottom = isAtBottom
        self.scrollTrigger = scrollTrigger
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        
        // 允许弹性滚动，以便触发 Overscroll
        scrollView.verticalScrollElasticity = .allowed
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hostingView)
        
        // hostingView 填满 documentView
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: documentView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])
        
        scrollView.documentView = documentView
        
        // 关键：让 documentView 宽度跟随 clipView（内容区），这样文字才会换行
        NSLayoutConstraint.activate([
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        // 监听滚动
        context.coordinator.scrollView = scrollView
        // 使用 boundsDidChangeNotification 监听滚动，比 didLiveScroll 更灵敏（包含弹性动画）
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        
        // 方案 A：监听 documentView 的 frame 变化
        documentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.documentViewFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: documentView
        )
        
        // 保存初始 trigger
        context.coordinator.lastScrollTrigger = scrollTrigger
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // 更新内容
        if let documentView = scrollView.documentView,
           let hostingView = documentView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
        
        // 更新 coordinator 的引用
        context.coordinator.isAtBottomBinding = $isAtBottom
        context.coordinator.bottomThreshold = bottomThreshold
        
        // 检查是否需要滚动到底部
        let shouldScroll = scrollTrigger != context.coordinator.lastScrollTrigger
        context.coordinator.lastScrollTrigger = scrollTrigger
        
        if shouldScroll && isAtBottom {
            let coordinator = context.coordinator
            // 下一个 RunLoop 执行
            DispatchQueue.main.async { [weak scrollView, weak coordinator] in
                guard let scrollView = scrollView, let coordinator = coordinator else { return }
                Self.scrollToBottom(scrollView, coordinator: coordinator)
            }
        }
    }
    
    private static func scrollToBottom(_ scrollView: NSScrollView, coordinator: Coordinator) {
        guard let documentView = scrollView.documentView else { return }
        
        // 标记程序正在滚动
        coordinator.isScrollingProgrammatically = true
        defer { coordinator.isScrollingProgrammatically = false }
        
        // 强制布局更新
        if let hostingView = documentView.subviews.first {
            hostingView.invalidateIntrinsicContentSize()
            hostingView.layoutSubtreeIfNeeded()
        }
        documentView.layoutSubtreeIfNeeded()
        
        // 计算并执行滚动
        let contentHeight = documentView.frame.height
        let clipHeight = scrollView.contentView.bounds.height
        let maxScrollY = max(0, contentHeight - clipHeight)
        
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxScrollY + CaptionDesign.scrollExtraOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        coordinator.isAtBottomBinding.wrappedValue = true
        coordinator.lastScrollY = maxScrollY + CaptionDesign.scrollExtraOffset
        
        // 🔥 追赶检查：100ms 后再次检查是否真的到底部
        // 解决"一口气输出太多"时布局更新滞后的问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak scrollView, weak coordinator] in
            guard let scrollView = scrollView, let coordinator = coordinator else { return }
            guard let documentView = scrollView.documentView else { return }
            
            // 再次强制布局
            if let hostingView = documentView.subviews.first {
                hostingView.layoutSubtreeIfNeeded()
            }
            documentView.layoutSubtreeIfNeeded()
            
            let newContentHeight = documentView.frame.height
            let newMaxScrollY = max(0, newContentHeight - clipHeight)
            let currentY = scrollView.contentView.bounds.origin.y
            
            // 如果内容高度增加了，追赶滚动
            if newMaxScrollY > currentY + CaptionDesign.scrollCatchUpThreshold {
                coordinator.isScrollingProgrammatically = true
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: newMaxScrollY + CaptionDesign.scrollExtraOffset))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                coordinator.lastScrollY = newMaxScrollY + CaptionDesign.scrollExtraOffset
                DispatchQueue.main.async {
                    coordinator.isScrollingProgrammatically = false
                }
            }
        }
    }
    
    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.stopPolling()
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isAtBottom: $isAtBottom, bottomThreshold: bottomThreshold)
    }
    
    class Coordinator: NSObject {
        var isAtBottomBinding: Binding<Bool>
        var bottomThreshold: CGFloat
        weak var scrollView: NSScrollView?
        var lastScrollTrigger: Int = 0
        
        /// 防止程序滚动触发循环
        var isScrollingProgrammatically: Bool = false
        
        /// 定时器轮询
        private var scrollTimer: Timer?
        
        /// 上次触发防抖时间
        private var lastOverscrollTime: Date = .distantPast
        
        /// 上次滚动位置（用于区分用户滚动 vs 内容增加）
        var lastScrollY: CGFloat = 0
        
        /// 上次的 maxScrollY（用于检测内容是否增加）
        var lastMaxScrollY: CGFloat = 0
        
        init(isAtBottom: Binding<Bool>, bottomThreshold: CGFloat) {
            self.isAtBottomBinding = isAtBottom
            self.bottomThreshold = bottomThreshold
            super.init()
            startPolling()
        }
        
        func startPolling() {
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.checkAndScrollToBottom()
            }
        }
        
        func stopPolling() {
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
        
        private func checkAndScrollToBottom() {
            guard !isScrollingProgrammatically else { return }
            guard isAtBottomBinding.wrappedValue else { return }
            guard let scrollView = scrollView,
                  let documentView = scrollView.documentView else { return }
            
            if let hostingView = documentView.subviews.first {
                hostingView.layoutSubtreeIfNeeded()
            }
            documentView.layoutSubtreeIfNeeded()
            
            let contentHeight = documentView.frame.height
            let clipHeight = scrollView.contentView.bounds.height
            let currentY = scrollView.contentView.bounds.origin.y
            let maxScrollY = max(0, contentHeight - clipHeight)
            
            let gap = maxScrollY - currentY
            if gap > 500 { return }
            
            if gap > CaptionDesign.scrollCatchUpThreshold {
                isScrollingProgrammatically = true
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxScrollY + CaptionDesign.scrollExtraOffset))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                DispatchQueue.main.async {
                    self.isScrollingProgrammatically = false
                }
            }
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard !isScrollingProgrammatically else { return }
            guard let scrollView = scrollView,
                  let documentView = scrollView.documentView else { return }
            
            let contentHeight = documentView.frame.height
            let clipHeight = scrollView.contentView.bounds.height
            let scrollY = scrollView.contentView.bounds.origin.y
            let maxScrollY = max(0, contentHeight - clipHeight)
            
            let atBottom = scrollY >= maxScrollY - bottomThreshold
            let previouslyAtBottom = isAtBottomBinding.wrappedValue
            
            // 🔥 关键修复：区分「用户向上滚动」vs「内容增加导致脱离底部」
            if previouslyAtBottom && !atBottom {
                // 之前在底部，现在不在了
                // 💡 新策略：通过 maxScrollY 是否增加来判断是否有新内容
                let contentGrew = maxScrollY > lastMaxScrollY + 5  // 5pt 容差
                let userScrolledAway = scrollY < lastScrollY - 3   // 用户主动滚动离开（3pt 容差，更灵敏）
                
                if contentGrew && !userScrolledAway {
                    // 内容增加且用户没主动滚动 → 追赶滚动
                    scrollLogger.debug("📐 Content grew, triggering catch-up scroll (maxScrollY: \(self.lastMaxScrollY) -> \(maxScrollY))")
                    lastScrollY = scrollY
                    lastMaxScrollY = maxScrollY
                    DispatchQueue.main.async { [weak self] in
                        self?.forceScrollToBottom()
                    }
                    return
                }
                // 否则是用户主动滚动，让 isAtBottom 正常更新为 false
                scrollLogger.debug("👆 User scrolled up, stopping auto-scroll")
            }
            
            lastScrollY = scrollY
            lastMaxScrollY = maxScrollY
            
            DispatchQueue.main.async {
                if self.isAtBottomBinding.wrappedValue != atBottom {
                    self.isAtBottomBinding.wrappedValue = atBottom
                }
            }
            
            // 🎯 Overscroll (Pull-up) 检测
            // 阈值调低至 15pt，增加灵敏度
            if scrollY > maxScrollY + 15 {
                let now = Date()
                if now.timeIntervalSince(lastOverscrollTime) > 1.0 { // 1秒冷却
                    lastOverscrollTime = now
                    scrollLogger.info("🚀 Detected bottom overscroll (Correction Triggered)")
                    
                    // 📳 触觉反馈
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    
                    // 强制触发一次布局重算和滚动
                    DispatchQueue.main.async { [weak self] in
                        self?.checkAndScrollToBottom()
                    }
                }
            }
        }
        
        /// 强制滚动到底部（不检查 isAtBottom 状态）
        /// 用于内容增加导致脱离底部时的追赶滚动
        func forceScrollToBottom() {
            guard !isScrollingProgrammatically else { return }
            guard let scrollView = scrollView,
                  let documentView = scrollView.documentView else { return }
            
            isScrollingProgrammatically = true
            defer { 
                DispatchQueue.main.async {
                    self.isScrollingProgrammatically = false
                }
            }
            
            // 强制布局
            if let hostingView = documentView.subviews.first {
                hostingView.layoutSubtreeIfNeeded()
            }
            documentView.layoutSubtreeIfNeeded()
            
            let contentHeight = documentView.frame.height
            let clipHeight = scrollView.contentView.bounds.height
            let maxScrollY = max(0, contentHeight - clipHeight)
            
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxScrollY + CaptionDesign.scrollExtraOffset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            lastScrollY = maxScrollY + CaptionDesign.scrollExtraOffset
        }
        
        /// 方案 A 的 frame 观察仍保留作为补充
        /// 🔥 添加 50ms 防抖，防止频繁触发
        private var lastFrameChangeTime: Date = .distantPast
        @objc func documentViewFrameChanged(_ notification: Notification) {
            let now = Date()
            guard now.timeIntervalSince(lastFrameChangeTime) > 0.05 else { return }
            lastFrameChangeTime = now
            checkAndScrollToBottom()
        }
        
        deinit {
            stopPolling()
        }
    }
    
    /// Flipped NSView（使坐标系从上到下）
    private class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }
}
