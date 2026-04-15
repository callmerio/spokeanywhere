import AppKit
import Foundation
import os

// MARK: - Pinned Text Manager

@MainActor
struct PinnedTextManagerDependencies {
    let pasteboardText: () -> String?
    let storageRootDirectory: () -> URL
    let beep: () -> Void
}

@MainActor
final class PinnedTextManager {
    static let shared = PinnedTextManager(dependencies: .live)

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "PinnedTextManager")
    private let dependencies: PinnedTextManagerDependencies

    private let maxContentLength = 10_000
    private(set) var items: [PinnedTextItem] = []
    private var windows: [UUID: NSPanel] = [:]

    var windowFactory: ((PinnedTextItem) -> NSPanel)?

    init(dependencies: PinnedTextManagerDependencies) {
        self.dependencies = dependencies
    }

    private var storageRootDirectory: URL {
        let dir = dependencies.storageRootDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var storageURL: URL {
        storageRootDirectory.appendingPathComponent("pinned_text_items.json")
    }

    @discardableResult
    func createFromClipboard() -> PinnedTextItem? {
        guard let rawText = dependencies.pasteboardText()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawText.isEmpty else {
            dependencies.beep()
            logger.warning("📌 [PinnedTextManager] Clipboard is empty or missing text")
            return nil
        }

        let text: String
        if rawText.count > maxContentLength {
            text = String(rawText.prefix(maxContentLength))
            logger.info("📌 [PinnedTextManager] Clipboard text truncated to \(self.maxContentLength, privacy: .public) chars")
        } else {
            text = rawText
        }

        return createFromText(text, source: .clipboard)
    }

    @discardableResult
    func createFromText(_ text: String, source: PinnedTextSource) -> PinnedTextItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dependencies.beep()
            logger.warning("📌 [PinnedTextManager] Refusing to create empty pinned text item")
            return nil
        }

        let screen = screenForCreation()
        let frame = makeInitialFrame(for: trimmed, on: screen)
        let item = PinnedTextItem(
            text: trimmed,
            frame: frame,
            opacity: 1.0,
            zoomLevel: 1.0,
            isPinned: true,
            isLocked: false,
            screenLocalizedName: screen?.localizedName,
            source: source
        )

        items.append(item)
        showWindow(for: item)
        saveAll()

        logger.info("📌 [PinnedTextManager] Created pinned text item \(item.id.uuidString, privacy: .public)")
        return item
    }

    func pin(_ item: PinnedTextItem) {
        item.isPinned = true
        if let window = windows[item.id], let screen = window.screen ?? NSScreen.main {
            item.screenLocalizedName = screen.localizedName
        }
        updateWindowBehavior(for: item)
        saveAll()
    }

    func unpin(_ item: PinnedTextItem) {
        item.isPinned = false
        updateWindowBehavior(for: item)
        saveAll()
    }

    func lock(_ item: PinnedTextItem) {
        item.isLocked = true
        updateWindowBehavior(for: item)
        saveAll()
    }

    func unlock(_ item: PinnedTextItem) {
        item.isLocked = false
        updateWindowBehavior(for: item)
        saveAll()
    }

    func mark(_ item: PinnedTextItem) {
        item.isMarked = true
        if !item.isPinned {
            pin(item)
        } else {
            updateWindowBehavior(for: item)
            saveAll()
        }
    }

    func unmark(_ item: PinnedTextItem) {
        item.isMarked = false
        updateWindowBehavior(for: item)
        saveAll()
    }

    func close(_ item: PinnedTextItem) {
        if let window = windows[item.id] {
            window.orderOut(nil)
            window.close()
            windows.removeValue(forKey: item.id)
        }

        items.removeAll { $0.id == item.id }
        saveAll()
        logger.info("📌 [PinnedTextManager] Closed item \(item.id.uuidString, privacy: .public)")
    }

    func updateFrame(_ frame: CGRect, for item: PinnedTextItem) {
        item.frame = frame
        saveAll()
    }

    func saveAll() {
        let pinnedItems = items.filter(\.isPinned)

        do {
            let data = try JSONEncoder().encode(pinnedItems)
            try data.write(to: storageURL)
            logger.info("💾 [PinnedTextManager] Saved \(pinnedItems.count, privacy: .public) pinned text items")
        } catch {
            logger.error("❌ [PinnedTextManager] Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func restoreAll() async {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.info("📂 [PinnedTextManager] No pinned text items to restore")
            return
        }

        let savedItems: [PinnedTextItem]
        do {
            let restoreURL = storageURL
            savedItems = try await runPinnedTextManagerDetachedThrowing {
                let data = try Data(contentsOf: restoreURL)
                return try JSONDecoder().decode([PinnedTextItem].self, from: data)
            }
        } catch {
            logger.error("❌ [PinnedTextManager] Restore failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        for item in savedItems {
            adjustFrameToScreen(for: item)
            items.append(item)
            showWindow(for: item)
            await Task.yield()
        }

        logger.info("✅ [PinnedTextManager] Restored \(savedItems.count, privacy: .public) pinned text items")
    }

    func stop() {
        for window in windows.values {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        saveAll()
        windowFactory = nil
    }

    private func showWindow(for item: PinnedTextItem) {
        guard let factory = windowFactory else {
            logger.error("❌ [PinnedTextManager] windowFactory not set")
            return
        }

        let window = factory(item)
        windows[item.id] = window
        updateWindowBehavior(for: item)
        window.setFrame(item.frame, display: true)
        window.orderFront(nil)
    }

    private func updateWindowBehavior(for item: PinnedTextItem) {
        guard let panel = windows[item.id] else { return }

        panel.alphaValue = item.opacity

        if let window = panel as? PinnedTextWindow {
            window.updatePinnedState()
            window.updateLockState()
            window.refreshToolbarState()
        } else if item.isPinned {
            panel.collectionBehavior = []
        } else {
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        }
    }

    private func screenForCreation() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func makeInitialFrame(for text: String, on screen: NSScreen?) -> CGRect {
        let size = PinnedTextMarkdownRenderer.preferredWindowSize(
            text: text,
            zoomLevel: 1.0
        )

        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.midY - size.height / 2
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    private func adjustFrameToScreen(for item: PinnedTextItem) {
        guard let savedScreenName = item.screenLocalizedName else {
            if let mainScreen = NSScreen.main {
                item.frame = adjustFrameToFit(item.frame, in: mainScreen.visibleFrame)
            }
            return
        }

        let targetScreen = NSScreen.screens.first { $0.localizedName == savedScreenName } ?? NSScreen.main
        guard let screen = targetScreen else { return }
        item.frame = adjustFrameToFit(item.frame, in: screen.visibleFrame)
    }

    private func adjustFrameToFit(_ frame: CGRect, in visibleFrame: CGRect) -> CGRect {
        var adjusted = frame
        adjusted.size.width = min(adjusted.size.width, visibleFrame.width)
        adjusted.size.height = min(adjusted.size.height, visibleFrame.height)

        if adjusted.minX < visibleFrame.minX {
            adjusted.origin.x = visibleFrame.minX
        }
        if adjusted.maxX > visibleFrame.maxX {
            adjusted.origin.x = visibleFrame.maxX - adjusted.width
        }
        if adjusted.minY < visibleFrame.minY {
            adjusted.origin.y = visibleFrame.minY
        }
        if adjusted.maxY > visibleFrame.maxY {
            adjusted.origin.y = visibleFrame.maxY - adjusted.height
        }

        return adjusted
    }
}
