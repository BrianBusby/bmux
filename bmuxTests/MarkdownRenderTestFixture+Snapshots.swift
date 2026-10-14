import AppKit
import Testing
import WebKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

extension MarkdownRenderTestFixture {
    func evaluateScrollSnapshot(_ script: String) async throws -> [String: Double] {
        let result = try await webView.evaluateJavaScript(script)
        let raw = try #require(result as? [String: Any])
        var snapshot: [String: Double] = [:]
        for (key, value) in raw {
            if let number = value as? NSNumber {
                snapshot[key] = number.doubleValue
            }
        }
        return snapshot
    }

    func remoteImageSnapshot() async throws -> [String: Any] {
        let result = try await webView.evaluateJavaScript(
            """
            (function() {
              return {
                images: Array.prototype.slice.call(document.querySelectorAll('img')).map(function(img) {
                  return {
                    alt: img.getAttribute('alt') || '',
                    src: img.getAttribute('src') || '',
                    currentSrc: img.currentSrc || '',
                    hidden: !!img.hidden,
                    remoteSrc: img.getAttribute('data-bmux-remote-src') || ''
                  };
                }),
                placeholders: Array.prototype.slice.call(document.querySelectorAll('.bmux-remote-image-placeholder')).map(function(el) {
                  return el.textContent || '';
                }),
                remoteImageURLs: Array.prototype.slice.call(document.querySelectorAll('.bmux-remote-image-url')).map(function(el) {
                  return el.textContent || '';
                }),
                buttons: Array.prototype.slice.call(document.querySelectorAll('.bmux-remote-image-placeholder button')).map(function(el) {
                  return el.textContent || '';
                }),
                buttonStates: Array.prototype.slice.call(document.querySelectorAll('.bmux-remote-image-placeholder button')).map(function(el) {
                  return {
                    text: el.textContent || '',
                    loading: el.getAttribute('data-loading') || '',
                    disabled: !!el.disabled
                  };
                }),
                codeFiles: Array.prototype.slice.call(document.querySelectorAll('code[data-bmux-file]')).map(function(el) {
                  return decodeURIComponent(el.getAttribute('data-bmux-file') || '');
                }),
                styleCount: document.getElementById('content').querySelectorAll('style').length,
                backgroundAttrCount: document.getElementById('content').querySelectorAll('[background]').length,
                renderedText: window.__bmuxRenderedText ? window.__bmuxRenderedText() : ''
              };
            })();
            """
        )
        return try #require(result as? [String: Any])
    }

    func scrollSmokeMarkdown(extraBeforeSection20: Bool) -> String {
        var lines: [String] = ["# Scroll Smoke", ""]
        for section in 1...36 {
            if section == 20, extraBeforeSection20 {
                for line in 1...12 {
                    lines.append("Inserted external edit line \(line), above the visible heading.")
                }
                lines.append("")
            }

            lines.append("## Section \(section)")
            lines.append("")
            for paragraph in 1...5 {
                lines.append(
                    "Paragraph \(paragraph) for section \(section). This gives the renderer enough height to exercise scroll restoration after an external file edit."
                )
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    static let onePixelPNG: Data = {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Unable to generate one-pixel PNG fixture")
        }
        return png
    }()

    var onePixelPNGDataURI: String { "data:image/png;base64,\(Self.onePixelPNG.base64EncodedString())" }
}
