import AppKit
import Carbon.HIToolbox
import CoreFoundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
@Suite
struct FilePreviewSaveShortcutTests {
    @Test
    func savingTextViewUsesConfiguredSaveShortcut() async throws {
        try await verifySave(chord: false)
    }

    @Test
    func savingTextViewUsesChordedSaveShortcut() async throws {
        try await verifySave(chord: true)
    }

    private func verifySave(chord: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { Issue.record(error, "Could not remove owned save-shortcut fixture directory") }
        }
        let url = root.appendingPathComponent("notes.txt")
        try "original".write(to: url, atomically: true, encoding: .utf8)
        let panel = FilePreviewPanel(workspaceId: UUID(), filePath: url.path)
        defer { panel.close() }
        await panel.loadTextContent().value
        #expect(panel.textContent == "original")

        let capture = FilePreviewSaveTaskCapture(panel: panel)
        let textView = SavingTextView.makeFilePreviewTextView()
        try #require(textView.textStorage != nil)
        try #require(textView.textContainer != nil)
        #expect(textView.textLayoutManager == nil)
        let expected = chord ? "saved by chord" : "saved by configured shortcut"
        textView.string = expected
        #expect(textView.string == expected)
        textView.panel = capture
        panel.attachTextView(textView)
        if chord { panel.updateTextContent(textView.string) }

        try dispatchSave(textView: textView, panel: panel, capture: capture, url: url, root: root, chord: chord)
        let task = try #require(capture.task)
        await task.value
        #expect(try String(contentsOf: url, encoding: .utf8) == expected)
        #expect(!panel.isSaving)
    }

    // Restore the legacy process-wide settings owner before awaiting the actual save task.
    private func dispatchSave(
        textView: SavingTextView, panel: FilePreviewPanel, capture: FilePreviewSaveTaskCapture,
        url: URL, root: URL, chord: Bool
    ) throws {
        let defaults = UserDefaults.standard
        let originalStore = KeyboardShortcutSettings.settingsFileStore
        let keys = [
            "bmux.settingsFile.backups.v1", "bmux.settingsFile.importedManagedDefaults.v1",
            SidebarMatchTerminalBackgroundSettings.legacyAppliedSettingsFileDefaultKey,
        ]
        let saved = keys.map {
            CFPreferencesCopyValue($0 as CFString, kCFPreferencesCurrentApplication,
                                   kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        let domains = [UserDefaults.argumentDomain, UserDefaults.registrationDomain]
        let savedDomains = domains.map { defaults.volatileDomain(forName: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            for (name, values) in zip(domains, savedDomains) {
                defaults.setVolatileDomain(values, forName: name)
            }
            KeyboardShortcutSettings.settingsFileStore = originalStore
        }
        for (name, values) in zip(domains, savedDomains) {
            defaults.setVolatileDomain(values.filter { !keys.contains($0.key) }, forName: name)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        var bindings: [String: Any] = Dictionary(uniqueKeysWithValues:
            KeyboardShortcutSettings.Action.allCases.map { ($0.rawValue, NSNull()) }
        )
        bindings[KeyboardShortcutSettings.Action.saveFilePreview.rawValue] = chord ? ["cmd+k", "cmd+s"] : ["cmd+opt+u"]
        let settingsURL = root.appendingPathComponent("bmux.json")
        try JSONSerialization.data(withJSONObject: ["shortcuts": ["bindings": bindings]]).write(to: settingsURL)
        KeyboardShortcutSettings.settingsFileStore = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsURL.path, fallbackPath: nil, additionalFallbackPaths: [],
            notificationCenter: NotificationCenter(), startWatching: false
        )

        let effective = KeyboardShortcutSettings.shortcut(for: .saveFilePreview)
        #expect(effective.hasChord == chord)
        #expect(effective.firstStroke.key == (chord ? "k" : "u"))
        if chord {
            #expect(effective.secondStroke?.key == "s")
            let prefix = try keyEvent("k", code: UInt16(kVK_ANSI_K), modifiers: [.command])
            #expect(textView.performKeyEquivalent(with: prefix))
            #expect(!panel.isSaving)
            #expect(capture.task == nil)
            #expect(try String(contentsOf: url, encoding: .utf8) == "original")
        } else {
            let oldDefault = try keyEvent("s", code: UInt16(kVK_ANSI_S), modifiers: [.command])
            #expect(!textView.performKeyEquivalent(with: oldDefault))
            #expect(capture.task == nil)
            #expect(try String(contentsOf: url, encoding: .utf8) == "original")
        }
        let event = try keyEvent(chord ? "s" : "u", code: UInt16(chord ? kVK_ANSI_S : kVK_ANSI_U),
                                 modifiers: chord ? [.command] : [.command, .option])
        #expect(textView.performKeyEquivalent(with: event))
    }

    private func keyEvent(_ key: String, code: UInt16, modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key,
            isARepeat: false, keyCode: code
        ))
    }
}
