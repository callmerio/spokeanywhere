import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("CaptionLineBuffer 测试")
@MainActor
struct CaptionLineBufferTests {

    @Test("addFinalized 会追加条目并继承 pendingTranslation")
    func addFinalizedInheritsPendingTranslation() {
        let buffer = CaptionLineBuffer()
        buffer.updateVolatile(text: "pending")
        buffer.updatePendingTranslation("待翻译", version: buffer.currentVolatileVersion)

        let id = buffer.addFinalized(text: "final text")

        #expect(id != nil)
        #expect(buffer.items.count == 1)
        #expect(buffer.items.first?.original == "final text")
        #expect(buffer.items.first?.translation == "待翻译")
    }

    @Test("clearPending 会清空流式状态")
    func clearPendingResetsVolatileState() {
        let buffer = CaptionLineBuffer()
        buffer.updateVolatile(text: "pending")
        buffer.updatePendingTranslation("译文", version: buffer.currentVolatileVersion)

        buffer.clearPending()

        #expect(buffer.pendingText.isEmpty)
        #expect(buffer.pendingTranslation.isEmpty)
        #expect(buffer.displayPendingText.isEmpty)
    }
}
