import Foundation

func runAttachmentTask(
    _ operation: @escaping @Sendable () async -> Void
) {
    runtimeRunAsync(operation)
}

func runAttachmentOnMain(
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(operation)
}

func runAttachmentOnMain<Owner: AnyObject>(
    owner: Owner?,
    _ action: @escaping @MainActor (Owner) -> Void
) {
    runtimeRunOnMain(owner: owner, action)
}

func runAttachmentDetached<Value: Sendable>(
    priority: TaskPriority = .userInitiated,
    _ operation: @escaping @Sendable () -> Value
) async -> Value {
    await Task.detached(priority: priority) {
        operation()
    }.value
}

@MainActor
func postAttachmentThumbnailUpdated(
    id: UUID,
    notificationCenter: NotificationCenter = .default
) {
    notificationCenter.post(
        name: .attachmentThumbnailUpdated,
        object: nil,
        userInfo: ["id": id]
    )
}
