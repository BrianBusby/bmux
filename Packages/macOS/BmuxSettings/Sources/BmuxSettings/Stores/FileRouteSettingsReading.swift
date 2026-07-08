import Foundation

/// Read access to the cmd-click file routing settings: whether cmd-clicked
/// markdown files open in the bmux markdown viewer and whether other
/// supported files open in bmux previews.
///
/// Consumer domains (the cmd-click open router) depend on this seam instead
/// of the concrete ``FileRouteSettingsStore``.
public protocol FileRouteSettingsReading: Sendable {
    /// Whether cmd-clicked markdown files route to the bmux markdown viewer.
    var markdownRouteEnabled: Bool { get }

    /// Whether cmd-clicked supported files route to bmux previews.
    var supportedFileRouteEnabled: Bool { get }

    /// Whether `path` should open in the bmux markdown viewer: the markdown
    /// route is enabled, the path has a markdown extension, and it is a
    /// readable regular file.
    func shouldRouteMarkdown(path: String) -> Bool

    /// Whether `path` should open in a bmux preview: the supported-file route
    /// is enabled and the path is a readable regular file.
    func shouldRouteSupportedFile(path: String) -> Bool
}
