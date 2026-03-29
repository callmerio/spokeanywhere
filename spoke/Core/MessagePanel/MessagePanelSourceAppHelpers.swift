import AppKit

func messagePanelSourceAppIcon(bundleId: String) -> NSImage? {
    guard let appURL = messagePanelSourceApplicationURL(bundleId: bundleId) else {
        return nil
    }
    return messagePanelSourceApplicationIcon(path: appURL.path)
}

func messagePanelFrontmostApplication() -> NSRunningApplication? {
    messagePanelSourceFrontmostApplication()
}
