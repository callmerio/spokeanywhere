import SwiftUI
import WebKit

/// 禁用滚动的 WKWebView，让事件穿透到外层 ScrollView
class NonScrollableWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        // 不处理滚动事件，让它传递给父视图
        nextResponder?.scrollWheel(with: event)
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
        
        let webView = NonScrollableWebView(frame: .zero, configuration: config)
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
            // Initial height check
            webView.evaluateJavaScript("document.body.scrollHeight") { (result, error) in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = height
                    }
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = height
                }
            }
        }
    }
    
    private func generateHTML(from markdown: String) -> String {
        // Escaping markdown for JS string
        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                html, body {
                    background-color: transparent;
                    color: rgba(255, 255, 255, 0.9);
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    margin: 0;
                    padding: 0;
                    overflow-y: auto; /* 允许垂直滚动 */
                    overflow-x: hidden; /* 禁用水平滚动 */
                }
                /* 隐藏滚动条但允许滚动 */
                ::-webkit-scrollbar { 
                    width: 0px;
                    height: 0px;
                    display: none;
                }
                /* Markdown Styles */
                h1, h2, h3, h4, h5, h6 { color: #fff; margin-top: 16px; margin-bottom: 8px; font-weight: 600; }
                p { margin-bottom: 12px; }
                code { background: rgba(255,255,255,0.15); padding: 2px 4px; border-radius: 4px; font-family: "Menlo", monospace; font-size: 0.9em; color: #ff9f9f; }
                pre { background: rgba(0,0,0,0.3); padding: 12px; border-radius: 8px; overflow-x: auto; margin-bottom: 12px; }
                pre code { background: none; padding: 0; color: #e0e0e0; }
                blockquote { border-left: 3px solid #4a9eff; margin: 0 0 12px 0; padding-left: 12px; color: #a0a0a0; }
                a { color: #4a9eff; text-decoration: none; }
                a:hover { text-decoration: underline; }
                img { max-width: 100%; border-radius: 6px; }
                ul, ol { padding-left: 20px; margin-bottom: 12px; }
                li { margin-bottom: 4px; }
                table { border-collapse: collapse; width: 100%; margin-bottom: 12px; }
                th, td { border: 1px solid rgba(255,255,255,0.1); padding: 8px; text-align: left; }
                th { background: rgba(255,255,255,0.05); font-weight: 600; }
                hr { border: none; border-top: 1px solid rgba(255,255,255,0.1); margin: 16px 0; }
                
                /* Mermaid */
                .mermaid { margin-bottom: 12px; text-align: center; }
            </style>
            <!-- Marked -->
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
            <!-- Mermaid -->
            <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
            <!-- Viz.js -->
            <script src="https://cdnjs.cloudflare.com/ajax/libs/viz.js/2.1.2/viz.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/viz.js/2.1.2/full.render.js"></script>
        </head>
        <body>
            <div id="content"></div>
            
            <script>
                // Initialize Mermaid
                mermaid.initialize({
                    startOnLoad: false,
                    theme: 'dark',
                    securityLevel: 'loose',
                    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif'
                });
                
                const markdown = `\(escapedMarkdown)`;
                
                // Custom Renderer
                const renderer = new marked.Renderer();
                // marked v5+ 传入对象 { text, lang, escaped }，兼容新旧版本
                renderer.code = function(codeObj) {
                    const code = (typeof codeObj === 'string') ? codeObj : (codeObj.text || '');
                    const language = (typeof codeObj === 'string') ? arguments[1] : (codeObj.lang || '');
                    
                    // 转义 HTML 防止 XSS
                    const escaped = code.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                    
                    if (language === 'mermaid') {
                        return '<div class="mermaid">' + code + '</div>';
                    } else if (language === 'graphviz' || language === 'dot') {
                        return '<div class="graphviz">' + code + '</div>';
                    } else if (language === 'html') {
                        return '<div class="html-preview">' + code + '</div>';
                    }
                    return '<pre><code class="language-' + language + '">' + escaped + '</code></pre>';
                };
                
                // Render Markdown
                document.getElementById('content').innerHTML = marked.parse(markdown, { renderer: renderer });
                
                // Update Height Helper
                function updateHeight() {
                    setTimeout(() => {
                        window.webkit.messageHandlers.heightHandler.postMessage(document.body.scrollHeight);
                    }, 100);
                }
                
                // Render Mermaid
                mermaid.run({
                    nodes: document.querySelectorAll('.mermaid')
                }).then(updateHeight);
                
                // Render Graphviz
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
                                console.error(error);
                                el.innerHTML = '<pre style="color:red;">Graphviz Error: ' + error + '</pre>';
                                updateHeight();
                            });
                    });
                }
                
                // Initial height check + observer for dynamic content
                updateHeight();
                
                // MutationObserver to watch for content changes
                const observer = new MutationObserver(() => updateHeight());
                observer.observe(document.getElementById('content'), { 
                    childList: true, 
                    subtree: true,
                    characterData: true
                });
                
                // Also update on images load
                document.querySelectorAll('img').forEach(img => {
                    img.onload = updateHeight;
                });
            </script>
        </body>
        </html>
        """
    }
}
