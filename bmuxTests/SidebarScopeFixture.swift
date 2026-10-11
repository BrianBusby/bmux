import SwiftUI

/// Local SwiftUI state and inherited environment must survive native host updates.
struct SidebarScopeFixture: View {
    let height: CGFloat
    let capture: ((UUID, ColorScheme, Bool, LayoutDirection, String)) -> Void
    @State private var identity = UUID()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.locale) private var locale
    var body: some View {
        SidebarScopeProbe(values: (identity, colorScheme, isEnabled, layoutDirection, locale.identifier), capture: capture)
            .frame(width: 100, height: height)
    }
}
