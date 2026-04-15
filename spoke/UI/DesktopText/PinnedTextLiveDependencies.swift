import AppKit
import Foundation

@MainActor
extension PinnedTextActionDependencies {
    private static func pinnedTextWindow(for itemID: UUID) -> PinnedTextWindow? {
        NSApp.windows
            .compactMap { $0 as? PinnedTextWindow }
            .first(where: { $0.item.id == itemID })
    }

    private static func withWindow(
        _ itemID: UUID,
        perform update: (PinnedTextWindow) -> Void
    ) {
        guard let window = pinnedTextWindow(for: itemID) else {
            return
        }
        update(window)
    }

    static let live: PinnedTextActionDependencies = {
        let manager = currentServiceContainer().pinnedTextManager

        return PinnedTextActionDependencies(
            togglePin: { item in
                if item.isPinned {
                    manager.unpin(item)
                } else {
                    manager.pin(item)
                }
            },
            toggleLock: { item in
                if item.isLocked {
                    manager.unlock(item)
                } else {
                    manager.lock(item)
                }
            },
            toggleMark: { item in
                if item.isMarked {
                    manager.unmark(item)
                } else {
                    manager.mark(item)
                }
            },
            updateWindowCollectionBehavior: { itemID in
                withWindow(itemID) { window in
                    window.updatePinnedState()
                    window.updateGlow()
                    window.refreshToolbarState()
                }
            },
            updateWindowMovable: { itemID in
                withWindow(itemID) { window in
                    window.updateLockState()
                    window.updateGlow()
                    window.refreshToolbarState()
                }
            },
            updateWindowGlow: { itemID in
                withWindow(itemID) { window in
                    window.updateGlow()
                    window.refreshToolbarState()
                }
            },
            closeWindow: { item in
                manager.close(item)
            },
            saveWindowState: {
                manager.saveAll()
            }
        )
    }()
}
