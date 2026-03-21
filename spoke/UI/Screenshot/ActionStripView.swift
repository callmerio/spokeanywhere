import SwiftUI
import Vision

// MARK: - Action Strip View

/// 截图底部操作条
struct ActionStripView: View {
    
    @Bindable var item: ScreenshotItem
    private let dependencies: ScreenshotActionDependencies

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
        HStack(spacing: 4) {
            // Pin 按钮
            ActionButton(
                icon: item.isPinned ? "pin.fill" : "pin",
                isActive: item.isPinned,
                activeColor: DesignTokens.Colors.warning
            ) {
                togglePin()
            }
            .help(item.isPinned ? "Unpin" : "Pin to Space")
            
            // Lock 按钮
            ActionButton(
                icon: item.isLocked ? "lock.fill" : "lock",
                isActive: item.isLocked,
                activeColor: DesignTokens.Colors.accentInfo
            ) {
                toggleLock()
            }
            .help(item.isLocked ? "Unlock" : "Lock")
            
            // Mark 按钮（橙色光晕标记）
            ActionButton(
                icon: item.isMarked ? "bookmark.fill" : "bookmark",
                isActive: item.isMarked,
                activeColor: DesignTokens.Colors.warning
            ) {
                toggleMark()
            }
            .help(item.isMarked ? "Unmark" : "Mark")
            
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)
            
            // Copy 按钮
            ActionButton(icon: "doc.on.doc") {
                copyImage()
            }
            .help("Copy Image")
            
            // OCR 按钮
            ActionButton(icon: "text.viewfinder") {
                performOCR()
            }
            .help("OCR")
            
            // Quick Ask 按钮
            ActionButton(icon: "sparkles") {
                openQuickAsk()
            }
            .help("Quick Ask")
            
            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)
            
            // Close 按钮
            ActionButton(icon: "xmark", activeColor: DesignTokens.Colors.error) {
                closeWindow()
            }
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: DesignTokens.Colors.overlayDark, radius: 4, x: 0, y: 2)
        )
        .padding(.bottom, 12)
    }
    
    // MARK: - Actions
    
    private func togglePin() {
        dependencies.togglePin(item)
        
        if let window = findWindow() {
            window.updateCollectionBehavior()
        }
    }
    
    private func toggleLock() {
        dependencies.toggleLock(item)
        
        if let window = findWindow() {
            window.updateMovable()
        }
    }
    
    private func toggleMark() {
        dependencies.toggleMark(item)
        
        if let window = findWindow() {
            window.updateGlow()
        }
    }
    
    private func copyImage() {
        dependencies.copyImage(item, nil)
    }
    
    private func performOCR() {
        guard let image = item.loadImage(),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        Task.detached {
            let text = await Self.extractText(from: cgImage)
            await MainActor.run {
                if !text.isEmpty {
                    dependencies.copyText(text)
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
        guard let image = item.loadImage() else { return }
        dependencies.startQuickAsk(image)
    }
    
    private func closeWindow() {
        dependencies.closeWindow(item)
    }
    
    private func findWindow() -> ScreenshotWindow? {
        NSApp.windows.first(where: { ($0 as? ScreenshotWindow)?.item.id == item.id }) as? ScreenshotWindow
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    
    let icon: String
    var isActive: Bool = false
    var activeColor: Color = DesignTokens.Colors.textPrimary
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? activeColor : DesignTokens.Colors.textPrimary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovered ? DesignTokens.Colors.buttonActive : DesignTokens.Colors.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
