import AppKit
import BmuxAppKitSupportUI
import BmuxFoundation
import SwiftUI
import XCTest

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

final class SidebarWidthPolicyTests: XCTestCase {
    private let settingsFileBackupsDefaultsKey = "bmux.settingsFile.backups.v1"
    private let importedManagedDefaultsKey = "bmux.settingsFile.importedManagedDefaults.v1"

    func testDefaultMinimumSidebarWidthIsPersistedProductDefault() {
        let suiteName = "SidebarWidthPolicyTests.defaultMinimum.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(
            SessionPersistencePolicy.defaultMinimumSidebarWidth,
            240,
            accuracy: 0.001
        )
        XCTAssertEqual(
            SessionPersistencePolicy.resolvedMinimumSidebarWidth(defaults: defaults),
            240,
            accuracy: 0.001
        )
    }

    func testContentViewClampKeepsMinimumSidebarWidth() {
        XCTAssertEqual(
            ContentView.clampedSidebarWidth(184, maximumWidth: 600),
            CGFloat(SessionPersistencePolicy.minimumSidebarWidth),
            accuracy: 0.001
        )
    }

    func testContentViewClampCanUseSmallerConfiguredMinimumSidebarWidth() {
        XCTAssertEqual(
            ContentView.clampedSidebarWidth(184, maximumWidth: 600, minimumWidth: 160),
            184,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ContentView.clampedSidebarWidth(140, maximumWidth: 600, minimumWidth: 160),
            160,
            accuracy: 0.001
        )
    }

    func testSessionPersistenceReadsConfiguredMinimumSidebarWidth() {
        let suiteName = "SidebarWidthPolicyTests.minimumSidebarWidth.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(160.0, forKey: SessionPersistencePolicy.sidebarMinimumWidthKey)
        XCTAssertEqual(
            SessionPersistencePolicy.sanitizedSidebarWidth(140, defaults: defaults),
            160,
            accuracy: 0.001
        )
        XCTAssertEqual(
            SessionPersistencePolicy.sanitizedSidebarWidth(184, defaults: defaults),
            184,
            accuracy: 0.001
        )
    }

    func testRightSidebarClampAllowsWideExplorerOnLargeWindows() {
        XCTAssertEqual(
            ContentView.clampedRightSidebarWidth(900, availableWidth: 1600),
            900,
            accuracy: 0.001
        )
    }

    func testRightSidebarFirstCustomMaximumMatchesBuiltInCap() {
        XCTAssertEqual(
            ContentView.clampedRightSidebarWidth(10_000, availableWidth: 10_000),
            CGFloat(RightSidebarWidthSettings.defaultConfiguredMaximumWidth),
            accuracy: 0.001
        )
    }

    func testRightSidebarClampLeavesTerminalWidthWhenMaxWidthSettingIsMissing() {
        XCTAssertEqual(
            ContentView.clampedRightSidebarWidth(10_000, availableWidth: 1000),
            640,
            accuracy: 0.001
        )
    }

    func testRightSidebarConfiguredMaxCanExceedBuiltInDefaultOnWideWindows() {
        XCTAssertEqual(
            ContentView.clampedRightSidebarWidth(
                10_000,
                availableWidth: 2400,
                configuredMaximumWidth: 1_500
            ),
            1_500,
            accuracy: 0.001
        )
    }

    func testRightSidebarConfiguredMaxStillLeavesTerminalWidth() {
        XCTAssertEqual(
            ContentView.clampedRightSidebarWidth(
                10_000,
                availableWidth: 1000,
                configuredMaximumWidth: 1_400
            ),
            640,
            accuracy: 0.001
        )
    }

    func testRightSidebarConfiguredMaxBelowMinimumClampsToMinimumWidth() {
        XCTAssertEqual(
            ContentView.clampedRightSidebarWidth(
                10_000,
                availableWidth: 1000,
                configuredMaximumWidth: 120
            ),
            276,
            accuracy: 0.001
        )
    }

    func testRightSidebarClampKeepsMinimumWidth() {
        XCTAssertEqual(
            ContentView.clampedRightSidebarWidth(20, availableWidth: 1000),
            276,
            accuracy: 0.001
        )
    }

    func testSettingsFileStoreAppliesRightSidebarMaxWidthSetting() throws {
        let defaults = UserDefaults.standard
        let managedKey = RightSidebarWidthSettings.maxWidthKey
        let previousValues = [
            managedKey,
            settingsFileBackupsDefaultsKey,
            importedManagedDefaultsKey,
        ].reduce(into: [String: Any]()) { values, key in
            values[key] = defaults.object(forKey: key)
        }
        defer {
            for key in [managedKey, settingsFileBackupsDefaultsKey, importedManagedDefaultsKey] {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.removeObject(forKey: managedKey)
        defaults.removeObject(forKey: settingsFileBackupsDefaultsKey)
        defaults.removeObject(forKey: importedManagedDefaultsKey)

        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "right-sidebar-width-settings-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("bmux.json", isDirectory: false)
        try """
        {
          "sidebar": {
            "rightMaxWidth": 900
          }
        }
        """.write(to: settingsFileURL, atomically: true, encoding: .utf8)

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            startWatching: false
        )

        XCTAssertEqual(defaults.double(forKey: managedKey), 900, accuracy: 0.001)
        let configuredMaximumWidth = try XCTUnwrap(
            RightSidebarWidthSettings().configuredMaximumWidth(from: defaults.double(forKey: managedKey))
        )
        XCTAssertEqual(configuredMaximumWidth, 900, accuracy: 0.001)
    }

    func testSettingsFileStoreClampsRightSidebarMaxWidthSetting() throws {
        let defaults = UserDefaults.standard
        let managedKey = RightSidebarWidthSettings.maxWidthKey
        let previousValues = [
            managedKey,
            settingsFileBackupsDefaultsKey,
            importedManagedDefaultsKey,
        ].reduce(into: [String: Any]()) { values, key in
            values[key] = defaults.object(forKey: key)
        }
        defer {
            for key in [managedKey, settingsFileBackupsDefaultsKey, importedManagedDefaultsKey] {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.removeObject(forKey: managedKey)
        defaults.removeObject(forKey: settingsFileBackupsDefaultsKey)
        defaults.removeObject(forKey: importedManagedDefaultsKey)

        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "right-sidebar-width-settings-clamped-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("bmux.json", isDirectory: false)
        try """
        {
          "sidebar": {
            "rightMaxWidth": 10000
          }
        }
        """.write(to: settingsFileURL, atomically: true, encoding: .utf8)

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            startWatching: false
        )

        XCTAssertEqual(
            defaults.double(forKey: managedKey),
            RightSidebarWidthSettings.settingsEditorMaximumWidth,
            accuracy: 0.001
        )
        let configuredMaximumWidth = try XCTUnwrap(
            RightSidebarWidthSettings().configuredMaximumWidth(from: defaults.double(forKey: managedKey))
        )
        XCTAssertEqual(
            configuredMaximumWidth,
            RightSidebarWidthSettings.settingsEditorMaximumWidth,
            accuracy: 0.001
        )
    }

    func testLeadingSidebarResizeRangeFavorsSidebarSide() {
        let range = SidebarResizeInteraction.Edge.leading.hitRange(dividerX: 200)

        XCTAssertEqual(range.lowerBound, 194, accuracy: 0.001)
        XCTAssertEqual(range.upperBound, 204, accuracy: 0.001)
        XCTAssertTrue(range.contains(196))
        XCTAssertTrue(range.contains(202))
        XCTAssertFalse(range.contains(193.9))
        XCTAssertFalse(range.contains(204.1))
    }

    func testTrailingSidebarResizeRangeFavorsSidebarSide() {
        let range = SidebarResizeInteraction.Edge.trailing.hitRange(dividerX: 680)

        XCTAssertEqual(range.lowerBound, 676, accuracy: 0.001)
        XCTAssertEqual(range.upperBound, 686, accuracy: 0.001)
        XCTAssertTrue(range.contains(678))
        XCTAssertTrue(range.contains(684))
        XCTAssertFalse(range.contains(675.9))
        XCTAssertFalse(range.contains(686.1))
    }
}

final class SidebarWorkspaceSelectionColorTests: XCTestCase {
    func testSelectedWorkspaceRowsKeepUnselectedBackgroundInLightAndDark() {
        for colorScheme in [ColorScheme.light, .dark] {
            let coloredSelected = sidebarWorkspaceRowBackgroundStyle(
                activeTabIndicatorStyle: .solidFill,
                isActive: true,
                isMultiSelected: false,
                customColorHex: "#E85D75",
                colorScheme: colorScheme,
                sidebarSelectionColorHex: nil
            )
            let standardSelected = sidebarWorkspaceRowBackgroundStyle(
                activeTabIndicatorStyle: .solidFill,
                isActive: true,
                isMultiSelected: false,
                customColorHex: nil,
                colorScheme: colorScheme,
                sidebarSelectionColorHex: nil
            )

            XCTAssertEqual(coloredSelected.opacity, 0.46, accuracy: 0.001)
            XCTAssertNotNil(coloredSelected.color)
            XCTAssertEqual(standardSelected.opacity, 0, accuracy: 0.001)
            XCTAssertNil(standardSelected.color)

            let unselectedColored = sidebarWorkspaceRowBackgroundStyle(
                activeTabIndicatorStyle: .solidFill,
                isActive: false,
                isMultiSelected: false,
                customColorHex: "#E85D75",
                colorScheme: colorScheme,
                sidebarSelectionColorHex: nil
            )
            XCTAssertEqual(unselectedColored.opacity, 0.46, accuracy: 0.001)
            XCTAssertNotNil(unselectedColored.color)
            assertColor(coloredSelected.color, equals: unselectedColored.color)
        }
    }

    func testSelectedWorkspaceIgnoresConfiguredSelectionFillColor() {
        let selectionHex = "#123456"
        let coloredSelected = sidebarWorkspaceRowBackgroundStyle(
            activeTabIndicatorStyle: .solidFill,
            isActive: true,
            isMultiSelected: false,
            customColorHex: "#E85D75",
            colorScheme: .light,
            sidebarSelectionColorHex: selectionHex
        )
        let standardSelected = sidebarWorkspaceRowBackgroundStyle(
            activeTabIndicatorStyle: .solidFill,
            isActive: true,
            isMultiSelected: false,
            customColorHex: nil,
            colorScheme: .light,
            sidebarSelectionColorHex: selectionHex
        )

        XCTAssertEqual(coloredSelected.opacity, 0.46, accuracy: 0.001)
        assertColor(coloredSelected.color, equals: NSColor(hex: "#E85D75"))
        XCTAssertEqual(standardSelected.opacity, 0, accuracy: 0.001)
        XCTAssertNil(standardSelected.color)
    }

    func testDefaultSelectedForegroundFallsBackForPaleSelectionBackground() throws {
        let background = try XCTUnwrap(NSColor(hex: "#F7F7F7"))
        let foreground = sidebarSelectedWorkspaceForegroundNSColor(
            on: background,
            opacity: 1.0
        )

        assertColor(foreground, equals: .black)
        XCTAssertGreaterThanOrEqual(
            bmuxContrastRatio(foreground: foreground, background: background),
            4.5
        )
    }

    func testSelectedForegroundPrefersWhiteForSaturatedSelectionBackground() throws {
        let background = try XCTUnwrap(NSColor(hex: "#0088FF"))
        let foreground = sidebarSelectedWorkspaceForegroundNSColor(
            on: background,
            opacity: 1.0
        )

        assertColor(foreground, equals: .white)
        XCTAssertGreaterThanOrEqual(
            bmuxContrastRatio(foreground: foreground, background: background),
            3.0
        )
    }

    func testSelectedForegroundKeepsWhiteForStandardInactiveSelectionBlue() throws {
        let background = try XCTUnwrap(NSColor(hex: "#6795F5"))
        let foreground = sidebarSelectedWorkspaceForegroundNSColor(
            on: background,
            opacity: 0.75
        )

        assertColor(foreground, equals: NSColor.white.withAlphaComponent(0.75))
    }

    func testWorkspaceLoadingIndicatorUsesBlackOnClearLightRows() {
        let foreground = sidebarWorkspaceRowLoadingIndicatorNSColor(
            activeTabIndicatorStyle: .leftRail,
            isActive: false,
            isMultiSelected: false,
            customColorHex: nil,
            colorScheme: .light,
            sidebarSelectionColorHex: nil
        )

        assertColor(foreground, equals: .black)
    }

    func testWorkspaceLoadingIndicatorUsesWhiteOnClearDarkRows() {
        let foreground = sidebarWorkspaceRowLoadingIndicatorNSColor(
            activeTabIndicatorStyle: .leftRail,
            isActive: false,
            isMultiSelected: false,
            customColorHex: nil,
            colorScheme: .dark,
            sidebarSelectionColorHex: nil
        )

        assertColor(foreground, equals: .white)
    }

    func testWorkspaceLoadingIndicatorUsesRepoColorForSelectedRows() throws {
        let selectionBackground = try XCTUnwrap(NSColor(hex: "#F7F7F7"))
        let foreground = sidebarWorkspaceRowLoadingIndicatorNSColor(
            activeTabIndicatorStyle: .solidFill,
            isActive: true,
            isMultiSelected: false,
            customColorHex: "#E85D75",
            colorScheme: .light,
            sidebarSelectionColorHex: selectionBackground.hexString(),
            baseBackgroundColor: .white
        )
        let style = sidebarWorkspaceRowBackgroundStyle(
            activeTabIndicatorStyle: .solidFill,
            isActive: true,
            isMultiSelected: false,
            customColorHex: "#E85D75",
            colorScheme: .light,
            sidebarSelectionColorHex: selectionBackground.hexString()
        )
        let effectiveBackground = bmuxCompositedNSColor(
            try XCTUnwrap(style.color).withAlphaComponent(CGFloat(style.opacity)),
            over: .white
        )

        assertColor(foreground, equals: .black)
        XCTAssertGreaterThan(
            bmuxContrastRatio(foreground: foreground, background: effectiveBackground),
            bmuxContrastRatio(foreground: .white, background: effectiveBackground)
        )
    }

    func testWorkspaceLoadingIndicatorUsesBaseBackgroundForSelectedRows() throws {
        let selectionBackground = try XCTUnwrap(NSColor(hex: "#123456"))
        let foreground = sidebarWorkspaceRowLoadingIndicatorNSColor(
            activeTabIndicatorStyle: .solidFill,
            isActive: true,
            isMultiSelected: false,
            customColorHex: nil,
            colorScheme: .light,
            sidebarSelectionColorHex: selectionBackground.hexString(),
            baseBackgroundColor: .white
        )

        assertColor(foreground, equals: .black)
        XCTAssertGreaterThan(
            bmuxContrastRatio(foreground: foreground, background: .white),
            bmuxContrastRatio(foreground: .white, background: .white)
        )
    }

    func testWorkspaceLoadingIndicatorTabSizeIsSlightlyLargerThanUnreadBadge() {
        XCTAssertEqual(
            TronLoadingIndicatorMotion.workspaceTabSize(forBadgeSize: 16),
            18,
            accuracy: 0.001
        )
    }

    func testWorkspaceLoadingIndicatorOrbitMaintainsTangentContactAtHandoffs() {
        let motion = TronLoadingIndicatorMotion(contactSeparationTurns: 0.06)

        XCTAssertEqual(
            motion.phaseSeparation(atElapsedTime: 0),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            motion.phaseSeparation(atElapsedTime: 0.75),
            0.06,
            accuracy: 0.001
        )
        XCTAssertEqual(
            motion.phaseSeparation(atElapsedTime: 1.5),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            motion.phaseSeparation(atElapsedTime: 2.25),
            0.94,
            accuracy: 0.001
        )
        XCTAssertEqual(
            motion.phaseSeparation(atElapsedTime: 3.0),
            0.5,
            accuracy: 0.001
        )
    }

    func testWorkspaceLoadingIndicatorOrbitSwapsFastAndSlowRingsAfterImpact() {
        let motion = TronLoadingIndicatorMotion(contactSeparationTurns: 0.06)
        let beforeImpactStart = motion.phases(atElapsedTime: 0.65)
        let beforeImpactEnd = motion.phases(atElapsedTime: 0.70)
        let afterImpactStart = motion.phases(atElapsedTime: 0.80)
        let afterImpactEnd = motion.phases(atElapsedTime: 0.85)

        XCTAssertGreaterThan(
            motion.forwardDistance(from: beforeImpactStart.first, to: beforeImpactEnd.first),
            motion.forwardDistance(from: beforeImpactStart.second, to: beforeImpactEnd.second)
        )
        XCTAssertLessThan(
            motion.forwardDistance(from: afterImpactStart.first, to: afterImpactEnd.first),
            motion.forwardDistance(from: afterImpactStart.second, to: afterImpactEnd.second)
        )
    }

    func testTitlebarControlForegroundContrastsWithLightTerminalBackground() throws {
        let background = try XCTUnwrap(NSColor(hex: "#F7F7F7"))
        let snapshot = makeWindowAppearanceSnapshot(background: background)
        let foreground = titlebarControlForegroundNSColor(
            opacity: 1.0,
            appearance: snapshot
        )

        assertColor(foreground, equals: .black)
        XCTAssertGreaterThanOrEqual(
            bmuxContrastRatio(
                foreground: foreground,
                background: snapshot.compositedTerminalBackgroundColor
            ),
            4.5
        )
    }

    private func assertColor(
        _ actual: NSColor?,
        equals expected: NSColor?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual, let expected else {
            XCTAssertNotNil(actual, file: file, line: line)
            XCTAssertNotNil(expected, file: file, line: line)
            return
        }

        XCTAssertTrue(
            colorsAreEqual(actual, expected),
            "Expected \(colorDescription(actual)) to equal \(colorDescription(expected))",
            file: file,
            line: line
        )
    }

    private func makeWindowAppearanceSnapshot(background: NSColor) -> WindowAppearanceSnapshot {
        WindowAppearanceSnapshot(
            terminalBackgroundColor: background,
            terminalBackgroundOpacity: 1.0,
            terminalBackgroundBlur: .disabled,
            terminalRenderingMode: .windowHostBackdrop,
            unifySurfaceBackdrops: true,
            sidebarSettings: SidebarBackdropSettingsSnapshot(
                materialRawValue: SidebarMaterialOption.sidebar.rawValue,
                blendModeRawValue: SidebarBlendModeOption.withinWindow.rawValue,
                stateRawValue: SidebarStateOption.followWindow.rawValue,
                tintHex: SidebarTintDefaults().hex,
                tintHexLight: nil,
                tintHexDark: nil,
                tintOpacity: SidebarTintDefaults().opacity,
                cornerRadius: 0,
                blurOpacity: 1,
                colorScheme: .light
            ),
            windowGlassSettings: WindowGlassSettingsSnapshot(
                sidebarBlendModeRawValue: SidebarBlendModeOption.withinWindow.rawValue,
                isEnabled: false,
                tintHex: "#000000",
                tintOpacity: 0,
                terminalBackgroundBlur: .disabled,
                terminalGlassTintColor: background
            )
        )
    }

    private func colorsAreEqual(_ lhs: NSColor?, _ rhs: NSColor?) -> Bool {
        guard let lhs, let rhs else {
            return lhs == nil && rhs == nil
        }
        guard let lhsRGB = lhs.usingColorSpace(.sRGB),
              let rhsRGB = rhs.usingColorSpace(.sRGB) else {
            return false
        }

        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0
        lhsRGB.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha)
        rhsRGB.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha)

        return abs(lhsRed - rhsRed) <= 0.001 &&
            abs(lhsGreen - rhsGreen) <= 0.001 &&
            abs(lhsBlue - rhsBlue) <= 0.001 &&
            abs(lhsAlpha - rhsAlpha) <= 0.001
    }

    private func colorDescription(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return color.description
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "rgba(%.3f, %.3f, %.3f, %.3f)",
            red,
            green,
            blue,
            alpha
        )
    }
}
