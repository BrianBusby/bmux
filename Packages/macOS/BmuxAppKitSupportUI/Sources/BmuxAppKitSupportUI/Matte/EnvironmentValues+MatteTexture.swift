import AppKit
import SwiftUI

extension EnvironmentValues {
    /// An immutable image loaded by the containing texture scope, never by a row.
    var matteTextureImage: NSImage? {
        get { self[MatteTextureImageKey.self] }
        set { self[MatteTextureImageKey.self] = newValue }
    }
}

private struct MatteTextureImageKey: EnvironmentKey {
    static let defaultValue: NSImage? = nil
}
