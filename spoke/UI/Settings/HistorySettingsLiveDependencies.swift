import AppKit
import Foundation

@MainActor
extension HistorySettingsDependencies {
    static let live = HistorySettingsDependencies(
        historyManager: currentServiceContainer().historyManagerConcrete,
        llmSettings: currentServiceContainer().llmSettings,
        audioPlayer: currentServiceContainer().audioPlayerService,
        copyText: { text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    )
}
