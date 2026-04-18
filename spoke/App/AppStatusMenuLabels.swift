import AppKit
import Carbon.HIToolbox
import Foundation

struct AppStatusMenuLabels {
    let recording: String
    let quickAsk: String

    static func make() -> Self {
        Self(
            recording: "录音",
            quickAsk: "Quick Ask"
        )
    }
}

struct AppStatusMenuTitleRuntime {
    func updateTitles(
        setRecordingTitle: (String) -> Void,
        setQuickAskTitle: (String) -> Void
    ) {
        let labels = AppStatusMenuLabels.make()
        setRecordingTitle(labels.recording)
        setQuickAskTitle(labels.quickAsk)
    }
}

struct AppStatusMenuShortcutDescriptor: Equatable {
    let keyEquivalent: String
    let modifierMask: NSEvent.ModifierFlags
}

enum AppStatusMenuShortcutRuntime {
    static func shortcut(
        keyCode: Int,
        modifiers: Int
    ) -> AppStatusMenuShortcutDescriptor? {
        guard let keyEquivalent = keyEquivalent(for: keyCode) else { return nil }
        return AppStatusMenuShortcutDescriptor(
            keyEquivalent: keyEquivalent,
            modifierMask: NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        )
    }

    private static func keyEquivalent(for keyCode: Int) -> String? {
        switch keyCode {
        case kVK_Space:
            return " "
        case kVK_Return:
            return "\r"
        case kVK_Tab:
            return "\t"
        default:
            guard let keyName = KeyComboFormatter.keyCodeToString(keyCode), keyName.count == 1 else {
                return nil
            }
            return keyName.lowercased()
        }
    }
}

struct AppStatusMenuShortcutObservation {
    let name: Notification.Name
    let handler: @MainActor (Notification) -> Void
}

struct AppStatusMenuShortcutObserverRuntime {
    @MainActor
    func makeObservations(
        onRefresh: @escaping @MainActor () -> Void
    ) -> [AppStatusMenuShortcutObservation] {
        [
            AppStatusMenuShortcutObservation(
                name: AppSettings.shortcutDidChangeNotification,
                handler: { _ in onRefresh() }
            ),
            AppStatusMenuShortcutObservation(
                name: AppSettings.quickAskShortcutDidChangeNotification,
                handler: { _ in onRefresh() }
            )
        ]
    }
}

@MainActor
struct AppStatusMenuCommandRuntime {
    let toggleRecording: () -> Void
    let triggerQuickAsk: () -> Void

    func toggleRecordingFromMenu() {
        toggleRecording()
    }

    func triggerQuickAskFromMenu() {
        triggerQuickAsk()
    }
}
