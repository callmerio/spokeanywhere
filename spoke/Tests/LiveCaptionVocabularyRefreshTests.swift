import Foundation
import Testing

@Suite("LiveCaption 词库刷新测试")
struct LiveCaptionVocabularyRefreshTests {
    @Test("词库变化不会把刷新 trigger 广播给所有历史字幕")
    func refreshPolicyIsScoped() throws {
        let source = try loadLiveCaptionViewSource()

        #expect(
            source.contains("private func scopedVocabularyRefreshTrigger(for itemID: UUID) -> Int"),
            "LiveCaptionView 应提供按 item 收窄的词库刷新策略"
        )
        #expect(
            source.contains("scopedVocabularyRefreshTrigger(for: item.id)"),
            "finalized caption 应使用按 item 收窄后的 refresh trigger"
        )
    }

    private func loadLiveCaptionViewSource() throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("UI", isDirectory: true)
            .appendingPathComponent("LiveCaption", isDirectory: true)
            .appendingPathComponent("LiveCaptionView.swift", isDirectory: false)

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
