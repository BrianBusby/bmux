import AppKit
import SwiftUI

@main struct MatteGallery {
    @MainActor static func main() throws {
        for scheme in [ColorScheme.dark, .light] {
            let theme = MatteTheme(colorScheme: scheme)
            let content = VStack(alignment: .leading, spacing: 28) {
                Text(scheme == .dark ? "GRAPHITE · NATIVE MATTE SURFACES" : "PORCELAIN · NATIVE MATTE SURFACES")
                    .font(.system(size: 16, weight: .semibold))
                HStack(spacing: 26) {
                    sample("RESTING / INACTIVE", role: .card, theme: theme)
                    sample("HOVERED", role: .card, theme: theme, state: .init(isHovered: true))
                    sample("SELECTED", role: .card, theme: theme, state: .init(isSelected: true))
                    sample("SELECTED + HOVER", role: .card, theme: theme, state: .init(isSelected: true, isHovered: true))
                }
                HStack(spacing: 26) {
                    sample("KEYBOARD FOCUS", role: .card, theme: theme, state: .init(isFocused: true))
                    sample("PRESSED", role: .card, theme: theme, state: .init(isHovered: true, isPressed: true))
                    sample("DISABLED", role: .card, theme: theme, state: .init(isHovered: true, isEnabled: false))
                    sample("OVERLAY", role: .overlay, theme: theme)
                }
                HStack(alignment: .top, spacing: 26) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MAIN PANEL").font(.system(size: 11, weight: .semibold))
                        Text("Workspace content").font(.system(size: 20, weight: .semibold))
                        Text("One contact shadow and one ambient shadow.").font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
                    .padding(theme.layout.panelPadding)
                    .matteSurface(.panel, theme: theme)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("TERMINAL INSET").font(.system(size: 11, weight: .semibold))
                        Text("brian@macbook ~ % git status\nOn branch matte-skin\nYour branch is up to date.")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, minHeight: 125, alignment: .topLeading)
                    .padding(theme.layout.panelPadding)
                    .matteSurface(.inset, theme: theme)
                }
                Spacer(minLength: 0)
            }
            .padding(32)
            .frame(width: 1092, height: 593)
            .foregroundStyle(Color(nsColor: theme.color(.textPrimary)))
            .matteSurface(.base, theme: theme)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let path = "\(CommandLine.arguments.dropFirst().first ?? "/tmp")/bmux-matte-stage2-\(scheme == .dark ? "graphite" : "porcelain").png"
            try data.write(to: URL(fileURLWithPath: path))
            print(path)
        }
    }

    static func sample(_ title: String, role: MatteSurfaceRole, theme: MatteTheme,
                       state: MatteSurfaceState = .init()) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
            Text("Maple Street").font(.system(size: 15, weight: .semibold))
            Text("Roof inspection").font(.system(size: 12))
                .foregroundStyle(Color(nsColor: theme.color(.textSecondary)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.layout.cardPadding)
        .opacity(state.isEnabled ? 1 : theme.layout.disabledOpacity)
        .matteSurface(role, theme: theme, state: state)
    }
}
