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
final class MarkdownMermaidZoomTests {
    @Test
    func renderedMermaidDiagramScalesWithViewerZoom() async throws {
        let fixture = MarkdownMermaidTestFixture()
        defer { fixture.close() }
        let webView = fixture.webView
        let coordinator = fixture.coordinator
        try await fixture.load()

        coordinator.setFontSize(MarkdownFontSizeSettings.defaultPointSize)
        try await fixture.renderer.renderMarkdown(
            """
            Prose before the diagram.

            ```mermaid
            flowchart LR
              host[Host process] --> backend[Backend]
              backend --> worker[Worker]
            ```
            """
        )

        let baseline = try await fixture.snapshot()
        let baselineWidth = try #require(baseline["width"])
        let baselineProseHeight = try #require(baseline["proseHeight"])
        #expect(abs((baseline["zoom"] ?? -1) - 1) <= 0.001)
        #expect(abs(baselineWidth - 240) <= 2)

        coordinator.setFontSize(MarkdownFontSizeSettings.defaultPointSize * 2)
        let zoomed = try await fixture.snapshot(expectedZoom: 2)
        let zoomedWidth = try #require(zoomed["width"])
        let zoomedProseHeight = try #require(zoomed["proseHeight"])
        #expect(zoomedWidth > baselineWidth * 1.8)
        #expect(abs((zoomedWidth / baselineWidth) - (zoomedProseHeight / baselineProseHeight)) <= 0.25)
        let exported = try await fixture.exportedSnapshot()
        #expect((exported["width"] ?? "missing") == "")
        #expect((exported["height"] ?? "missing") == "")
        #expect(exported["maxWidth"] == "240px")
        #expect(exported["hasBmuxData"] == "0")

        coordinator.setFontSize(MarkdownFontSizeSettings.defaultPointSize)
        try await fixture.renderer.renderMarkdown(
            """
            ```mermaid
            flowchart LR
              wideDiagram[Very wide diagram] --> wider[Still fits at one hundred percent]
            ```
            """
        )
        let fitted = try await fixture.snapshot()
        let fittedWidth = try #require(fitted["width"])
        let fittedContainerWidth = try #require(fitted["containerWidth"])
        #expect(fittedWidth > baselineWidth * 1.8)
        #expect(fittedWidth <= fittedContainerWidth + 2)

        coordinator.setFontSize(MarkdownFontSizeSettings.defaultPointSize * 2)
        let fittedZoomed = try await fixture.snapshot(expectedZoom: 2)
        let fittedZoomedWidth = try #require(fittedZoomed["width"])
        #expect(fittedZoomedWidth > fittedWidth * 1.8)
        #expect((try #require(fittedZoomed["leftOffset"])) >= -1)

        let widerFrame = NSRect(x: 0, y: 0, width: 960, height: 480)
        try #require(webView.window).setFrame(widerFrame, display: true)
        webView.frame = widerFrame
        _ = try await webView.evaluateJavaScript("window.__bmuxSetMarkdownZoom(2);")
        let widened = try await fixture.snapshot(
            expectedZoom: 2,
            minimumWidth: fittedZoomedWidth * 1.1
        )
        let widenedWidth = try #require(widened["width"])
        #expect(widenedWidth > fittedZoomedWidth * 1.1)
    }

    @Test
    func firstDiagramAtDoubleZoomTracksContentCapChanges() async throws {
        let fixture = MarkdownMermaidTestFixture()
        defer { fixture.close() }
        try await fixture.load()
        fixture.coordinator.setFontSize(MarkdownFontSizeSettings.defaultPointSize * 2)
        try await fixture.renderer.renderMarkdown("```mermaid\nflowchart LR\n  host --> worker\n```")
        let small = try await fixture.snapshot(expectedZoom: 2)
        #expect(abs(try #require(small["width"]) - 480) <= 4)

        try await fixture.renderer.renderMarkdown("```mermaid\nflowchart LR\n  wideDiagram --> worker\n```")
        let wide = try await fixture.snapshot(expectedZoom: 2)
        let before = try #require(wide["width"])
        // Measure 1x only after the fresh 2x render, without priming its fit cache.
        let reference = MarkdownMermaidTestFixture()
        defer { reference.close() }
        try await reference.load()
        reference.coordinator.setFontSize(MarkdownFontSizeSettings.defaultPointSize)
        try await reference.renderer.renderMarkdown("```mermaid\nflowchart LR\n  wideDiagram --> worker\n```")
        let referenceSnapshot = try await reference.snapshot(expectedZoom: 1)
        #expect(abs(before - (try #require(referenceSnapshot["width"]) * 2)) <= 4)
        // Both caps exceed the current zoomed column; its ResizeObserver alone cannot see this change.
        fixture.coordinator.setMaxContentWidth(500)
        let capped = try await fixture.snapshot(expectedZoom: 2)
        #expect(abs(try #require(capped["width"]) - 1000) <= 4)
        #expect(try #require(capped["width"]) < before)
        fixture.coordinator.setMaxContentWidth(MarkdownMaxWidthSettings.defaultCSSPixels)
        let restored = try await fixture.snapshot(expectedZoom: 2)
        #expect(abs(try #require(restored["width"]) - before) <= 4)
    }
}
