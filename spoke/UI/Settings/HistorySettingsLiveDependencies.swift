import AppKit
import Foundation

@MainActor
extension HistorySettingsDependencies {
    static let live = HistorySettingsDependencies(
        historyManager: .shared,
        llmSettings: .shared,
        audioPlayer: .shared,
        copyText: { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    )
}

