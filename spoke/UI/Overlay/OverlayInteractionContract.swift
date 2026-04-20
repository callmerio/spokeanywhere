import CoreGraphics

@MainActor
enum OverlayInteractionContract {
    static let minimumOpacity: Double = 0.05
    static let maximumOpacity: Double = 1.0
    static let horizontalOpacitySensitivity: CGFloat = 0.003

    enum MenuGroup: String, CaseIterable {
        case copy
        case pin
        case sourceSpecific
        case mark
        case close
    }
}
