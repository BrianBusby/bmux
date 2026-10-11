import AppKit
import SwiftUI

/// Owns the resource lifetime above list boundaries; rows receive an image value.
struct MatteTextureScope: ViewModifier {
    let enabled: Bool
    @State private var image: NSImage?

    func body(content: Content) -> some View {
        content
            .environment(\.matteTextureImage, enabled ? image : nil)
            .onChange(of: enabled, initial: true) { _, isEnabled in
                if isEnabled && image == nil {
                    image = Bundle.module.image(forResource: "MatteNoise")
                }
            }
    }
}
