import AppKit

func messagePanelSourceApplicationURL(bundleId: String) -> URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
}

func messagePanelSourceApplicationIcon(path: String) -> NSImage {
    NSWorkspace.shared.icon(forFile: path)
}

func messagePanelSourceFrontmostApplication() -> NSRunningApplication? {
    NSWorkspace.shared.frontmostApplication
}
