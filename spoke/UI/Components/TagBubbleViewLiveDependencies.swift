import SwiftUI

@MainActor
extension TagBubbleDependencies {
    static let live = makeLive(
        tagLibrary: currentServiceContainer().tagLibrary,
        messagePanelState: currentServiceContainer().messagePanelState
    )
}
