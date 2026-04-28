import AppKit
import os
import SwiftUI

private let scrollLogger = Logger(subsystem: AppIdentity.logSubsystem, category: "LiveCaptionScroll")

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
        // 🔥 确保 scrollView 本身完全透明
        scrollView.backgroundColor = .clear
        
        // 允许弹性滚动，以便触发 Overscroll
        scrollView.verticalScrollElasticity = .allowed
        
        // 🔥 启用 Layer-Backing 并设置圆角裁剪
        // 这是确保 NSViewRepresentable 在 SwiftUI 中正确显示圆角的关键
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.layer?.cornerRadius = CaptionDesign.cornerRadius
        scrollView.layer?.masksToBounds = true
        
        // 🔥 使用带阻尼的 ClipView，增加滚动"质感"
        let dampedClipView = DampedClipView()
        dampedClipView.wantsLayer = true
        dampedClipView.layer?.backgroundColor = NSColor.clear.cgColor
        dampedClipView.drawsBackground = false
        dampedClipView.scrollDampingFactor = 0.8  // 80% 原速度
        scrollView.contentView = dampedClipView
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        // 🔥 确保 NSHostingView 也透明
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        // 🔥 确保 documentView 透明
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.clear.cgColor
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
        addAppKitScrollObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        
        // 方案 A：监听 documentView 的 frame 变化
        documentView.postsFrameChangedNotifications = true
        addAppKitScrollObserver(
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
            runAppKitScrollOnMain { [weak scrollView, weak coordinator] in
                guard let scrollView = scrollView, let coordinator = coordinator else { return }
                Self.scrollToBottom(scrollView, coordinator: coordinator)
            }
        }
    }
    
    @MainActor
    private static func scrollToBottom(_ scrollView: NSScrollView, coordinator: Coordinator) {
        guard let documentView = scrollView.documentView else { return }

        // 标记程序正在滚动
        coordinator.pendingCatchUpWorkItem?.cancel()
        coordinator.isScrollingProgrammatically = true

        // 🔥 强化布局更新：确保 SwiftUI 内容完全布局
        if let hostingView = documentView.subviews.first {
            hostingView.invalidateIntrinsicContentSize()
            hostingView.needsLayout = true
            hostingView.layoutSubtreeIfNeeded()
        }
        documentView.needsLayout = true
        documentView.layoutSubtreeIfNeeded()

        // 计算滚动目标
        let contentHeight = documentView.frame.height
        let clipHeight = scrollView.contentView.bounds.height
        let maxScrollY = max(0, contentHeight - clipHeight)
        let targetY = maxScrollY + CaptionDesign.scrollExtraOffset

        scrollLogger.debug("📜 scrollToBottom: contentHeight=\(contentHeight), clipHeight=\(clipHeight), maxScrollY=\(maxScrollY), targetY=\(targetY)")
        coordinator.programmaticTargetY = targetY

        // 🔥 动画滚动：平滑过渡替代瞬时跳转
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12  // 120ms 短促动画
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: targetY))
        }

        // 🔥 避免 Sendable closure 捕获泛型 Coordinator：使用 asyncAfter 替代 completion handler
        let workItem = DispatchWorkItem { [weak scrollView, weak coordinator] in
            guard let scrollView = scrollView, let coordinator = coordinator else { return }

            scrollView.reflectScrolledClipView(scrollView.contentView)
            coordinator.isAtBottomBinding.wrappedValue = true
            coordinator.lastScrollY = targetY
            coordinator.lastMaxScrollY = maxScrollY

            // 🔥 追赶检查：动画完成后进行多次延迟检查，确保布局完全更新
            coordinator.performCatchUpScroll(scrollView: scrollView)
        }
        coordinator.pendingCatchUpWorkItem = workItem
        scheduleAppKitScrollWorkItem(after: 0.13, workItem)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        removeAppKitScrollObserver(coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isAtBottom: $isAtBottom, bottomThreshold: bottomThreshold)
    }
    
    @MainActor
    class Coordinator: NSObject {
        var isAtBottomBinding: Binding<Bool>
        var bottomThreshold: CGFloat
        weak var scrollView: NSScrollView?
        var lastScrollTrigger: Int = 0

        /// 防止程序滚动触发循环
        var isScrollingProgrammatically: Bool = false
        var programmaticTargetY: CGFloat?
        var pendingCatchUpWorkItem: DispatchWorkItem?
        var pendingFrameChangeWorkItem: DispatchWorkItem?
        
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
            guard appKitScrollShouldCatchUp(
                gap: gap,
                threshold: CaptionDesign.scrollCatchUpThreshold
            ) else { return }

            isScrollingProgrammatically = true
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxScrollY + CaptionDesign.scrollExtraOffset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            runAppKitScrollOnMain {
                self.isScrollingProgrammatically = false
            }
        }
        
        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let scrollView = scrollView,
                  let documentView = scrollView.documentView else { return }
            
            let contentHeight = documentView.frame.height
            let clipHeight = scrollView.contentView.bounds.height
            let scrollY = scrollView.contentView.bounds.origin.y
            let maxScrollY = max(0, contentHeight - clipHeight)
            let userInterruptedProgrammaticScroll = isScrollingProgrammatically && scrollY < lastScrollY - 3

            if userInterruptedProgrammaticScroll {
                pendingCatchUpWorkItem?.cancel()
                pendingCatchUpWorkItem = nil
                programmaticTargetY = nil
                isScrollingProgrammatically = false
                lastScrollY = scrollY
                lastMaxScrollY = maxScrollY

                runAppKitScrollOnMain {
                    if self.isAtBottomBinding.wrappedValue {
                        self.isAtBottomBinding.wrappedValue = false
                    }
                }
                return
            }

            if isScrollingProgrammatically {
                lastScrollY = scrollY
                lastMaxScrollY = maxScrollY
                return
            }
            
            let atBottom = scrollY >= maxScrollY - bottomThreshold
            let previouslyAtBottom = isAtBottomBinding.wrappedValue
            
            // 🔥 关键修复：区分「用户向上滚动」vs「内容增加导致脱离底部」
            if appKitScrollShouldTreatAsContentGrowth(
                previouslyAtBottom: previouslyAtBottom,
                atBottom: atBottom,
                scrollY: scrollY,
                lastScrollY: lastScrollY,
                maxScrollY: maxScrollY,
                lastMaxScrollY: lastMaxScrollY
            ) {
                // 内容增加且用户没主动滚动 → 追赶滚动
                scrollLogger.debug("📐 Content grew, triggering catch-up scroll (maxScrollY: \(self.lastMaxScrollY) -> \(maxScrollY))")
                lastScrollY = scrollY
                lastMaxScrollY = maxScrollY
                runAppKitScrollOnMain { [weak self] in
                    self?.forceScrollToBottom()
                }
                return
            } else if previouslyAtBottom && !atBottom {
                // 否则是用户主动滚动，让 isAtBottom 正常更新为 false
                scrollLogger.debug("👆 User scrolled up, stopping auto-scroll")
            }
            
            lastScrollY = scrollY
            lastMaxScrollY = maxScrollY
            
            runAppKitScrollOnMain {
                if self.isAtBottomBinding.wrappedValue != atBottom {
                    self.isAtBottomBinding.wrappedValue = atBottom
                }
            }
            
            // 🎯 Overscroll (Pull-up) 检测
            // 阈值调低至 15pt，增加灵敏度
            if appKitScrollShouldHandleOverscroll(
                scrollY: scrollY,
                maxScrollY: maxScrollY
            ) {
                let now = Date()
                if now.timeIntervalSince(lastOverscrollTime) > 1.0 { // 1秒冷却
                    lastOverscrollTime = now
                    scrollLogger.info("🚀 Detected bottom overscroll (Correction Triggered)")
                    
                    // 📳 触觉反馈
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                    
                    // 强制触发一次布局重算和滚动
                    runAppKitScrollOnMain { [weak self] in
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

            // 🔥 强化布局更新
            if let hostingView = documentView.subviews.first {
                hostingView.needsLayout = true
                hostingView.layoutSubtreeIfNeeded()
            }
            documentView.needsLayout = true
            documentView.layoutSubtreeIfNeeded()

            let contentHeight = documentView.frame.height
            let clipHeight = scrollView.contentView.bounds.height
            let maxScrollY = max(0, contentHeight - clipHeight)

            scrollLogger.debug("📜 forceScrollToBottom: contentHeight=\(contentHeight), maxScrollY=\(maxScrollY)")
            programmaticTargetY = maxScrollY + CaptionDesign.scrollExtraOffset

            scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxScrollY + CaptionDesign.scrollExtraOffset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            lastScrollY = maxScrollY + CaptionDesign.scrollExtraOffset
            lastMaxScrollY = maxScrollY

            // 🔥 使用追赶检查确保滚动到位
            performCatchUpScroll(scrollView: scrollView, attempts: 2)
        }

        /// 🔥 追赶滚动：多次延迟检查，确保内容完全布局后滚动到底部
        /// - Parameters:
        ///   - scrollView: 滚动视图
        ///   - attempts: 剩余尝试次数
        private let catchUpInterval: TimeInterval = 0.05  // 50ms
        private let defaultCatchUpAttempts: Int = 3

        func performCatchUpScroll(scrollView: NSScrollView, attempts: Int? = nil) {
            let remainingAttempts = attempts ?? defaultCatchUpAttempts
            guard remainingAttempts > 0 else {
                isScrollingProgrammatically = false
                programmaticTargetY = nil
                return
            }

            pendingCatchUpWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak scrollView] in
                guard let self = self, let scrollView = scrollView else { return }
                guard let documentView = scrollView.documentView else {
                    self.isScrollingProgrammatically = false
                    self.programmaticTargetY = nil
                    return
                }

                // 强制布局
                if let hostingView = documentView.subviews.first {
                    hostingView.needsLayout = true
                    hostingView.layoutSubtreeIfNeeded()
                }
                documentView.needsLayout = true
                documentView.layoutSubtreeIfNeeded()

                let newContentHeight = documentView.frame.height
                // 🔥 修复：重新计算 clipHeight 而不是使用传入参数（可能已过时）
                let clipHeight = scrollView.contentView.bounds.height
                let newMaxScrollY = max(0, newContentHeight - clipHeight)
                let currentY = scrollView.contentView.bounds.origin.y

                    scrollLogger.debug("📜 catchUp[\(self.defaultCatchUpAttempts - remainingAttempts + 1)]: contentHeight=\(newContentHeight), maxScrollY=\(newMaxScrollY), currentY=\(currentY)")

                // 如果内容高度增加了，追赶滚动
                if appKitScrollShouldCatchUp(
                    gap: newMaxScrollY - currentY,
                    threshold: CaptionDesign.scrollCatchUpThreshold
                ) {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: newMaxScrollY + CaptionDesign.scrollExtraOffset))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                    self.lastScrollY = newMaxScrollY + CaptionDesign.scrollExtraOffset
                    self.lastMaxScrollY = newMaxScrollY
                    self.programmaticTargetY = newMaxScrollY + CaptionDesign.scrollExtraOffset
                    // 继续下一次检查（确保 scrollView 仍在窗口中）
                    guard scrollView.window != nil else {
                        self.isScrollingProgrammatically = false
                        self.programmaticTargetY = nil
                        return
                    }
                    self.performCatchUpScroll(scrollView: scrollView, attempts: remainingAttempts - 1)
                } else {
                    // 已到底部，完成
                    self.isScrollingProgrammatically = false
                    self.programmaticTargetY = nil
                    self.pendingCatchUpWorkItem = nil
                }
            }
            pendingCatchUpWorkItem = workItem
            scheduleAppKitScrollWorkItem(after: catchUpInterval, workItem)
        }

        /// 方案 A 的 frame 观察仍保留作为补充
        @objc func documentViewFrameChanged(_ notification: Notification) {
            pendingFrameChangeWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.checkAndScrollToBottom()
            }
            pendingFrameChangeWorkItem = workItem
            scheduleAppKitScrollWorkItem(after: 0.05, workItem)
        }
        
        deinit {
            pendingCatchUpWorkItem?.cancel()
            pendingFrameChangeWorkItem?.cancel()
        }
    }
    
    /// Flipped NSView（使坐标系从上到下）
    private class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }
    
    /// 带阻尼的 ClipView - 减缓滚轮滚动速度
    /// 🔥 确保完全透明，不绘制任何背景
    class DampedClipView: NSClipView {
        /// 滚动速度衰减因子（0.8 = 80% 原速度）
        var scrollDampingFactor: CGFloat = 0.8
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.drawsBackground = false
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.drawsBackground = false
        }
        
        // 🔥 强制不绘制背景
        override var drawsBackground: Bool {
            get { false }
            set { }
        }
        
        override func scrollWheel(with event: NSEvent) {
            // 对于触控板和鼠标滚轮，减缓滚动速度
            // 通过手动计算新位置来实现阻尼效果
            let deltaY = event.scrollingDeltaY * scrollDampingFactor
            let deltaX = event.scrollingDeltaX * scrollDampingFactor
            
            var newOrigin = bounds.origin
            newOrigin.y -= deltaY  // 注意：向下滚动 deltaY 为负
            newOrigin.x -= deltaX
            
            // 边界检查
            if let documentView = documentView {
                let maxY = max(0, documentView.frame.height - bounds.height)
                let maxX = max(0, documentView.frame.width - bounds.width)
                newOrigin.y = min(max(0, newOrigin.y), maxY)
                newOrigin.x = min(max(0, newOrigin.x), maxX)
            }
            
            scroll(to: newOrigin)
            enclosingScrollView?.reflectScrolledClipView(self)
        }
    }
}
