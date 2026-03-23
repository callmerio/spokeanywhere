import AppKit

func messagePanelSourceAppIcon(bundleId: String) -> NSImage? {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
        return nil
    }
    return NSWorkspace.shared.icon(forFile: appURL.path)
}

func messagePanelFrontmostApplication() -> NSRunningApplication? {
    NSWorkspace.shared.frontmostApplication
}

