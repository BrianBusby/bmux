import AppKit
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct MarkdownWindowRenderingTests {
    @Test
    func keepsVisibleHeadingPositionAfterContentUpdate() async throws {
        let frame = NSRect(x: 0, y: 0, width: 720, height: 360)
        let webView = WKWebView(frame: frame, configuration: WKWebViewConfiguration())
        let fixture = MarkdownRenderTestFixture(webView: webView)
        defer {
            fixture.close()
        }

        try await fixture.loadShell(baseURL: FileManager.default.temporaryDirectory.appendingPathComponent("scroll.md"))

        try await fixture.renderMarkdown(fixture.scrollSmokeMarkdown(extraBeforeSection20: false))
        let before = try await fixture.evaluateScrollSnapshot(
            """
            (function() {
              var scroller = document.scrollingElement || document.documentElement;
              var heading = document.getElementById('section-20');
              document.documentElement.style.scrollBehavior = 'auto';
              window.scrollTo(0, heading.offsetTop - 48);
              return {
                top: heading.getBoundingClientRect().top,
                y: window.scrollY || scroller.scrollTop,
                max: scroller.scrollHeight - scroller.clientHeight
              };
            })();
            """
        )

        #expect((before["max"] ?? 0) > (1_000))

        try await fixture.renderMarkdown(fixture.scrollSmokeMarkdown(extraBeforeSection20: true))
        let after = try await fixture.evaluateScrollSnapshot(
            """
            (function() {
              var scroller = document.scrollingElement || document.documentElement;
              var heading = document.getElementById('section-20');
              return {
                top: heading.getBoundingClientRect().top,
                y: window.scrollY || scroller.scrollTop,
                max: scroller.scrollHeight - scroller.clientHeight
              };
            })();
            """
        )

        #expect((after["max"] ?? 0) > (before["max"] ?? 0))
        #expect(abs((after["top"] ?? .greatestFiniteMagnitude) - (before["top"] ?? 0)) <= 6)
    }

    @Test
    func handlesLocalImageSources() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("bmux-markdown-image-\(UUID().uuidString)", isDirectory: true)
        let directoryURL = rootURL.appendingPathComponent("docs", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            do { try fileManager.removeItem(at: rootURL) }
            catch { Issue.record(error, "Could not remove owned Markdown image directory") }
        }

        let imageURL = directoryURL.appendingPathComponent("pixel.png")
        let outsideImageURL = rootURL.appendingPathComponent("outside.png")
        let markdownURL = directoryURL.appendingPathComponent("image.md")
        try MarkdownRenderTestFixture.onePixelPNG.write(to: imageURL)
        try MarkdownRenderTestFixture.onePixelPNG.write(to: outsideImageURL)
        try """
        ![Local pixel](pixel.png)
        ![Traversal pixel](../outside.png)
        ![Explicit file pixel](\(outsideImageURL.absoluteString))
        ![Root absolute pixel](\(outsideImageURL.path))
        """.write(to: markdownURL, atomically: true, encoding: .utf8)

        let frame = NSRect(x: 0, y: 0, width: 320, height: 240)
        let configuration = WKWebViewConfiguration()
        let coordinator = MarkdownWebRenderer.Coordinator()
        coordinator.filePath = markdownURL.path
        configuration.setURLSchemeHandler(coordinator, forURLScheme: MarkdownWebRenderer.localImageURLScheme)
        let webView = MarkdownWebView(frame: frame, configuration: configuration)
        coordinator.webView = webView
        let fixture = MarkdownRenderTestFixture(webView: webView)
        defer {
            coordinator.webView = nil
            coordinator.cancelLocalImageLoads()
            fixture.close()
        }

        try await fixture.loadShell(baseURL: markdownURL)

        try await fixture.renderMarkdown(
            """
            ![Local pixel](pixel.png)
            ![Traversal pixel](../outside.png)
            ![Explicit file pixel](\(outsideImageURL.absoluteString))
            ![Root absolute pixel](\(outsideImageURL.path))
            """
        )
        let images = try await fixture.waitForMarkdownImages(expectedCount: 4)
        func image(alt: String) throws -> [String: Any] {
            try #require(images.first { $0["alt"] as? String == alt })
        }

        let localImage = try image(alt: "Local pixel")
        #expect((localImage["complete"] as? Bool) == (true))
        #expect((try #require(localImage["naturalWidth"] as? Int)) > (0))
        #expect((try #require(localImage["naturalHeight"] as? Int)) > (0))
        #expect((localImage["currentSrc"] as? String ?? "").hasPrefix("bmux-local-image://"))

        let traversalImage = try image(alt: "Traversal pixel")
        #expect((traversalImage["complete"] as? Bool) == (true))
        #expect((traversalImage["naturalWidth"] as? Int) == (0))
        #expect((traversalImage["naturalHeight"] as? Int) == (0))
        #expect((traversalImage["currentSrc"] as? String ?? "").hasPrefix("bmux-local-image://"))

        let explicitFileImage = try image(alt: "Explicit file pixel")
        #expect((explicitFileImage["src"] as? String) == (""))
        #expect((explicitFileImage["currentSrc"] as? String) == (""))

        let rootAbsoluteImage = try image(alt: "Root absolute pixel")
        #expect((rootAbsoluteImage["src"] as? String) == (""))
        #expect((rootAbsoluteImage["currentSrc"] as? String) == (""))
    }

    @Test
    func loadsSafeDataImage() async throws {
        let markdownURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-markdown-data-image-\(UUID().uuidString).md")

        let frame = NSRect(x: 0, y: 0, width: 320, height: 240)
        let webView = WKWebView(frame: frame, configuration: WKWebViewConfiguration())
        let fixture = MarkdownRenderTestFixture(webView: webView)
        defer {
            fixture.close()
        }

        try await fixture.loadShell(baseURL: markdownURL)

        try await fixture.renderMarkdown("![Inline pixel](\(fixture.onePixelPNGDataURI))\n")
        let image = try #require(try await fixture.waitForMarkdownImages(expectedCount: 1).first)

        #expect((image["found"] as? Bool) == (true))
        #expect((image["complete"] as? Bool) == (true))
        #expect((try #require(image["naturalWidth"] as? Int)) > (0))
        #expect((try #require(image["naturalHeight"] as? Int)) > (0))
        #expect((image["src"] as? String ?? "").hasPrefix("data:image/png;base64,"))
    }
}
