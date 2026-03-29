import Foundation

func runFloatingHUDManagerOnMain(
    _ manager: FloatingHUDManager?,
    _ action: @escaping @MainActor (FloatingHUDManager) -> Void
) {
    runtimeRunOnMain(owner: manager, action)
}

func makeFloatingHUDHideTimer(
    delay: TimeInterval,
    owner: FloatingHUDManager
) -> Timer {
    runtimeMakeOwnedTimer(
        interval: delay,
        repeats: false,
        owner: owner
    ) { manager in
        manager.hide()
    }
}
