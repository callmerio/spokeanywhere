import SwiftUI
import WebKit

/// 可选择文本的 WKWebView
/// - 普通滚动事件传递给外层 ScrollView
/// - 保持文本选择功能
/// - 支持 Cmd+C 复制
class SelectableWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        // 将滚动事件传递给父视图（外层 SwiftUI ScrollView）
        nextResponder?.scrollWheel(with: event)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    /// 处理 Cmd+C 复制快捷键
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "c":
                // 通过 JavaScript 获取选中文本并复制到剪贴板
                evaluateJavaScript("window.getSelection().toString()") { result, _ in
                    if let text = result as? String, !text.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
                return true
            case "a":
                // 全选
                evaluateJavaScript("document.execCommand('selectAll')") { _, _ in }
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let text: String
    @Binding var dynamicHeight: CGFloat
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setValue(false, forKey: "drawsBackground")
        
        // Add script message handler
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightHandler")
        config.userContentController = userContentController
        
        // 使用 SelectableWebView：支持文本选择，滚动事件传递给外层
        let webView = SelectableWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(from: text)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MarkdownWebView
        
        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = height
                    }
                }
            }
        }
        
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = height
                }
            }
        }
    }
    
    private static let htmlTemplate = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <!-- KaTeX CSS -->
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <!-- Highlight.js CSS (GitHub Dark theme) -->
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github-dark.min.css">
            <style>
                html, body {
                    background-color: transparent;
                    color: rgba(255, 255, 255, 0.9);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    margin: 0;
                    padding: 0;
                    overflow-y: auto;
                    overflow-x: hidden;
                    -webkit-user-select: text;
                    user-select: text;
                    cursor: text;
                }
                ::selection {
                    background: rgba(74, 158, 255, 0.3);
                }
                ::-webkit-scrollbar { 
                    width: 0px;
                    height: 0px;
                    display: none;
                }
                /* Markdown Styles */
                h1, h2, h3, h4, h5, h6 {
                    color: #fff;
                    margin-top: 16px;
                    margin-bottom: 8px;
                    font-weight: 600;
                }
                h1 { font-size: 1.5em; }
                h2 { font-size: 1.3em; }
                h3 { font-size: 1.15em; }
                p { margin-bottom: 12px; }
                strong { font-weight: 600; color: #fff; }
                em { font-style: italic; }
                del { text-decoration: line-through; opacity: 0.7; }
                code {
                    background: rgba(255,255,255,0.1);
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: "SF Mono", "Menlo", "Monaco", monospace;
                    font-size: 0.9em;
                    color: #ff9f9f;
                }
                pre {
                    background: rgba(0,0,0,0.4);
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin-bottom: 12px;
                }
                pre code {
                    background: none;
                    padding: 0;
                    color: #e0e0e0;
                    font-size: 13px;
                }
                blockquote {
                    border-left: 3px solid #4a9eff;
                    margin: 0 0 12px 0;
                    padding-left: 12px;
                    color: rgba(255,255,255,0.7);
                }
                a { color: #4a9eff; text-decoration: none; }
                a:hover { text-decoration: underline; }
                img { max-width: 100%; border-radius: 6px; }
                ul, ol { padding-left: 20px; margin-bottom: 12px; }
                li { margin-bottom: 4px; }
                /* Task list */
                li input[type="checkbox"] {
                    margin-right: 6px;
                    accent-color: #4a9eff;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin-bottom: 12px;
                }
                th, td {
                    border: 1px solid rgba(255,255,255,0.15);
                    padding: 8px;
                    text-align: left;
                }
                th {
                    background: rgba(255,255,255,0.08);
                    font-weight: 600;
                }
                hr {
                    border: none;
                    border-top: 1px solid rgba(255,255,255,0.15);
                    margin: 16px 0;
                }
                /* KaTeX Math */
                .katex { font-size: 1.05em; }
                .katex-display {
                    margin: 12px 0;
                    overflow-x: auto;
                    overflow-y: hidden;
                }
                /* Mermaid */
                .mermaid { margin-bottom: 12px; text-align: center; }
                /* Graphviz */
                .graphviz { margin-bottom: 12px; text-align: center; }
                .graphviz svg { max-width: 100%; }
            </style>
            <!-- KaTeX JS -->
            <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
            <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>
            <!-- Marked -->
            <script src="https://cdn.jsdelivr.net/npm/marked@12.0.0/marked.min.js"></script>
            <!-- Highlight.js -->
            <script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>
            <!-- Mermaid -->
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
            <!-- Viz.js -->
            <script src="https://cdnjs.cloudflare.com/ajax/libs/viz.js/2.1.2/viz.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/viz.js/2.1.2/full.render.js"></script>
        </head>
        <body>
            <div id="content"></div>
            
            <script>
                // Wait for all scripts to load
                document.addEventListener('DOMContentLoaded', function() {
                    initializeRendering();
                });
                
                // Fallback: if DOMContentLoaded already fired
                if (document.readyState !== 'loading') {
                    setTimeout(initializeRendering, 50);
                }
                
                function initializeRendering() {
                    // Initialize Mermaid
                    mermaid.initialize({
                        startOnLoad: false,
                        theme: 'dark',
                        securityLevel: 'loose',
                        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif'
                    });
                    
                    const markdown = `{{MARKDOWN}}`;
                    
                    // Configure marked with custom renderer
                    const renderer = new marked.Renderer();
                    
                    // Custom code block handler
                    renderer.code = function(codeObj) {
                        const code = (typeof codeObj === 'string') ? codeObj : (codeObj.text || '');
                        const language = (typeof codeObj === 'string') ? arguments[1] : (codeObj.lang || '');
                        
                        if (language === 'mermaid') {
                            return '<div class="mermaid">' + code + '</div>';
                        } else if (language === 'graphviz' || language === 'dot') {
                            return '<div class="graphviz">' + code + '</div>';
                        } else if (language === 'html') {
                            return '<div class="html-preview">' + code + '</div>';
                        }
                        
                        // Use highlight.js for syntax highlighting
                        const escaped = code.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                        const langClass = language ? 'language-' + language : '';
                        return '<pre><code class="hljs ' + langClass + '">' + escaped + '</code></pre>';
                    };
                    
                    // Configure marked
                    marked.use({
                        renderer: renderer,
                        gfm: true,           // GitHub Flavored Markdown
                        breaks: false,       // Don't convert \\n to <br>
                        pedantic: false,
                        smartypants: false   // Don't convert quotes/dashes
                    });
                    
                    // Render Markdown
                    const contentEl = document.getElementById('content');
                    contentEl.innerHTML = marked.parse(markdown);
                    
                    // Apply syntax highlighting
                    document.querySelectorAll('pre code.hljs').forEach(block => {
                        try {
                            hljs.highlightElement(block);
                        } catch (e) {
                            console.warn('Highlight error:', e);
                        }
                    });
                    
                    // Render KaTeX math
                    if (typeof renderMathInElement !== 'undefined') {
                        renderMathInElement(contentEl, {
                            delimiters: [
                                {left: '$$', right: '$$', display: true},
                                {left: '$', right: '$', display: false},
                                {left: '\\\\[', right: '\\\\]', display: true},
                                {left: '\\\\(', right: '\\\\)', display: false}
                            ],
                            throwOnError: false,
                            errorColor: '#ff6b6b',
                            trust: true
                        });
                    }
                    
                    // Render Mermaid diagrams
                    const mermaidNodes = document.querySelectorAll('.mermaid');
                    if (mermaidNodes.length > 0) {
                        mermaid.run({ nodes: mermaidNodes }).then(updateHeight).catch(e => {
                            console.warn('Mermaid error:', e);
                            updateHeight();
                        });
                    }
                    
                    // Render Graphviz diagrams
                    const viz = new Viz();
                    const graphvizNodes = document.querySelectorAll('.graphviz');
                    if (graphvizNodes.length > 0) {
                        Array.from(graphvizNodes).forEach(el => {
                            viz.renderSVGElement(el.textContent)
                                .then(element => {
                                    el.innerHTML = "";
                                    el.appendChild(element);
                                    updateHeight();
                                })
                                .catch(error => {
                                    console.error('Graphviz error:', error);
                                    el.innerHTML = '<pre style="color:#ff6b6b;">Graphviz Error: ' + error + '</pre>';
                                    updateHeight();
                                });
                        });
                    }
                    
                    // Initial height update
                    updateHeight();
                    
                    // MutationObserver for dynamic content
                    const observer = new MutationObserver(() => updateHeight());
                    observer.observe(contentEl, { 
                        childList: true, 
                        subtree: true,
                        characterData: true
                    });
                    
                    // Update on images load
                    document.querySelectorAll('img').forEach(img => {
                        img.onload = updateHeight;
                    });
                }
                
                function updateHeight() {
                    setTimeout(() => {
                        window.webkit.messageHandlers.heightHandler.postMessage(document.body.scrollHeight);
                    }, 100);
                }
            </script>
        </body>
        </html>
        """
    
    private func generateHTML(from markdown: String) -> String {
        // 只转义 JS 模板字符串需要的字符：反斜杠和反引号
        // 注意：不要转义 $ 符号，KaTeX 需要它来识别数学公式
        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        
        return Self.htmlTemplate.replacingOccurrences(
            of: "{{MARKDOWN}}",
            with: escapedMarkdown
        )
    }
}
