import AppKit
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
final class MarkdownMermaidStubHandler: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "bmuxLib",
              let body = message.body as? [String: Any],
              body["lib"] as? String == "mermaid" else { return }
        webView?.evaluateJavaScript(
            """
            window.mermaid = {
              initialize: function() {},
              render: function(id, src) {
                var isWide = String(src || '').indexOf('wideDiagram') !== -1;
                var width = isWide ? 1200 : 240;
                var height = isWide ? 600 : 120;
                return Promise.resolve({
                  svg: '<svg data-stub-mermaid="1" width="100%" style="max-width:' + width + 'px;" viewBox="0 0 ' + width + ' ' + height + '" xmlns="http://www.w3.org/2000/svg"><rect x="0" y="0" width="' + width + '" height="' + height + '" fill="#d73a49"></rect><text x="20" y="65" font-size="18" fill="#ffffff">Mermaid label</text></svg>'
                });
              }
            };
            if (window.__bmuxLibLoaded) { window.__bmuxLibLoaded('mermaid'); }
            """,
            completionHandler: nil
        )
    }
}
