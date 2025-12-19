import SwiftUI
import Vision

// MARK: - Action Strip View

/// 截图底部操作条
struct ActionStripView: View {
    
    @Bindable var item: ScreenshotItem
    
    var body: some View {
        HStack(spacing: 4) {
            // Pin 按钮
            ActionButton(
                icon: item.isPinned ? "pin.fill" : "pin",
                isActive: item.isPinned,
                activeColor: .orange
            ) {
                togglePin()
            }
            .help(item.isPinned ? "Unpin" : "Pin to Space")
            
            // Lock 按钮
            ActionButton(
                icon: item.isLocked ? "lock.fill" : "lock",
                isActive: item.isLocked,
                activeColor: .blue
            ) {
                toggleLock()
            }
            .help(item.isLocked ? "Unlock" : "Lock")
            
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
            ActionButton(icon: "xmark", activeColor: .red) {
                closeWindow()
            }
            .help("Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .padding(.bottom, 12)
    }
    
    // MARK: - Actions
    
    private func togglePin() {
        if item.isPinned {
            ScreenshotManager.shared.unpin(item)
        } else {
            ScreenshotManager.shared.pin(item)
        }
        
        if let window = findWindow() {
            window.updateCollectionBehavior()
        }
    }
    
    private func toggleLock() {
        if item.isLocked {
            ScreenshotManager.shared.unlock(item)
        } else {
            ScreenshotManager.shared.lock(item)
        }
        
        if let window = findWindow() {
            window.updateMovable()
        }
    }
    
    private func copyImage() {
        ScreenshotManager.shared.copyToClipboard(item)
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
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                }
            }
        }
    }
    
    private static func extractText(from image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
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
        
        // 先启动会话（会清空状态），再添加截图
        QuickAskService.shared.startSession()
        QuickAskService.shared.state.addScreenshot(image)
    }
    
    private func closeWindow() {
        ScreenshotManager.shared.close(item)
    }
    
    private func findWindow() -> ScreenshotWindow? {
        NSApp.windows.first(where: { ($0 as? ScreenshotWindow)?.item.id == item.id }) as? ScreenshotWindow
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    
    let icon: String
    var isActive: Bool = false
    var activeColor: Color = .white
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? activeColor : .primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovered ? Color.white.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
