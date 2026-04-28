import Foundation
import Observation

@Observable
final class LiveCaptionHoverState {
    var isHovering = false
    var isCopyHovered = false
    var isExpandHovered = false
    var isCloseHovered = false
    var isCopied = false
}

@Observable
final class LiveCaptionScrollState {
    var isAtBottom = true
    var scrollTrigger = 0
    var appearedItemIDs: Set<UUID> = []
}

@Observable
final class LiveCaptionInteractionState {
    var isExpanded = false
    var isUserSelecting = false
    var vocabularyRefreshTrigger = 0
    var highlightedWord: String?
}
