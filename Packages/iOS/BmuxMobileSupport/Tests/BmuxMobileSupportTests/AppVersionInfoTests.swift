import Testing
@testable import BmuxMobileSupport

@Suite struct AppVersionInfoTests {
    @Test func releaseShowsCleanVersionWithBuildNumber() {
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "20260607031606",
                "BMUXDevTag": "",
                "BMUXGitSHA": "",
            ],
            isDevBuild: false
        )
        #expect(info.displayString == "1.0.0 (20260607031606)")
    }

    @Test func releaseIgnoresDevMetadataEvenIfPresent() {
        // A release build must never leak a tag/SHA, even if the keys carry
        // values: isDevBuild gates the suffix, not just empty strings.
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "123",
                "BMUXDevTag": "grid",
                "BMUXGitSHA": "a1b2c3d",
            ],
            isDevBuild: false
        )
        #expect(info.displayString == "1.0.0 (123)")
    }

    @Test func devAppendsTagAndSHA() {
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "123",
                "BMUXDevTag": "grid",
                "BMUXGitSHA": "a1b2c3d",
            ],
            isDevBuild: true
        )
        #expect(info.displayString == "1.0.0 (123) · grid · a1b2c3d")
    }

    @Test func devWithDirtyTreeMarkerIsPreserved() {
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "123",
                "BMUXDevTag": "grid",
                "BMUXGitSHA": "a1b2c3d+",
            ],
            isDevBuild: true
        )
        #expect(info.displayString == "1.0.0 (123) · grid · a1b2c3d+")
    }

    @Test func devWithOnlyTagOmitsSHASeparator() {
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "123",
                "BMUXDevTag": "grid",
                "BMUXGitSHA": "",
            ],
            isDevBuild: true
        )
        #expect(info.displayString == "1.0.0 (123) · grid")
    }

    @Test func devWithNoTagOrSHAFallsBackToBase() {
        // A dev build run outside reload.sh (no overrides) still renders cleanly.
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
                "BMUXDevTag": "",
                "BMUXGitSHA": "",
            ],
            isDevBuild: true
        )
        #expect(info.displayString == "1.0.0 (1)")
    }

    @Test func unexpandedBuildSettingPlaceholdersAreTreatedAsEmpty() {
        // If the keys were never overridden, Info.plist substitution leaves the
        // raw "$(BMUX_GIT_SHA)" macro; it must not surface to the user.
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "123",
                "BMUXDevTag": "$(BMUX_DEV_TAG)",
                "BMUXGitSHA": "$(BMUX_GIT_SHA)",
            ],
            isDevBuild: true
        )
        #expect(info.displayString == "1.0.0 (123)")
    }

    @Test func missingBuildNumberOmitsParentheses() {
        let info = AppVersionInfo(
            infoDictionary: ["CFBundleShortVersionString": "1.0.0"],
            isDevBuild: false
        )
        #expect(info.displayString == "1.0.0")
    }

    @Test func missingMarketingVersionFallsBack() {
        let info = AppVersionInfo(infoDictionary: nil, isDevBuild: false)
        #expect(info.marketingVersion == "0.0.0")
        #expect(info.displayString == "0.0.0")
    }
}
