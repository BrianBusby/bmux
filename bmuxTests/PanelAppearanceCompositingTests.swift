import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct PanelAppearanceCompositingTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func transparentGhosttyOpacityClearsContentAndCompositesChrome(appearanceName: NSAppearance.Name) throws {
        let drawingAppearance = try #require(NSAppearance(named: appearanceName))
        var result: Result<Void, Error> = .success(())
        drawingAppearance.performAsCurrentDrawingAppearance {
            result = Result {
                var config = GhosttyConfig()
                config.backgroundColor = NSColor(srgbRed: 0.10, green: 0.20, blue: 0.30, alpha: 1)
                config.backgroundOpacity = 0.42
                config.backgroundBlur = .disabled

                let appearance = PanelAppearance.fromConfig(config, usesTransparentWindow: false)
                #expect(appearance.usesClearContentBackground)
                #expect(!appearance.drawsContentBackground)
                #expect(abs(appearance.contentBackgroundColor.alphaComponent) < 0.0001)

                let actual = try #require(appearance.backgroundColor.usingColorSpace(.sRGB))
                let window = try #require(NSColor.windowBackgroundColor.usingColorSpace(.sRGB))
                // Compute the expected blend independently of the production color resolver.
                #expect(abs(actual.alphaComponent - 1) < 0.0001)
                #expect(abs(actual.redComponent - (0.10 * 0.42 + window.redComponent * 0.58)) < 0.0001)
                #expect(abs(actual.greenComponent - (0.20 * 0.42 + window.greenComponent * 0.58)) < 0.0001)
                #expect(abs(actual.blueComponent - (0.30 * 0.42 + window.blueComponent * 0.58)) < 0.0001)
            }
        }
        try result.get()
    }
}
