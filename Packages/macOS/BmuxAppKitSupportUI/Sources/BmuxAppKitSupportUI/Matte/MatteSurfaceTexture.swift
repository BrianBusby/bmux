import AppKit
import SwiftUI

/// Tiles the bundled alpha mask beneath surface content, never over terminal pixels.
struct MatteSurfaceTexture: View {
    let role: MatteSurfaceRole
    let tokens: MatteTextureTokens
    let image: NSImage

    var body: some View {
        if role != .inset {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable(resizingMode: .tile)
                .foregroundStyle(tokens.isWhiteNoise ? Color.white : Color.black)
                .opacity(opacity)
        }
    }

    private var opacity: Double {
        switch role {
        case .base: tokens.baseOpacity
        case .panel: tokens.panelOpacity
        case .card, .overlay: tokens.cardOpacity
        case .inset: 0
        }
    }
}
