import SwiftUI

@MainActor
extension TagBubbleDependencies {
    static let live = makeLive(
        tagLibrary: TagLibrary.shared,
        messagePanelState: MessagePanelState.shared
    )
}
