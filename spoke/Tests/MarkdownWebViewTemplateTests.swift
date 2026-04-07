import Testing
@testable import SpokenAnyWhere

@Suite("MarkdownWebView 模板测试")
struct MarkdownWebViewTemplateTests {

    @Test("HTML 模板不应再包含远程 CDN URL")
    func templateContainsNoRemoteCDNs() {
        let html = MarkdownWebView.generateHTML(from: "# Hello")

        #expect(!html.contains("https://"))
        #expect(!html.contains("http://"))
        #expect(html.contains("marked.min.js"))
        #expect(html.contains("highlight.min.js"))
        #expect(html.contains("katex/katex.min.css"))
    }
}
