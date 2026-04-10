import AppKit
import Vision

extension ScreenshotContentView {
    private var actionDependencies: ScreenshotActionDependencies { dependencies }

    // MARK: - Actions

    @objc func performPinAction() {
        actionDependencies.togglePin(item)

        if let window = window as? ScreenshotWindow {
            window.updateCollectionBehavior()
        }
        refreshMenuItems()
        // 刷新 ActionBar 的 Pin 图标状态
        actionBar?.refreshButtons()
    }

    @objc func performLockAction() {
        actionDependencies.toggleLock(item)

        if let window = window as? ScreenshotWindow {
            window.updateMovable()
        }
        refreshMenuItems()
    }

    @objc func performCopyImage() {
        actionDependencies.copyImage(item, imageView.image)
    }

    /// 获取当前显示的图片（可能是 AI 增强后的）
    func getCurrentDisplayImage() -> NSImage? {
        return imageView.image
    }

    /// 复制增强后的图片（如果未增强则先触发增强）
    @objc func performCopyEnhancedImage() {
        guard let original = originalImage else { return }

        // 如果当前已有增强图片（与原图不同），直接复制
        if let currentImage = imageView.image, currentImage !== original {
            copyImageToClipboard(currentImage)
            return
        }

        // 否则触发增强后复制
        let targetSize = CGSize(
            width: original.size.width * 2,  // 2x 放大
            height: original.size.height * 2
        )

        logger.info("🎨 Enhancing image before copy...")

        runScreenshotEnhancedCopy(
            original: original,
            targetSize: targetSize,
            enhance: actionDependencies.enhanceImage
        ) { enhanced in
            if let enhanced = enhanced {
                self.copyImageToClipboard(enhanced)
                self.logger.info("✅ Enhanced image copied to clipboard")
            } else {
                // 增强失败，复制原图
                self.copyImageToClipboard(original)
                self.logger.warning("⚠️ Enhancement failed, copied original image")
            }
        }
    }

    private func copyImageToClipboard(_ image: NSImage) {
        actionDependencies.copyRawImage(image)
    }

    @objc func performOCR() {
        // Legacy OCR method for macOS 12
        if #available(macOS 13.0, *) { return }
        guard let image = item.loadImage(),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        runScreenshotLegacyOCR(
            cgImage: cgImage,
            extractText: Self.extractText
        ) { text in
            if !text.isEmpty {
                self.actionDependencies.copyText(text)
            }
        }
    }

    @objc func performCopyText() {
        if let text = getRecognizedText(), !text.isEmpty {
            actionDependencies.copyText(text)
        }
    }

    static func extractText(from image: CGImage) async -> String {
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

    @objc func performQuickAsk() {
        guard let image = item.loadImage() else { return }
        actionDependencies.startQuickAsk(image)
    }

    // 公开给 Window 调用，支持快捷键 A 触发
    func triggerQuickAsk() {
        performQuickAsk()
    }

    @objc func performCloseAction() {
        actionDependencies.closeWindow(item)
    }

    @objc func performMarkAction() {
        actionDependencies.toggleMark(item)
        setupContextMenu()
        // 刷新光晕效果
        updateGlow(isHovered: isHovered, isMarked: item.isMarked, isPinned: item.isPinned)
        // 刷新 ActionBar Pin 按钮状态（Mark 会自动 Pin）
        actionBar?.refreshButtons()
    }
}
