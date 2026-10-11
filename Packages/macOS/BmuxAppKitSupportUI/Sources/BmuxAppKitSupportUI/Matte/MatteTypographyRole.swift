/// Semantic font metrics for native chrome and the terminal reference.
public enum MatteTypographyRole: CaseIterable, Sendable {
    /// Native window title; preserves the pre-matte 13-point bold system font.
    case windowTitle
    /// Native build badge; preserves the pre-matte 10.5-point semibold system font.
    case buildBadge
    /// Brand wordmark.
    case wordmark
    /// Main workspace heading.
    case workspaceHeading
    /// Workspace card title.
    case cardTitle
    /// Repository label.
    case repositoryLabel
    /// Uppercase section label.
    case sectionLabel
    /// Active and inactive tab labels share these metrics.
    case tab
    /// Body text, links, and metadata.
    case body
    /// Preview line.
    case previewLine
    /// Terminal reference metrics; preserve the actual terminal font preferences.
    case terminal
}
