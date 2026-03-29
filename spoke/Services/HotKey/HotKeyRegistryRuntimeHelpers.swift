import Foundation

func runHotKeyRegistryObserver(
    _ registry: HotKeyRegistry?,
    type: HotKeyType,
    logMessage: String
) {
    runtimeRunOnMain(owner: registry) { registry in
        registry.reloadBinding(for: type)
        registry.logReload(logMessage)
    }
}
