import SwiftUI
import BmuxAppKitSupportUI

/// Presents the continuous matte base and sidebar/main gutter without owning their state.
struct WorkspaceReferenceAppShell<Rail: View, Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let rail: () -> Rail
    @ViewBuilder let content: () -> Content

    var body: some View {
        let theme = MatteTheme(colorScheme: colorScheme)
        ZStack {
            Color(nsColor: theme.color(.base)).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Text("bmux")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(nsColor: theme.color(.textPrimary)))
                        Text("✳").font(.system(size: 18)).foregroundStyle(Color(nsColor: theme.color(.sage)))
                        Text("CompanyCam").foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .frame(height: 44)

                GeometryReader { geometry in
                    HStack(spacing: theme.layout.windowGutter) {
                        rail()
                            .frame(width: min(theme.layout.sidebarMaximumWidth, max(theme.layout.sidebarMinimumWidth, geometry.size.width * theme.layout.sidebarPreferredFraction)))
                        content()
                    }
                }
            }
            .padding(.horizontal, theme.layout.windowGutter)
            .padding(.bottom, theme.layout.windowGutter)
            .padding(.top, 18)
        }
    }
}
