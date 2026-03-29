import SwiftUI
import Vision

private struct ScreenshotContextMenuAction {
    let id: String
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void
}

@MainActor
struct ScreenshotActionDependencies {
    let togglePin: (ScreenshotItem) -> Void
    let toggleLock: (ScreenshotItem) -> Void
    let toggleMark: (ScreenshotItem) -> Void
    let withWindow: (UUID, (ScreenshotWindow) -> Void) -> Void
    let updateWindowCollectionBehavior: (UUID) -> Void
    let updateWindowMovable: (UUID) -> Void
    let copyImage: (ScreenshotItem, NSImage?) -> Void
    let copyRawImage: (NSImage) -> Void
    let closeWindow: (ScreenshotItem) -> Void
    let startQuickAsk: (NSImage) -> Void
    let enhanceImage: @MainActor (NSImage, CGSize) -> NSImage?
    let enhanceBasic: @Sendable (NSImage, CGSize) async -> NSImage?
    let enhanceAIHighRes: @Sendable (NSImage) async -> NSImage?
    let scaleImage: (NSImage, CGSize, CGFloat) -> NSImage?
    let shouldShowEnhancedCopy: () -> Bool
    let showSelectionToolbar: (SelectionContext, CGPoint) -> Void
    let saveWindowState: () -> Void
    let notificationCenter: NotificationCenter
    let copyText: (String) -> Void
}

// MARK: - Screenshot View

/// 截图视图（SwiftUI）
struct ScreenshotView: View {
    
    @Bindable var item: ScreenshotItem
    private let dependencies: ScreenshotActionDependencies
    @State private var isHovered = false

    init(
        item: ScreenshotItem,
        dependencies: ScreenshotActionDependencies
    ) {
        self.item = item
        self.dependencies = dependencies
    }

    @MainActor
    init(item: ScreenshotItem) {
        self.init(item: item, dependencies: .live)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 图片内容（填充整个窗口，不使用 .fit 避免约束循环）
            if let image = item.loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(item.opacity)
            } else {
                Rectangle()
                    .fill(DesignTokens.Colors.cardBackground)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    )
            }
            
            // Action Strip (hover 时显示)
            if isHovered {
                ActionStripView(item: item, dependencies: dependencies)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Lock 指示器（左上角）- 移除了右上角 Pin 指示器
            if item.isLocked {
                VStack {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(DesignTokens.Colors.overlayMedium)
                            )
                            .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: DesignTokens.Colors.overlayDark, radius: 8, x: 0, y: 4)
        .onHover { hovering in
            setHoverState(hovering)
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuItems: some View {
        let sections = contextMenuSections
        ForEach(Array(sections.enumerated()), id: \.offset) { sectionIndex, actions in
            if sectionIndex > 0 {
                Divider()
            }

            ForEach(actions, id: \.id) { menuAction in
                contextMenuButton(menuAction)
            }
        }
    }
    
    // MARK: - Actions

    @ViewBuilder
    private func contextMenuButton(
        _ action: ScreenshotContextMenuAction
    ) -> some View {
        Button(role: action.role, action: action.action) {
            Label(action.title, systemImage: action.systemImage)
        }
    }

    private var contextMenuSections: [[ScreenshotContextMenuAction]] {
        [
            [
                ScreenshotContextMenuAction(
                    id: "pin",
                    title: item.isPinned ? "Unpin" : "Pin to Space",
                    systemImage: item.isPinned ? "pin.slash" : "pin",
                    role: nil,
                    action: togglePin
                ),
                ScreenshotContextMenuAction(
                    id: "lock",
                    title: item.isLocked ? "Unlock" : "Lock",
                    systemImage: item.isLocked ? "lock.open" : "lock",
                    role: nil,
                    action: toggleLock
                ),
            ],
            [
                ScreenshotContextMenuAction(
                    id: "copy",
                    title: "Copy Image",
                    systemImage: "doc.on.doc",
                    role: nil,
                    action: copyImage
                ),
                ScreenshotContextMenuAction(
                    id: "ocr",
                    title: "OCR",
                    systemImage: "text.viewfinder",
                    role: nil,
                    action: performOCR
                ),
                ScreenshotContextMenuAction(
                    id: "quick-ask",
                    title: "Quick Ask",
                    systemImage: "sparkles",
                    role: nil,
                    action: openQuickAsk
                ),
            ],
            [
                ScreenshotContextMenuAction(
                    id: "close",
                    title: "Close",
                    systemImage: "xmark",
                    role: .destructive,
                    action: closeWindow
                ),
            ],
        ]
    }

    private func setHoverState(_ hovering: Bool) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isHovered = hovering
        }
    }

    private func performItemAction(
        _ action: (ScreenshotItem) -> Void,
        synchronizeWindow update: ((UUID) -> Void)? = nil
    ) {
        action(item)
        update?(item.id)
    }
    
    private func togglePin() {
        performItemAction(dependencies.togglePin, synchronizeWindow: dependencies.updateWindowCollectionBehavior)
    }
    
    private func toggleLock() {
        performItemAction(dependencies.toggleLock, synchronizeWindow: dependencies.updateWindowMovable)
    }
    
    private func copyImage() {
        dependencies.copyImage(item, nil)
    }

    private func withLoadedImage(_ action: (NSImage) -> Void) {
        guard let image = item.loadImage() else {
            return
        }
        action(image)
    }

    private func withLoadedCGImage(_ action: (CGImage) -> Void) {
        withLoadedImage { image in
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return
            }
            action(cgImage)
        }
    }
    
    private func performOCR() {
        withLoadedCGImage { cgImage in
            runScreenshotOCR(cgImage, copyText: dependencies.copyText)
        }
    }
    
    private static func extractText(from image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func openQuickAsk() {
        withLoadedImage { image in
            dependencies.startQuickAsk(image)
        }
    }
    
    private func closeWindow() {
        dependencies.closeWindow(item)
    }
}
