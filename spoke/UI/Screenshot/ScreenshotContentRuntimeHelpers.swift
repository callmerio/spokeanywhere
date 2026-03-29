import AppKit
import Foundation

typealias ScreenshotAsyncTask = Task<Void, Never>

func runScreenshotTask(
    _ operation: @escaping @Sendable () async -> Void
) {
    runtimeRunAsync(operation)
}

func makeScreenshotAsyncTask(
    _ operation: @escaping @Sendable () async -> Void
) -> ScreenshotAsyncTask {
    runtimeMakeTask(operation)
}

func runScreenshotDetached<Value: Sendable>(
    priority: TaskPriority = .userInitiated,
    _ operation: @escaping @Sendable () async -> Value
) async -> Value {
    await runtimeRunDetachedAsync(priority: priority, operation)
}

func scheduleScreenshotWorkItem(
    after seconds: Double,
    _ workItem: DispatchWorkItem
) {
    runtimeRunOnMain(after: seconds) {
        guard !workItem.isCancelled else { return }
        workItem.perform()
    }
}

func scheduleScreenshotMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}

func runScreenshotEnhancedCopy(
    original: NSImage,
    targetSize: CGSize,
    enhance: @escaping @MainActor (NSImage, CGSize) -> NSImage?,
    complete: @escaping @MainActor (NSImage?) -> Void
) {
    runtimeRunOnMain {
        let enhanced = enhance(original, targetSize)
        complete(enhanced)
    }
}

func runScreenshotLegacyOCR(
    cgImage: CGImage,
    extractText: @escaping (CGImage) async -> String,
    complete: @escaping @MainActor (String) -> Void
) {
    runtimeRunAsync {
        let text = await runtimeRunDetachedAsync {
            await extractText(cgImage)
        }
        runtimeRunOnMain {
            complete(text)
        }
    }
}
