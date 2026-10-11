import AppKit
import SwiftUI
import Testing

@testable import BmuxAppKitSupportUI

@Suite @MainActor
struct MatteTextureTests {
    private let image = Bundle.module.image(forResource: "MatteNoise")

    @Test
    func bundledImageContainsBothBackingScales() throws {
        let image = try #require(image)
        #expect(image.size == NSSize(width: 128, height: 128))
        #expect(Set(image.representations.map(\.pixelsWide)) == [128, 256])
        #expect(image.representations.allSatisfy { $0.bitsPerSample == 8 })
    }

    @Test(arguments: [ColorScheme.dark, .light], [1.0, 2.0])
    func textureIsStationaryAndRepeatsEvery128Points(scheme: ColorScheme, scale: Double) throws {
        let enabled = try render(.base, scheme: scheme, enabled: true, scale: scale)
        let disabled = try render(.base, scheme: scheme, enabled: false, scale: scale)
        let repeated = try render(.base, scheme: scheme, enabled: true, scale: scale)
        var changed = 0
        var shades: Set<Int> = []
        var maximumRepeatError = 0.0
        for y in 20..<80 {
            for x in 20..<100 {
                let sample = try brightness(enabled, x, y)
                let plain = try brightness(disabled, x, y)
                if sample != plain { changed += 1 }
                shades.insert(Int((sample * 255).rounded()))
                maximumRepeatError = max(maximumRepeatError,
                    abs(sample - (try brightness(enabled, x + Int(128 * scale), y))))
                #expect(sample == (try brightness(repeated, x, y)))
                #expect(scheme == .dark ? sample >= plain : sample <= plain)
            }
        }
        #expect(maximumRepeatError < 0.001)
        #expect(changed > 1000, "The bundled grain must actually render")
        #expect(shades.count > 3, "Grain must vary, rather than being a uniform tint")
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func insetIsUnchangedAndOpaqueContentOccludesTexture(scheme: ColorScheme) throws {
        let on = try render(.inset, scheme: scheme, enabled: true)
        let off = try render(.inset, scheme: scheme, enabled: false)
        #expect(on.tiffRepresentation == off.tiffRepresentation)
        let renderer = ImageRenderer(content: Color.red.frame(width: 80, height: 80)
            .matteSurface(.panel, theme: MatteTheme(colorScheme: scheme))
            .environment(\.matteTextureImage, image))
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        let plainRenderer = ImageRenderer(content: Color.red.frame(width: 80, height: 80))
        let plain = NSBitmapImageRep(cgImage: try #require(plainRenderer.cgImage))
        #expect(bitmap.tiffRepresentation == plain.tiffRepresentation)
    }

    @Test(arguments: [ColorScheme.dark, .light])
    func raisedSurfaceGrainIsClippedAndQuieterThanBase(scheme: ColorScheme) throws {
        let base = try render(.base, scheme: scheme, enabled: true)
        let plainBase = try render(.base, scheme: scheme, enabled: false)
        for role in [MatteSurfaceRole.card, .panel, .overlay] {
            let on = try render(role, scheme: scheme, enabled: true)
            let off = try render(role, scheme: scheme, enabled: false)
            #expect(on.colorAt(x: 0, y: 0) == off.colorAt(x: 0, y: 0))
            var difference = 0.0
            var baseDifference = 0.0
            for y in 30..<60 {
                for x in 30..<60 {
                    difference += abs(try brightness(on, x, y) - brightness(off, x, y))
                    baseDifference += abs(try brightness(base, x, y) - brightness(plainBase, x, y))
                }
            }
            #expect(difference > 0 && difference < baseDifference)
        }
    }

    private func render(
        _ role: MatteSurfaceRole, scheme: ColorScheme, enabled: Bool, scale: Double = 1
    ) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(content: Color.clear.frame(width: 300, height: 160)
            .matteSurface(role, theme: MatteTheme(colorScheme: scheme))
            .environment(\.matteTextureImage, enabled ? image : nil))
        renderer.scale = scale
        return NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    }

    private func brightness(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) throws -> Double {
        let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return color.redComponent + color.greenComponent + color.blueComponent
    }
}
