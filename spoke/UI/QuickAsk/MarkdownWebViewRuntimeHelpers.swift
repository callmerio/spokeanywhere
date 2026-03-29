import Foundation

func runMarkdownWebViewOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(operation)
}
