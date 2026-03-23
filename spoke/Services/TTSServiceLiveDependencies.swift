import Foundation

@MainActor
extension TTSServiceDependencies {
    static let live = TTSServiceDependencies(
        settings: .shared
    )
}

