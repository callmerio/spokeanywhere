import AppKit
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("Attachment 缩略图更新测试", .serialized)
@MainActor
struct AttachmentThumbnailUpdateTests {

    @Test("QuickAskState 通过 ID-only 通知从 AttachmentManager 拉取最新缩略图")
    func quickAskStateRefreshesAttachmentByID() async throws {
        let manager = AttachmentManager.makePreview()
        let state = QuickAskState(
            attachmentManager: manager,
            dependencies: QuickAskStateDependencies(notificationCenter: .default)
        )
        let image = makeImage(size: NSSize(width: 120, height: 80))

        state.addImage(image)

        try await waitUntil {
            state.attachments.first?.thumbnail != nil
        }

        #expect(state.attachments.count == 1)
        #expect(state.attachments.first?.thumbnail != nil)
        #expect(manager.attachment(for: state.attachments[0].id)?.thumbnail != nil)
    }

    private func makeImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private func waitUntil(
        attempts: Int = 100,
        pollNs: UInt64 = 20_000_000,
        condition: @escaping @MainActor @Sendable () -> Bool
    ) async throws {
        for _ in 0..<attempts {
            if await MainActor.run(body: condition) {
                return
            }
            try await Task.sleep(nanoseconds: pollNs)
        }

        throw CancellationError()
    }
}
