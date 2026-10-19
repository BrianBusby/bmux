/// Stationary micrograin parameters; texture always sits behind content.
public struct MatteTextureTokens: Sendable {
    /// Tile size in points for the native asset.
    public let tileSize: Double

    /// Required raster asset scales.
    public let assetScales: [Int]

    /// Raster channel bit depth.
    public let bitDepth: Int

    /// Texture opacity on the continuous base.
    public let baseOpacity: Double

    /// Texture opacity on main panels.
    public let panelOpacity: Double

    /// Texture opacity on workspace cards and menus.
    public let cardOpacity: Double

    /// Whether the monochrome grain is white rather than black.
    public let isWhiteNoise: Bool

    /// Fractal-noise base frequency in the reference generator.
    public let baseFrequency: Double

    /// Fractal-noise octave count in the reference generator.
    public let octaveCount: Int

    /// Stable generator seed for seamless, repeatable grain.
    public let seed: Int

    /// Red-channel multiplier in the reference alpha matrix.
    public let alphaMultiplier: Double

    /// Offset applied after the red-channel alpha multiplier.
    public let alphaOffset: Double
}
