import Foundation

@MainActor
struct BatchImportSheetDependencies {
    let dictionaryService: DictionaryService
    let scheduleDismiss: (_ after: Double, _ operation: @escaping @MainActor () -> Void) -> Void
}

@MainActor
extension BatchImportSheetDependencies {
    static let live = Self(
        dictionaryService: currentServiceContainer().dictionaryService,
        scheduleDismiss: { seconds, operation in
            runtimeRunOnMain(after: seconds, operation)
        }
    )
}
