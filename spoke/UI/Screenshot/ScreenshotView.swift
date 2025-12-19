import SwiftUI
import Vision

// MARK: - Screenshot View

/// 截图视图（SwiftUI）
struct ScreenshotView: View {
    
    @Bindable var item: ScreenshotItem
    @State private var isHovered = false
    
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
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            // Action Strip (hover 时显示)
            if isHovered {
                ActionStripView(item: item)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Lock 指示器（左上角）- 移除了右上角 Pin 指示器
            if item.isLocked {
                VStack {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                            )
                            .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            togglePin()
        } label: {
            Label(item.isPinned ? "Unpin" : "Pin to Space", systemImage: item.isPinned ? "pin.slash" : "pin")
        }
        
        Button {
            toggleLock()
        } label: {
            Label(item.isLocked ? "Unlock" : "Lock", systemImage: item.isLocked ? "lock.open" : "lock")
        }
        
        Divider()
        
        Button {
            copyImage()
        } label: {
            Label("Copy Image", systemImage: "doc.on.doc")
        }
        
        Button {
            performOCR()
        } label: {
            Label("OCR", systemImage: "text.viewfinder")
        }
        
        Button {
            openQuickAsk()
        } label: {
            Label("Quick Ask", systemImage: "sparkles")
        }
        
        Divider()
        
        Button(role: .destructive) {
            closeWindow()
        } label: {
            Label("Close", systemImage: "xmark")
        }
    }
    
    // MARK: - Actions
    
    private func togglePin() {
        if item.isPinned {
            ScreenshotManager.shared.unpin(item)
        } else {
            ScreenshotManager.shared.pin(item)
        }
        
        // 更新窗口行为
        if let window = NSApp.windows.first(where: { ($0 as? ScreenshotWindow)?.item.id == item.id }) as? ScreenshotWindow {
            window.updateCollectionBehavior()
        }
    }
    
    private func toggleLock() {
        if item.isLocked {
            ScreenshotManager.shared.unlock(item)
        } else {
            ScreenshotManager.shared.lock(item)
        }
        
        // 更新窗口可拖动状态
        if let window = NSApp.windows.first(where: { ($0 as? ScreenshotWindow)?.item.id == item.id }) as? ScreenshotWindow {
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
}
