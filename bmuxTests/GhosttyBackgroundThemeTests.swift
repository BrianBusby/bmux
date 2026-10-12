import AppKit
import Testing
import BmuxAppKitSupportUI

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct GhosttyBackgroundThemeTests {
    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
    func opacityLimitsProduceOpaqueWindowOrTerminalColor(appearanceName: NSAppearance.Name) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            let terminal = NSColor(srgbRed: 0.10, green: 0.20, blue: 0.30, alpha: 1)
            expectColor(GhosttyBackgroundTheme.color(backgroundColor: terminal, opacity: -2), equals: .windowBackgroundColor)
            expectColor(GhosttyBackgroundTheme.color(backgroundColor: terminal, opacity: 5), equals: terminal)
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [false, true])
    func notificationCompositesItsPayloadOverWindow(appearanceName: NSAppearance.Name, boxedOpacity: Bool) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            let color = NSColor(srgbRed: 0.18, green: 0.29, blue: 0.44, alpha: 1)
            let opacity: Any = boxedOpacity ? NSNumber(value: 0.57) : 0.57 as Any
            let notification = Notification(name: .ghosttyDefaultBackgroundDidChange, userInfo: [
                GhosttyNotificationKey.backgroundColor: color,
                GhosttyNotificationKey.backgroundOpacity: opacity,
            ])
            let actual = GhosttyBackgroundTheme.color(from: notification, fallbackColor: .black, fallbackOpacity: 1)
            let expected = WindowAppearanceSnapshot.compositedTerminalColor(backgroundColor: color, opacity: 0.57)
            expectColor(actual, equals: expected)
            #expect(actual.alphaComponent == 1)
        }
    }

    @Test(arguments: [NSAppearance.Name.aqua, .darkAqua], [false, true])
    func missingPayloadCompositesFallback(appearanceName: NSAppearance.Name, missingNotification: Bool) throws {
        let appearance = try #require(NSAppearance(named: appearanceName))
        appearance.performAsCurrentDrawingAppearance {
            let fallback = NSColor(srgbRed: 0.12, green: 0.34, blue: 0.56, alpha: 1)
            let notification: Notification? = missingNotification ? nil : Notification(name: .ghosttyDefaultBackgroundDidChange)
            let actual = GhosttyBackgroundTheme.color(from: notification, fallbackColor: fallback, fallbackOpacity: 0.42)
            expectColor(actual, equals: WindowAppearanceSnapshot.compositedTerminalColor(backgroundColor: fallback, opacity: 0.42))
            #expect(actual.alphaComponent == 1)
        }
    }

    private func expectColor(_ actual: NSColor, equals expected: NSColor) {
        guard let actual = actual.usingColorSpace(.sRGB), let expected = expected.usingColorSpace(.sRGB) else {
            Issue.record("Expected sRGB-convertible colors")
            return
        }
        #expect(abs(actual.redComponent - expected.redComponent) < 0.005)
        #expect(abs(actual.greenComponent - expected.greenComponent) < 0.005)
        #expect(abs(actual.blueComponent - expected.blueComponent) < 0.005)
        #expect(abs(actual.alphaComponent - expected.alphaComponent) < 0.005)
    }
}
