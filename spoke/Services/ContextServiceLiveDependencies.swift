import AppKit

@MainActor
extension ContextServiceDependencies {
    static let live = ContextServiceDependencies(
        notificationCenter: NSWorkspace.shared.notificationCenter,
        frontmostApplication: { NSWorkspace.shared.frontmostApplication }
    )
}
