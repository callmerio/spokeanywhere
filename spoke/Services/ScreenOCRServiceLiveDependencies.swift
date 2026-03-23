import AppKit

@MainActor
struct ScreenOCRServiceDependencies {
    let frontmostApplication: () -> NSRunningApplication?
}

@MainActor
extension ScreenOCRServiceDependencies {
    static let live = ScreenOCRServiceDependencies(
        frontmostApplication: { NSWorkspace.shared.frontmostApplication }
    )
}
