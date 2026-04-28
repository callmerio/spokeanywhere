import Foundation
import Testing

@Suite("MessageCard 布局策略测试")
struct MessageCardLayoutPolicyTests {
    @Test("文本折叠与附件折叠应分离，避免短文本被强制撑高")
    func textCollapsePolicyIsSeparated() throws {
        let source = try loadSource(at: ["UI", "MessagePanel", "MessageCardView.swift"])

        #expect(
            source.contains("private var needsTextCollapse: Bool"),
            "MessageCardView 应显式区分文本折叠策略"
        )
        #expect(
            source.contains("needsTextCollapse && !isExpanded && !shouldShowSummary"),
            "固定文本高度和渐隐遮罩应仅在文本真的需要折叠时触发"
        )
    }

    private func loadSource(at components: [String]) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = components.reduce(projectRoot) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
