import AppKit
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct WorkspaceChromeColorTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func bonsplitChromeHexCompositesTranslucencyOverWindow(appearanceName: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            guard let expectedTranslucentHex = expectedTranslucentHex() else { return }
            let color = NSColor(
                srgbRed: 17.0 / 255.0,
                green: 34.0 / 255.0,
                blue: 51.0 / 255.0,
                alpha: 1.0
            )

            let hex = Workspace.bonsplitChromeHex(backgroundColor: color, backgroundOpacity: 0.5)
            #expect(hex == expectedTranslucentHex)
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func bonsplitChromeHexOmitsAlphaWhenOpaque(appearanceName: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            let color = NSColor(
                srgbRed: 17.0 / 255.0,
                green: 34.0 / 255.0,
                blue: 51.0 / 255.0,
                alpha: 1.0
            )

            let hex = Workspace.bonsplitChromeHex(backgroundColor: color, backgroundOpacity: 1.0)
            #expect(hex == "#112233")
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func bonsplitChromeHexKeepsBackdropWhenSharingWindowBackdrop(appearanceName: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            guard let expectedTranslucentHex = expectedTranslucentHex() else { return }
            let color = NSColor(
                srgbRed: 17.0 / 255.0,
                green: 34.0 / 255.0,
                blue: 51.0 / 255.0,
                alpha: 1.0
            )

            let hex = Workspace.bonsplitChromeHex(
                backgroundColor: color,
                backgroundOpacity: 0.5,
                sharesWindowBackdrop: true
            )
            #expect(hex == expectedTranslucentHex)
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func bonsplitChromeColorsKeepPaneClearWhenTerminalUsesHostLayerBackground(appearanceName: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            guard let expectedTranslucentHex = expectedTranslucentHex() else { return }
            let color = NSColor(
                srgbRed: 17.0 / 255.0,
                green: 34.0 / 255.0,
                blue: 51.0 / 255.0,
                alpha: 1.0
            )

            let colors = Workspace.bonsplitChromeColors(
                backgroundColor: color,
                backgroundOpacity: 0.5,
                renderingMode: .windowHostBackdrop
            )

            #expect(colors.backgroundHex == expectedTranslucentHex)
            #expect(colors.tabBarBackgroundHex == expectedTranslucentHex)
            #expect(colors.splitButtonBackdropHex == expectedTranslucentHex)
            #expect(colors.paneBackgroundHex == "#00000000")
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func bonsplitChromeColorsKeepSemanticBackgroundButClearLocalBackdropsWhenSharingWindowBackdrop(appearanceName: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            guard let expectedTranslucentHex = expectedTranslucentHex() else { return }
            let color = NSColor(
                srgbRed: 17.0 / 255.0,
                green: 34.0 / 255.0,
                blue: 51.0 / 255.0,
                alpha: 1.0
            )

            let colors = Workspace.bonsplitChromeColors(
                backgroundColor: color,
                backgroundOpacity: 0.5,
                sharesWindowBackdrop: true,
                renderingMode: .windowHostBackdrop
            )

            #expect(colors.backgroundHex == expectedTranslucentHex)
            #expect(colors.tabBarBackgroundHex == "#00000000")
            #expect(colors.splitButtonBackdropHex == "#00000000")
            #expect(colors.paneBackgroundHex == "#00000000")
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func bonsplitChromeColorsUseConfiguredPaneBorderColor(appearanceName: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            guard let expectedTranslucentHex = expectedTranslucentHex() else { return }
            let color = NSColor(
                srgbRed: 17.0 / 255.0,
                green: 34.0 / 255.0,
                blue: 51.0 / 255.0,
                alpha: 1.0
            )

            let colors = Workspace.bonsplitChromeColors(
                backgroundColor: color,
                backgroundOpacity: 0.5,
                renderingMode: .windowHostBackdrop,
                paneBorderColorHex: "#33AAFF"
            )

            #expect(colors.backgroundHex == expectedTranslucentHex)
            #expect(colors.tabBarBackgroundHex == expectedTranslucentHex)
            #expect(colors.splitButtonBackdropHex == expectedTranslucentHex)
            #expect(colors.paneBackgroundHex == "#00000000")
            #expect(colors.borderHex == "#33AAFF")
        }
    }

    /// Resolve the dynamic window color in the caller's synchronous appearance scope.
    private func expectedTranslucentHex() -> String? {
        guard let base = NSColor.windowBackgroundColor.usingColorSpace(.sRGB) else {
            Issue.record("Expected an sRGB window background")
            return nil
        }
        let channels = zip([17.0, 34.0, 51.0], [base.redComponent, base.greenComponent, base.blueComponent])
        let bytes = channels.map { foreground, background in
            Int((foreground / 255.0 * 0.5 + Double(background) * 0.5) * 255.0)
        }
        return String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
    }
}
