import Testing
@testable import SpokenAnyWhere

@Suite("PromptRenderer 测试")
struct PromptRendererTests {

    @Test("renderBulletSection 会过滤空白项并保留标题")
    func bulletSectionFiltersEmptyItems() {
        let rendered = PromptRenderer.renderBulletSection(
            title: "上下文",
            intro: "请参考：",
            items: ["alpha", "  ", "beta"]
        )

        #expect(rendered?.contains("上下文") == true)
        #expect(rendered?.contains("- alpha") == true)
        #expect(rendered?.contains("- beta") == true)
        #expect(rendered?.contains("-   ") == false)
    }

    @Test("replacingPlaceholders 会替换并裁剪结果")
    func replacingPlaceholdersWorks() {
        let rendered = PromptRenderer.replacingPlaceholders(
            in: "Hello {{name}}  ",
            replacements: [("{{name}}", "MM")]
        )

        #expect(rendered == "Hello MM")
    }
}
