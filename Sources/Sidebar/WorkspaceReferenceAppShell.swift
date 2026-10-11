import SwiftUI
import BmuxAppKitSupportUI

/// Presents the continuous matte base and sidebar/main gutter without owning their state.
struct WorkspaceReferenceAppShell<Rail: View, Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearanceSettings.matteTextureEnabledKey) private var textureEnabled = false
    @ViewBuilder let rail: () -> Rail
    @ViewBuilder let content: () -> Content

    var body: some View {
        let theme = MatteTheme(colorScheme: colorScheme)
        ZStack {
            Color.clear.matteSurface(.base, theme: theme).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: theme.layout.brandHeaderContentGap) {
                        Text("bmux")
                            .matteTypography(.wordmark, theme: theme)
                            .foregroundStyle(Color(nsColor: theme.color(.textPrimary)))
                        Text("✳").font(.system(size: theme.layout.brandDecorationSize)).foregroundStyle(Color(nsColor: theme.color(.sage)))
                        Text("CompanyCam").matteTypography(.body, theme: theme).foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
                    }
                    Spacer()
                }
                .padding(.horizontal, theme.layout.brandHeaderHorizontalInset)
                .frame(height: theme.layout.brandHeaderHeight)
                .offset(y: theme.layout.brandHeaderVerticalOffset)

                GeometryReader { geometry in
                    HStack(spacing: theme.layout.windowGutter) {
                        rail()
                            .frame(width: min(theme.layout.sidebarMaximumWidth, max(theme.layout.sidebarMinimumWidth, geometry.size.width * theme.layout.sidebarPreferredFraction)))
                        content()
                            .padding(.top, theme.layout.mainPanelTopInset)
                    }
                }
            }
            .padding(.horizontal, theme.layout.windowGutter)
            .padding(.bottom, theme.layout.windowGutter)
            .padding(.top, theme.layout.shellTopInset)
        }
        .matteTexture(enabled: textureEnabled)
    }
}
