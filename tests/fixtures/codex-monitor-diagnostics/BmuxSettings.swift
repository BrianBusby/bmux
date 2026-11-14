import Foundation
public struct BmuxStateDirectory {
    public static func url(homeDirectory: URL) -> URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["TEST_STATE_DIR"]!, isDirectory: true)
    }
}
