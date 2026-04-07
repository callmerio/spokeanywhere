import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionTranscriber 测试")
@MainActor
struct LiveCaptionTranscriberTests {

    @Test("取消错误不会向外派发 onError")
    func cancelledErrorIsIgnored() {
        let transcriber = LiveCaptionTranscriber()
        var receivedError = false
        transcriber.onError = { _ in receivedError = true }

        transcriber.handleRecognitionResult(
            nil,
            error: NSError(domain: "test", code: 203, userInfo: nil)
        )

        #expect(!receivedError)
    }

    @Test("普通错误会向外派发 onError")
    func nonCancelledErrorIsForwarded() {
        let transcriber = LiveCaptionTranscriber()
        var receivedCode: Int?
        transcriber.onError = { error in
            receivedCode = (error as NSError).code
        }

        transcriber.handleRecognitionResult(
            nil,
            error: NSError(domain: "test", code: 500, userInfo: nil)
        )

        #expect(receivedCode == 500)
    }
}
