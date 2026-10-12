import XCTest

enum BundledCLITestSupport {
    static func bundledCLIPath(
        for bundleClass: AnyClass,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        try bundledCLIURL(for: bundleClass, file: file, line: line).path
    }

    static func bundledCLIURL(
        for bundleClass: AnyClass,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> URL {
        let fileManager = FileManager.default
        let appBundleURL = Bundle(for: bundleClass)
            .bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let expectedCLIURL = appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("bmux", isDirectory: false)

        if fileManager.isExecutableFile(atPath: expectedCLIURL.path) {
            return expectedCLIURL
        }

        let enumerator = fileManager.enumerator(
            at: appBundleURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        while let item = enumerator?.nextObject() as? URL {
            guard item.lastPathComponent == "bmux",
                  item.path.contains(".app/Contents/Resources/bin/bmux"),
                  fileManager.isExecutableFile(atPath: item.path) else { continue }
            return item
        }

        let message = "Bundled bmux CLI not found at \(expectedCLIURL.path)"
        XCTFail(message, file: file, line: line)
        throw NSError(domain: "bmux.tests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: message,
        ])
    }
}
