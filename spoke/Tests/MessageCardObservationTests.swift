import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("MessageCard Observation 测试")
struct MessageCardObservationTests {

    @Test("MessageCard 可变属性更新后仍能正确编码解码")
    func mutationsRemainCodable() throws {
        let card = MessageCard(
            stage: .system("hello"),
            content: "raw content",
            metadata: ["source": "test"]
        )

        card.recordType = .todo
        card.summary = "summary"
        card.summaryStatus = .completed
        card.tagIds = [UUID()]

        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(MessageCard.self, from: data)

        #expect(decoded.recordType == .todo)
        #expect(decoded.summary == "summary")
        #expect(decoded.summaryStatus == .completed)
        #expect(decoded.metadata["source"] == "test")
        #expect(decoded.tagIds.count == 1)
    }
}
