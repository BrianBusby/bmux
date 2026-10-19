import AppKit
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Composes the maintained native rendering owner with deterministic Mermaid geometry.
@MainActor
final class MarkdownMermaidTestFixture {
    let webView: MarkdownWebView
    let coordinator = MarkdownWebRenderer.Coordinator()
    let renderer: MarkdownRenderTestFixture
    private let mermaidHandler = MarkdownMermaidStubHandler()
    private let snapshotTimeout: Duration

    init(snapshotTimeout: Duration = .seconds(10)) {
        self.snapshotTimeout = snapshotTimeout
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(mermaidHandler, name: "bmuxLib")
        webView = MarkdownWebView(frame: NSRect(x: 0, y: 0, width: 720, height: 480), configuration: configuration)
        mermaidHandler.webView = webView
        coordinator.webView = webView
        renderer = MarkdownRenderTestFixture(webView: webView)
    }

    func load() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bmux-mermaid-\(UUID().uuidString).md")
        try await renderer.loadShell(baseURL: url)
    }

    func close() {
        coordinator.close()
        mermaidHandler.webView = nil
        renderer.close()
    }

    func snapshot(expectedZoom: Double? = nil, minimumWidth: Double? = nil) async throws -> [String: Double] {
        // DOM rectangles are CSS units. Native pageZoom converts all geometry to view points.
        let scale = Double(webView.pageZoom)
        let zoomPredicate = expectedZoom.map { "Math.abs(value.zoom - \($0)) <= 0.001" } ?? "true"
        let widthPredicate = minimumWidth.map { "value.width * \(scale) >= \($0)" } ?? "value.width > 0"
        let json = try await renderer.observeDOM(
            snapshot: """
            (function() {
              var svg = document.querySelector('.bmux-mermaid svg');
              if (!svg) { return null; }
              var rect = svg.getBoundingClientRect();
              var container = svg.closest('.bmux-mermaid');
              var containerRect = container ? container.getBoundingClientRect() : null;
              var prose = document.querySelector('.markdown-body p');
              var proseRect = prose ? prose.getBoundingClientRect() : null;
              var zoom = Number(svg.getAttribute('data-bmux-mermaid-zoom') || '1');
              return {
                width: rect.width || 0,
                containerWidth: containerRect ? (containerRect.width || 0) : 0,
                leftOffset: containerRect ? ((rect.left || 0) - (containerRect.left || 0)) : 0,
                proseHeight: proseRect ? (proseRect.height || 0) : 0,
                zoom: Number.isFinite(zoom) ? zoom : 1
              };
            })();
            """,
            predicate: "value !== null && (\(zoomPredicate)) && (\(widthPredicate))",
            deadline: ContinuousClock.now.advanced(by: snapshotTimeout)
        )
        let raw = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        var snapshot: [String: Double] = [:]
        for (key, value) in raw {
            if let number = value as? NSNumber {
                snapshot[key] = number.doubleValue * (key == "zoom" ? 1 : scale)
            }
        }
        return snapshot
    }

    func exportedSnapshot() async throws -> [String: String] {
        let result = try await webView.evaluateJavaScript(
            """
            (function() {
              var wrapper = document.createElement('div');
              wrapper.innerHTML = window.__bmuxRenderedHTML();
              var svg = wrapper.querySelector('.bmux-mermaid svg');
              if (!svg) { return {}; }
              return {
                width: svg.style.width || '',
                height: svg.style.height || '',
                maxWidth: svg.style.maxWidth || '',
                hasBmuxData: Array.prototype.some.call(svg.attributes || [], function(attr) {
                  return String(attr.name || '').indexOf('data-bmux-') === 0;
                }) ? '1' : '0'
              };
            })();
            """
        )
        guard let raw = result as? [String: Any] else { return [:] }
        return raw.reduce(into: [String: String]()) { output, item in
            output[item.key] = item.value as? String
        }
    }
}
