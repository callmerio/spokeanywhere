import Foundation

@MainActor
extension ClipboardHistoryDependencies {
    static let live = ClipboardHistoryDependencies(
        historyLimit: { AppSettings.shared.clipboardHistoryLimit }
    )
}
