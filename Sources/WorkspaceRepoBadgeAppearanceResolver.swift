import Foundation

struct WorkspaceRepoBadgeAppearance: Equatable {
    let name: String
    let colorHex: String
}

enum WorkspaceRepoBadgeAppearanceColorPolicy {
    static func effectiveColorHex(
        customColorHex: String?,
        repoBadgeAppearance: WorkspaceRepoBadgeAppearance?
    ) -> String? {
        if let customColorHex = customColorHex.flatMap(WorkspaceTabColorSettings.normalizedHex) {
            return customColorHex
        }
        return repoBadgeAppearance?.colorHex
    }
}

struct WorkspaceRepoBadgeAppearanceResolver {
    private static let fallbackColorHex = "#F2C94C"
    private static let sessionPalette = [
        "#F2C94C",
        "#56CCF2",
        "#6FCF97",
        "#BB6BD9",
        "#F2994A",
        "#2F80ED",
        "#EB5757",
        "#9BCA3E",
    ]

    @MainActor private static var sessionResolver = WorkspaceRepoBadgeAppearanceResolver()

    private let palette: [String]
    private var colorsByRepoRootPath: [String: String] = [:]

    init(palette: [String] = Self.sessionPalette) {
        let normalizedPalette = palette.compactMap(WorkspaceTabColorSettings.normalizedHex)
        self.palette = normalizedPalette.isEmpty ? [Self.fallbackColorHex] : normalizedPalette
    }

    mutating func appearance(repoRootPath: String?) -> WorkspaceRepoBadgeAppearance? {
        guard let normalizedPath = Self.normalizedRepoRootPath(repoRootPath) else {
            return nil
        }
        let repoName = URL(fileURLWithPath: normalizedPath, isDirectory: true)
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repoName.isEmpty else { return nil }

        let colorHex: String
        if let existingColor = colorsByRepoRootPath[normalizedPath] {
            colorHex = existingColor
        } else {
            colorHex = palette[colorsByRepoRootPath.count % palette.count]
            colorsByRepoRootPath[normalizedPath] = colorHex
        }

        return WorkspaceRepoBadgeAppearance(name: repoName, colorHex: colorHex)
    }

    @MainActor static func sessionAppearance(repoRootPath: String?) -> WorkspaceRepoBadgeAppearance? {
        sessionResolver.appearance(repoRootPath: repoRootPath)
    }

    private static func normalizedRepoRootPath(_ path: String?) -> String? {
        guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        let url = URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL
        let normalizedPath = url.path
        guard normalizedPath != "/" else { return nil }
        return normalizedPath.hasSuffix("/")
            ? String(normalizedPath.dropLast())
            : normalizedPath
    }
}
