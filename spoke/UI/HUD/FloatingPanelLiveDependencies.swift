import Foundation

func postFloatingPanelQuickAskCancel() {
    NotificationCenter.default.post(name: .quickAskCancelRequested, object: nil)
}
