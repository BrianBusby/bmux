import SwiftUI
import BmuxAppKitSupportUI

/// Keeps matte chrome opaque while the existing window backdrop owns transparent terminal canvases.
struct TerminalBackdropSurface: ViewModifier {
    let role: MatteSurfaceRole
    let theme: MatteTheme

    func body(content: Content) -> some View {
        content.backgroundPreferenceValue(TerminalBackdropRegionPreference.self) { regions in
            decoration
                .overlay {
                    GeometryReader { geometry in
                        ForEach(regions.indices, id: \.self) { index in
                            let bounds = geometry[regions[index]]
                            Rectangle()
                                .fill(.black)
                                .frame(width: bounds.width, height: bounds.height)
                                .position(x: bounds.midX, y: bounds.midY)
                        }
                    }
                    .blendMode(.destinationOut)
                }
                // Isolate subtraction to the decoration, including its shadow fills.
                // Neither terminal content nor the configured root backdrop is masked.
                .compositingGroup()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var decoration: some View {
        if role == .base {
            Color.clear.matteSurface(role, theme: theme).ignoresSafeArea()
        } else {
            Color.clear.matteSurface(role, theme: theme)
        }
    }
}
