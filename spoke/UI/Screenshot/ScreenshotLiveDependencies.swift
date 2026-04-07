import AppKit
import Foundation

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
        let services = currentServiceContainer()
        let screenshotManager = services.screenshotManager
        let quickAskService = services.quickAskServiceConcrete
        let imageEnhancementService = services.imageEnhancementService
        let screenshotSettings = services.screenshotSettings
        let selectionToolbarState = services.selectionToolbarState
        let selectionToolbarManager = services.selectionToolbarManager
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
