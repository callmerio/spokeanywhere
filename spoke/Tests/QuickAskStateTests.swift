import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("QuickAskState 测试")
@MainActor
struct QuickAskStateTests {

    @Test("start/reset/restartRecording 会正确切换状态")
    func lifecycleTransitions() {
        let state = QuickAskState(
            attachmentManager: AttachmentManager.makePreview(),
            dependencies: QuickAskStateDependencies(notificationCenter: NotificationCenter())
        )

        state.startSession(targetApp: nil)
        #expect(state.phase == .recording)

        state.restartRecording()
        #expect(state.phase == .recording)

        state.reset()
        #expect(state.phase == .idle)
        #expect(state.attachments.isEmpty)
    }

    @Test("add/removeAttachment 会更新附件列表")
    func attachmentMutation() {
        let state = QuickAskState(
            attachmentManager: AttachmentManager.makePreview(),
            dependencies: QuickAskStateDependencies(notificationCenter: NotificationCenter())
        )
        let image = NSImage(size: NSSize(width: 8, height: 8))
        let attachment = Attachment.image(image, nil, UUID())

        state.addAttachment(attachment)
        #expect(state.attachments.count == 1)

        state.removeAttachment(attachment.id)
        #expect(state.attachments.isEmpty)
    }
}
