import SwiftUI
import Vision

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

@MainActor
extension ScreenshotActionDependencies {
    private static func toggleAction(
        isEnabled: @escaping (ScreenshotItem) -> Bool,
        enable: @escaping (ScreenshotManager, ScreenshotItem) -> Void,
        disable: @escaping (ScreenshotManager, ScreenshotItem) -> Void,
        manager: ScreenshotManager
    ) -> (ScreenshotItem) -> Void {
        { item in
            if isEnabled(item) {
                disable(manager, item)
            } else {
                enable(manager, item)
            }
        }
    }

    private static func copyImageToPasteboard(_ image: NSImage, pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    private static func copyTextToPasteboard(_ text: String, pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func screenshotWindow(for itemID: UUID) -> ScreenshotWindow? {
        NSApp.windows
            .compactMap { $0 as? ScreenshotWindow }
            .first(where: { $0.item.id == itemID })
    }

    private static func withWindow(_ itemID: UUID, perform update: (ScreenshotWindow) -> Void) {
        guard let window = screenshotWindow(for: itemID) else {
            return
        }
        update(window)
    }

    static let live: ScreenshotActionDependencies = {
        let screenshotManager = ScreenshotManager.shared
        let quickAskService = QuickAskService.shared
        let imageEnhancementService = ImageEnhancementService.shared
        let screenshotSettings = ScreenshotSettings.shared
        let selectionToolbarState = SelectionToolbarState.shared
        let selectionToolbarManager = SelectionToolbarManager.shared
        let pasteboard = NSPasteboard.general

        return ScreenshotActionDependencies(
            togglePin: Self.toggleAction(
                isEnabled: \.isPinned,
                enable: { manager, item in manager.pin(item) },
                disable: { manager, item in manager.unpin(item) },
                manager: screenshotManager
            ),
            toggleLock: Self.toggleAction(
                isEnabled: \.isLocked,
                enable: { manager, item in manager.lock(item) },
                disable: { manager, item in manager.unlock(item) },
                manager: screenshotManager
            ),
            toggleMark: Self.toggleAction(
                isEnabled: \.isMarked,
                enable: { manager, item in manager.mark(item) },
                disable: { manager, item in manager.unmark(item) },
                manager: screenshotManager
            ),
            withWindow: { itemID, update in
                Self.withWindow(itemID, perform: update)
            },
            updateWindowCollectionBehavior: { itemID in
                Self.withWindow(itemID) { window in
                    window.updateCollectionBehavior()
                }
            },
            updateWindowMovable: { itemID in
                Self.withWindow(itemID) { window in
                    window.updateMovable()
                }
            },
            copyImage: { item, enhancedImage in
                screenshotManager.copyToClipboard(item, enhancedImage: enhancedImage)
            },
            copyRawImage: { image in
                Self.copyImageToPasteboard(image, pasteboard: pasteboard)
            },
            closeWindow: { item in
                screenshotManager.close(item)
            },
            startQuickAsk: { image in
                quickAskService.startSession()
                quickAskService.state.addScreenshot(image)
            },
            enhanceImage: { image, targetSize in
                imageEnhancementService.enhance(image, to: targetSize)
            },
            enhanceBasic: { image, targetSize in
                await imageEnhancementService.enhanceBasic(image, to: targetSize)
            },
            enhanceAIHighRes: { image in
                await imageEnhancementService.enhanceAIHighResAsync(image)
            },
            scaleImage: { image, targetSize, backingScale in
                imageEnhancementService.scaleNSImage(image, to: targetSize, backingScale: backingScale)
            },
            shouldShowEnhancedCopy: {
                screenshotSettings.upscalingMode != .none
            },
            showSelectionToolbar: { context, point in
                selectionToolbarState.show(with: context)
                selectionToolbarManager.show(at: point)
            },
            saveWindowState: {
                screenshotManager.saveAll()
            },
            notificationCenter: .default,
            copyText: { text in
                Self.copyTextToPasteboard(text, pasteboard: pasteboard)
            }
        )
    }()
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
        contextMenuButton(pinMenuTitle, systemImage: pinMenuImage, action: togglePin)
        
        contextMenuButton(lockMenuTitle, systemImage: lockMenuImage, action: toggleLock)
        
        Divider()
        
        contextMenuButton("Copy Image", systemImage: "doc.on.doc", action: copyImage)
        
        contextMenuButton("OCR", systemImage: "text.viewfinder", action: performOCR)
        
        contextMenuButton("Quick Ask", systemImage: "sparkles", action: openQuickAsk)
        
        Divider()
        
        contextMenuButton("Close", systemImage: "xmark", role: .destructive, action: closeWindow)
    }
    
    // MARK: - Actions

    private var pinMenuTitle: String {
        item.isPinned ? "Unpin" : "Pin to Space"
    }

    private var pinMenuImage: String {
        item.isPinned ? "pin.slash" : "pin"
    }

    private var lockMenuTitle: String {
        item.isLocked ? "Unlock" : "Lock"
    }

    private var lockMenuImage: String {
        item.isLocked ? "lock.open" : "lock"
    }

    @ViewBuilder
    private func contextMenuButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
        }
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
            Task.detached {
                let text = await Self.extractText(from: cgImage)
                await MainActor.run {
                    if !text.isEmpty {
                        dependencies.copyText(text)
                    }
                }
            }
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
