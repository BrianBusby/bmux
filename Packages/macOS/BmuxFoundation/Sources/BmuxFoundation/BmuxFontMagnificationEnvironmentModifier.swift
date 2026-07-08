public import SwiftUI

/// Injects the stored bmux font magnification percent into a SwiftUI subtree.
struct BmuxFontMagnificationEnvironmentModifier: ViewModifier {
    @AppStorage(GlobalFontMagnification.percentKey) private var percent = GlobalFontMagnification.defaultPercent

    func body(content: Content) -> some View {
        content.environment(\.bmuxGlobalFontMagnificationPercent, percent)
    }
}
