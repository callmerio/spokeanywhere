import AppKit

@MainActor
final class PinnedTextActionBarView: NSView {
    private let item: PinnedTextItem
    private let dependencies: PinnedTextActionDependencies
    private var actionButtons: [ActionBarButton] = []

    private let buttonSize: CGFloat = 22
    private let buttonSpacing: CGFloat = 1

    init(
        item: PinnedTextItem,
        dependencies: PinnedTextActionDependencies
    ) {
        self.item = item
        self.dependencies = dependencies
        super.init(frame: .zero)

        wantsLayer = true
        alphaValue = 0.94
        setupButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupButtons() {
        let markButton = ActionBarButton(
            icon: item.isMarked ? "bookmark.fill" : "bookmark",
            activeColor: DesignTokens.Colors.NS.warning,
            isActive: item.isMarked
        ) { [weak self] in self?.toggleMark() }
        markButton.toolTip = item.isMarked ? "Unmark" : "Mark"

        let pinButton = ActionBarButton(
            icon: item.isPinned ? "pin.fill" : "pin",
            activeColor: DesignTokens.Colors.NS.warning,
            isActive: item.isPinned
        ) { [weak self] in self?.togglePin() }
        pinButton.toolTip = item.isPinned ? "Unpin" : "Pin to Space"

        let lockButton = ActionBarButton(
            icon: item.isLocked ? "lock.fill" : "lock",
            activeColor: DesignTokens.Colors.NS.accentInfo,
            isActive: item.isLocked
        ) { [weak self] in self?.toggleLock() }
        lockButton.toolTip = item.isLocked ? "Unlock" : "Lock"

        let closeButton = ActionBarButton(
            icon: "xmark",
            activeColor: DesignTokens.Colors.NS.error
        ) { [weak self] in self?.closeWindow() }
        closeButton.toolTip = "Close"

        actionButtons = [lockButton, markButton, pinButton, closeButton]

        for (index, button) in actionButtons.enumerated() {
            button.frame = CGRect(
                x: CGFloat(index) * (buttonSize + buttonSpacing),
                y: 0,
                width: buttonSize,
                height: buttonSize
            )
            addSubview(button)
        }
    }

    override var intrinsicContentSize: NSSize {
        let width = CGFloat(actionButtons.count) * buttonSize + CGFloat(actionButtons.count - 1) * buttonSpacing
        return NSSize(width: width, height: buttonSize)
    }

    func refreshButtons() {
        actionButtons[0].updateIcon(item.isLocked ? "lock.fill" : "lock")
        actionButtons[0].setActive(item.isLocked, animated: true)
        actionButtons[0].toolTip = item.isLocked ? "Unlock" : "Lock"

        actionButtons[1].updateIcon(item.isMarked ? "bookmark.fill" : "bookmark")
        actionButtons[1].setActive(item.isMarked, animated: true)
        actionButtons[1].toolTip = item.isMarked ? "Unmark" : "Mark"

        actionButtons[2].updateIcon(item.isPinned ? "pin.fill" : "pin")
        actionButtons[2].setActive(item.isPinned, animated: true)
        actionButtons[2].toolTip = item.isPinned ? "Unpin" : "Pin to Space"
    }

    private func togglePin() {
        dependencies.togglePin(item)
        dependencies.updateWindowCollectionBehavior(item.id)
        refreshButtons()
    }

    private func toggleLock() {
        dependencies.toggleLock(item)
        dependencies.updateWindowMovable(item.id)
        refreshButtons()
    }

    private func toggleMark() {
        dependencies.toggleMark(item)
        dependencies.updateWindowGlow(item.id)
        refreshButtons()
    }

    private func closeWindow() {
        dependencies.closeWindow(item)
    }
}
