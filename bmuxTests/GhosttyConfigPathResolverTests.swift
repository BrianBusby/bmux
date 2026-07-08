import XCTest
import Foundation
import BmuxFoundation

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

final class GhosttyConfigPathResolverTests: XCTestCase {
    func testBmuxAppSupportConfigURLsUseReleaseConfigForDebugBundleWithoutCurrentConfig() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let releaseConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config",
                contents: "font-size = 13\n"
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.debug",
                    appSupportDirectory: appSupportDirectory
                ),
                [releaseConfigURL]
            )
        }
    }

    func testBmuxAppSupportConfigURLsPreferConfigGhosttyOverLegacyConfigWhenBothExist() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config",
                contents: "background = #000000\n"
            )
            let preferredConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: "theme = light:3024 Day,dark:3024 Night\n"
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.debug.issue-3478",
                    appSupportDirectory: appSupportDirectory
                ),
                [preferredConfigURL]
            )
        }
    }

    func testBmuxAppSupportConfigURLsPreferCurrentBundleConfigWhenPresent() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config",
                contents: "font-size = 13\n"
            )
            let currentConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app.debug.issue-829",
                filename: "config.ghostty",
                contents: "font-size = 14\n"
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.debug.issue-829",
                    appSupportDirectory: appSupportDirectory
                ),
                [currentConfigURL]
            )
        }
    }

    func testBmuxAppSupportConfigURLsPreserveSymlinkedConfigURL() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let fileManager = FileManager.default
            let bundleDirectory = appSupportDirectory
                .appendingPathComponent("com.bmuxterm.app.debug.issue-3518", isDirectory: true)
            try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

            let dotfilesDirectory = appSupportDirectory
                .appendingPathComponent("dotfiles", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: dotfilesDirectory, withIntermediateDirectories: true)
            let targetConfigURL = dotfilesDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try "font-size = 16\n".write(to: targetConfigURL, atomically: true, encoding: .utf8)

            let symlinkedConfigURL = bundleDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try fileManager.createSymbolicLink(
                atPath: symlinkedConfigURL.path,
                withDestinationPath: targetConfigURL.path
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.debug.issue-3518",
                    appSupportDirectory: appSupportDirectory
                ),
                [symlinkedConfigURL]
            )
        }
    }

    func testConfigSourceEnvironmentSaveWritesThroughSymlinkedBmuxConfig() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = FileManager.default
            let appSupportDirectory = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
            let bundleDirectory = appSupportDirectory
                .appendingPathComponent("com.bmuxterm.app.debug.issue-3518", isDirectory: true)
            try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

            let dotfilesDirectory = homeDirectory
                .appendingPathComponent("dotfiles", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: dotfilesDirectory, withIntermediateDirectories: true)
            let targetConfigURL = dotfilesDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try "font-size = 16\n".write(to: targetConfigURL, atomically: true, encoding: .utf8)

            let symlinkedConfigURL = bundleDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try fileManager.createSymbolicLink(
                atPath: symlinkedConfigURL.path,
                withDestinationPath: targetConfigURL.path
            )

            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: "com.bmuxterm.app.debug.issue-3518"
            )
            try environment.writeBmuxConfigContents("theme = light:Andromeda,dark:3024 Day\n")

            XCTAssertEqual(
                try String(contentsOf: targetConfigURL, encoding: .utf8),
                "theme = light:Andromeda,dark:3024 Day\n"
            )
            XCTAssertEqual(
                try symlinkedConfigURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
                true
            )
            XCTAssertEqual(environment.bmuxConfigURL, symlinkedConfigURL)
        }
    }

    func testMaterializeWritesSelectedEditableConfigWhenLegacyConfigAppearsDuringCheck() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = RaceCreatingFileManager()
            let appSupportDirectory = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
            let bundleDirectory = appSupportDirectory
                .appendingPathComponent("com.bmuxterm.app.debug.issue-3518", isDirectory: true)
            let configGhosttyURL = bundleDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            let legacyConfigURL = bundleDirectory.appendingPathComponent("config", isDirectory: false)

            fileManager.onFirstMissingPlainExistenceCheck = { path in
                guard path == configGhosttyURL.path else { return }
                try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
                try "background = #000000\n".write(to: legacyConfigURL, atomically: true, encoding: .utf8)
            }

            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: "com.bmuxterm.app.debug.issue-3518",
                fileManager: fileManager
            )

            let materializedURL = try environment.materializeBmuxConfigFileIfNeeded()

            XCTAssertEqual(materializedURL, configGhosttyURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: configGhosttyURL.path))
            XCTAssertEqual(try String(contentsOf: configGhosttyURL, encoding: .utf8), "")
            XCTAssertEqual(try String(contentsOf: legacyConfigURL, encoding: .utf8), "background = #000000\n")
            XCTAssertNil(fileManager.creationError)
        }
    }

    func testSyncedConfigPreviewIncludesSymlinkedStandaloneGhosttyConfig() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = FileManager.default
            let ghosttyConfigDirectory = homeDirectory
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: ghosttyConfigDirectory, withIntermediateDirectories: true)

            let dotfilesDirectory = homeDirectory
                .appendingPathComponent("dotfiles", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: dotfilesDirectory, withIntermediateDirectories: true)
            let targetConfigURL = dotfilesDirectory.appendingPathComponent("config", isDirectory: false)
            try "font-size = 17\n".write(to: targetConfigURL, atomically: true, encoding: .utf8)

            let symlinkedConfigURL = ghosttyConfigDirectory.appendingPathComponent("config", isDirectory: false)
            try fileManager.createSymbolicLink(
                atPath: symlinkedConfigURL.path,
                withDestinationPath: targetConfigURL.path
            )

            let snapshot = ConfigSource.synced.snapshot(
                environment: ConfigSourceEnvironment(
                    homeDirectoryURL: homeDirectory,
                    currentBundleIdentifier: "com.bmuxterm.app"
                )
            )

            XCTAssertTrue(snapshot.hasStandaloneGhosttyConfig)
            XCTAssertTrue(snapshot.contents.contains("font-size = 17"))
            XCTAssertEqual(snapshot.displayPaths, [
                homeDirectory
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Application Support", isDirectory: true)
                    .appendingPathComponent("com.bmuxterm.app", isDirectory: true)
                    .appendingPathComponent("config.synced-preview", isDirectory: false)
                    .path,
            ])
        }
    }

    func testBmuxAppSupportConfigURLsUseNightlyConfigWhenPresent() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )
            let nightlyConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app.nightly",
                filename: "config.ghostty",
                contents: "font-size = 15\n"
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.nightly",
                    appSupportDirectory: appSupportDirectory
                ),
                [nightlyConfigURL]
            )
        }
    }

    func testBmuxAppSupportConfigURLsUseReleaseConfigForNightlyWithoutCurrentConfig() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let releaseConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.nightly",
                    appSupportDirectory: appSupportDirectory
                ),
                [releaseConfigURL]
            )
        }
    }

    func testBmuxAppSupportConfigURLsUseStagingConfigWhenPresent() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )
            let stagingConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app.staging",
                filename: "config.ghostty",
                contents: "font-size = 15\n"
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.staging",
                    appSupportDirectory: appSupportDirectory
                ),
                [stagingConfigURL]
            )
        }
    }

    func testBmuxAppSupportConfigURLsUseReleaseConfigForStagingWithoutCurrentConfig() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let releaseConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )

            XCTAssertEqual(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.staging",
                    appSupportDirectory: appSupportDirectory
                ),
                [releaseConfigURL]
            )
        }
    }

    func testLoadedGhosttyConfigScanPathsOmitsReleaseLegacyConfigWhenPreferredConfigGhosttyExists() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let legacyConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config",
                contents: "background = #000000\n"
            )
            let preferredConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: "theme = light:3024 Day,dark:3024 Night\n"
            )

            let paths = GhosttyApp.loadedGhosttyConfigScanPaths(
                currentBundleIdentifier: "com.bmuxterm.app.debug.issue-3478",
                appSupportDirectory: appSupportDirectory
            )

            XCTAssertTrue(paths.contains(preferredConfigURL.path))
            XCTAssertFalse(paths.contains(legacyConfigURL.path))
        }
    }

    func testBmuxAppSupportConfigURLsSkipReleaseFallbackForNonDebugBundle() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config",
                contents: "font-size = 13\n"
            )

            XCTAssertTrue(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.example.other-app",
                    appSupportDirectory: appSupportDirectory
                ).isEmpty
            )
        }
    }

    func testBmuxConfigPathResolverOpensLegacyConfigWhenConfigGhosttyIsEmpty() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let legacyConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config",
                contents: "background = #000000\n"
            )
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: ""
            )

            XCTAssertEqual(
                BmuxGhosttyConfigPathResolver().activeOrEditableConfigURL(
                    currentBundleIdentifier: "com.bmuxterm.app",
                    appSupportDirectory: appSupportDirectory
                ),
                legacyConfigURL
            )
        }
    }

    func testBmuxConfigPathResolverTargetsCurrentConfigGhosttyWhenNoActiveConfigExists() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let expectedURL = appSupportDirectory
                .appendingPathComponent("com.bmuxterm.app.debug.issue-3518", isDirectory: true)
                .appendingPathComponent("config.ghostty", isDirectory: false)

            XCTAssertEqual(
                BmuxGhosttyConfigPathResolver().activeOrEditableConfigURL(
                    currentBundleIdentifier: "com.bmuxterm.app.debug.issue-3518",
                    appSupportDirectory: appSupportDirectory
                ),
                expectedURL
            )
        }
    }

    func testBmuxAppSupportConfigURLsIgnoreMissingOrEmptyFiles() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "com.bmuxterm.app",
                filename: "config.ghostty",
                contents: ""
            )

            XCTAssertTrue(
                GhosttyApp.bmuxAppSupportConfigURLs(
                    currentBundleIdentifier: "com.bmuxterm.app.debug",
                    appSupportDirectory: appSupportDirectory
                ).isEmpty
            )
        }
    }

    func testGhosttySettingsEditorURLsMaterializeBmuxConfigWhenNoConfigExists() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: "com.bmuxterm.app.debug.empty"
            )

            let urls = try environment.materializedGhosttySettingsEditorURLs()
            let expectedConfigURL = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("com.bmuxterm.app.debug.empty", isDirectory: true)
                .appendingPathComponent("config.ghostty", isDirectory: false)
            let expectedPreviewURL = expectedConfigURL
                .deletingLastPathComponent()
                .appendingPathComponent("config.synced-preview", isDirectory: false)

            XCTAssertEqual(urls.map(\.path), [expectedConfigURL.path])
            XCTAssertTrue(FileManager.default.fileExists(atPath: expectedConfigURL.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: expectedPreviewURL.path))
        }
    }

    func testGhosttySettingsEditorURLsIncludeStandaloneAppSupportAndRecursiveConfigFiles() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = FileManager.default
            let appSupportDirectory = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

            let bundleIdentifier = "com.bmuxterm.app.debug.includes"
            let bmuxConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: bundleIdentifier,
                filename: "config.ghostty",
                contents: "theme = bmux\nconfig-file = bmux-include.conf\n"
            )
            let bmuxIncludeURL = bmuxConfigURL
                .deletingLastPathComponent()
                .appendingPathComponent("bmux-include.conf", isDirectory: false)
            try "font-size = 16\n".write(to: bmuxIncludeURL, atomically: true, encoding: .utf8)

            let ghosttyDirectory = homeDirectory
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            let ghosttyIncludeDirectory = ghosttyDirectory.appendingPathComponent("includes", isDirectory: true)
            try fileManager.createDirectory(at: ghosttyIncludeDirectory, withIntermediateDirectories: true)

            let standaloneConfigURL = ghosttyDirectory.appendingPathComponent("config", isDirectory: false)
            try """
            font-size = 14
            config-file = includes/font.conf # shared font config
            config-file = ?missing.conf
            """.write(to: standaloneConfigURL, atomically: true, encoding: .utf8)

            let standaloneIncludeURL = ghosttyIncludeDirectory.appendingPathComponent("font.conf", isDirectory: false)
            try "font-family = Test\n".write(to: standaloneIncludeURL, atomically: true, encoding: .utf8)

            let ghosttyAppSupportDirectory = appSupportDirectory
                .appendingPathComponent("com.mitchellh.ghostty", isDirectory: true)
            try fileManager.createDirectory(at: ghosttyAppSupportDirectory, withIntermediateDirectories: true)
            let ghosttyAppSupportConfigURL = ghosttyAppSupportDirectory
                .appendingPathComponent("config.ghostty", isDirectory: false)
            try "background = #101010\n".write(
                to: ghosttyAppSupportConfigURL,
                atomically: true,
                encoding: .utf8
            )

            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: bundleIdentifier
            )

            let urls = try environment.materializedGhosttySettingsEditorURLs()
            XCTAssertEqual(
                urls.map(\.path),
                [
                    bmuxConfigURL.path,
                    standaloneConfigURL.path,
                    ghosttyAppSupportConfigURL.path,
                    bmuxIncludeURL.path,
                    standaloneIncludeURL.path,
                ]
            )
        }
    }

    private func withTemporaryAppSupportDirectory(
        _ body: (URL) throws -> Void
    ) throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("bmux-app-support-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        try body(directory)
    }

    private func withTemporaryHomeDirectory(
        _ body: (URL) throws -> Void
    ) throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("bmux-home-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        try body(directory)
    }

    private func writeAppSupportConfig(
        appSupportDirectory: URL,
        bundleIdentifier: String,
        filename: String,
        contents: String
    ) throws -> URL {
        let fileManager = FileManager.default
        let bundleDirectory = appSupportDirectory
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

        let configURL = bundleDirectory.appendingPathComponent(filename, isDirectory: false)
        try contents.write(to: configURL, atomically: true, encoding: .utf8)
        return configURL
    }

    private final class RaceCreatingFileManager: FileManager {
        var onFirstMissingPlainExistenceCheck: ((String) throws -> Void)?
        var creationError: Error?
        private var hasRunPlainExistenceHook = false

        override func fileExists(atPath path: String) -> Bool {
            let exists = super.fileExists(atPath: path)
            guard !exists, !hasRunPlainExistenceHook else {
                return exists
            }
            hasRunPlainExistenceHook = true
            do {
                try onFirstMissingPlainExistenceCheck?(path)
            } catch {
                creationError = error
            }
            return exists
        }
    }
}
