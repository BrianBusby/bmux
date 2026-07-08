import Foundation
import Testing
import BmuxSidebarProviderKit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Regression coverage for the right-click sidebar-button view switcher.
///
/// v0.64.10 shipped seven built-in sidebar views — Default Workspaces plus the
/// Project Worktrees, Attention Queue, Dev Servers, Last Prompt, Super Compact,
/// and Browser Stack presets — that the sidebar-button context menu let users
/// switch between. #4994 ("Replace sidebar extension kit contract") swept that
/// menu behind the experimental Extensions beta flag and stubbed the built-in
/// providers out, so on a default install (beta off) the menu and every one of
/// its views disappeared (https://github.com/manaflow-ai/bmux/issues/5173).
///
/// These tests pin the two guarantees the regression broke: the built-in views
/// are available regardless of the experimental flag, and a selected view
/// resolves to itself (which is what drives the menu's active-view checkmark).
@MainActor
@Suite(.serialized)
struct SidebarProviderMenuRegressionTests {
    /// Stable ids of the seven built-in sidebar views, in menu order.
    private static let builtInViewIDs: [String] = [
        "bmux.sidebar.default",
        "com.example.bmux.sidebar.project-worktrees",
        "com.example.bmux.sidebar.attention-queue",
        "com.example.bmux.sidebar.dev-servers",
        "com.example.bmux.sidebar.last-prompt",
        "com.example.bmux.sidebar.super-compact",
        "com.example.bmux.sidebar.browser-stack",
    ]

    private static let extensionsBetaKey = "extensions.beta.enabled"

    private func withExtensionsBeta(_ enabled: Bool, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: Self.extensionsBetaKey)
        defaults.set(enabled, forKey: Self.extensionsBetaKey)
        defer { restore(previous, forKey: Self.extensionsBetaKey) }
        body()
    }

    private func withSelectedProvider(_ providerId: String, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let key = BmuxExtensionSidebarSelection.defaultsKey
        let previous = defaults.object(forKey: key)
        defaults.set(providerId, forKey: key)
        defer { restore(previous, forKey: key) }
        body()
    }

    private func restore(_ value: Any?, forKey key: String) {
        let defaults = UserDefaults.standard
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// The built-in views must remain selectable even when the experimental
    /// Extensions beta is disabled — the regression hid every one of them.
    @Test
    func builtInViewsAvailableWhenExtensionsBetaDisabled() {
        withExtensionsBeta(false) {
            let availableIDs = Set(BmuxExtensionSidebarSelection.descriptors.map(\.id))
            for builtInID in Self.builtInViewIDs {
                #expect(
                    availableIDs.contains(builtInID),
                    "Built-in sidebar view \(builtInID) is missing from the switcher menu"
                )
            }
        }
    }

    /// Persisting a built-in view as the selection drives the menu's active-view
    /// checkmark to that view. This exercises the same path `showMenu` uses to
    /// decide which item is checked — read the persisted id from `UserDefaults`,
    /// resolve it through `effectiveProviderId`, then look up the descriptor —
    /// rather than asserting on the id in isolation.
    @Test
    func persistedBuiltInSelectionDrivesMenuCheckmark() {
        withExtensionsBeta(false) {
            for builtInID in Self.builtInViewIDs {
                withSelectedProvider(builtInID) {
                    let persisted = UserDefaults.standard.string(forKey: BmuxExtensionSidebarSelection.defaultsKey)
                        ?? BmuxExtensionSidebarSelection.defaultProviderId
                    let effective = BmuxExtensionSidebarSelection.effectiveProviderId(
                        persisted,
                        extensionsEnabled: BmuxExtensionSidebarSelection.isEnabled
                    )
                    let checkedID = BmuxExtensionSidebarSelection.descriptor(for: effective).id
                    #expect(
                        checkedID == builtInID,
                        "Persisted selection \(builtInID) did not drive the menu checkmark (got \(checkedID))"
                    )
                }
            }
        }
    }

    /// The hosted-extensions provider belongs to the experimental Extensions
    /// feature, so the effective selection (which the menu checkmark tracks)
    /// downgrades it to the default sidebar while the beta is off and honors it
    /// while the beta is on. Built-in views resolve to themselves either way —
    /// they are never gated by the flag.
    @Test
    func effectiveSelectionGatesHostedExtensionButNotBuiltInViews() {
        let projectWorktrees = "com.example.bmux.sidebar.project-worktrees"
        #expect(
            BmuxExtensionSidebarSelection.effectiveProviderId(projectWorktrees, extensionsEnabled: false) == projectWorktrees
        )
        #expect(
            BmuxExtensionSidebarSelection.effectiveProviderId(projectWorktrees, extensionsEnabled: true) == projectWorktrees
        )

        let hosted = BmuxExtensionSidebarSelection.hostedExtensionsProviderId
        #expect(
            BmuxExtensionSidebarSelection.effectiveProviderId(hosted, extensionsEnabled: true) == hosted
        )
        #expect(
            BmuxExtensionSidebarSelection.effectiveProviderId(hosted, extensionsEnabled: false) == BmuxExtensionSidebarSelection.defaultProviderId
        )
    }

    /// The host renders the selected view through an
    /// `any BmuxSidebarProvider` existential
    /// (`BmuxExtensionSidebarSelection.provider(for:)?.render(snapshot:)`).
    /// `render(snapshot:)` must dynamic-dispatch to the concrete view; if it
    /// instead hits the empty protocol-extension default, every built-in view
    /// renders an empty sidebar even though the provider and workspaces are
    /// present — the second half of #5173. Super Compact lists every workspace
    /// in one section, so its rows must equal the workspace count.
    @Test
    func builtInProviderRendersRowsThroughHostExistential() {
        let snapshot = Self.populatedSnapshot(workspaceCount: 3)
        let provider = BmuxExtensionSidebarSelection.provider(for: "com.example.bmux.sidebar.super-compact")
        #expect(provider != nil, "Super Compact provider should be registered")
        let model = provider?.render(snapshot: snapshot)
        #expect(
            (model?.sections.flatMap(\.rows).count ?? 0) == 3,
            "Selected view rendered no rows through the host existential (empty-sidebar regression)"
        )
    }

    /// `VerticalTabsSidebar.body` decides whether to show the default workspaces
    /// sidebar or an extension sidebar on every render. It used to do that with
    /// `descriptor(for:).id == defaultWorkspacesID`, which rebuilds the full
    /// `descriptors` list — constructing a `SettingCatalog` twice and scanning
    /// the custom-sidebars directory — on every body pass. That per-pass cost was
    /// the multiplier behind the sustained ~100% CPU re-render loop in #5970.
    /// `resolvesToDefaultSidebar(effectiveProviderId:)` is the cheap replacement;
    /// these tests pin that it routes identically to the old descriptor lookup
    /// for every effective selection.
    @Test
    func resolvesToDefaultSidebarMatchesDescriptorRoutingForBuiltInViews() {
        for betaEnabled in [false, true] {
            withExtensionsBeta(betaEnabled) {
                for builtInID in Self.builtInViewIDs {
                    let cheap = BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(effectiveProviderId: builtInID)
                    let viaDescriptor = BmuxExtensionSidebarSelection.descriptor(for: builtInID).id
                        == BmuxSidebarProviderDescriptor.defaultWorkspacesID
                    #expect(
                        cheap == viaDescriptor,
                        "Routing mismatch for \(builtInID) (extensionsBeta=\(betaEnabled)): cheap=\(cheap) descriptor=\(viaDescriptor)"
                    )
                }
                // The default view routes to the workspaces sidebar; every bundled
                // preset routes to an extension sidebar.
                #expect(
                    BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(
                        effectiveProviderId: BmuxExtensionSidebarSelection.defaultProviderId
                    )
                )
                for presetID in Self.builtInViewIDs.dropFirst() {
                    #expect(
                        !BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(effectiveProviderId: presetID),
                        "Bundled preset \(presetID) must route to an extension sidebar, not the default"
                    )
                }
            }
        }
    }

    /// The hosted-extensions provider only appears in `effectiveProviderId`'s
    /// output while the Extensions beta is on, and then it must route to an
    /// extension sidebar (not the default). Matches the descriptor lookup.
    @Test
    func resolvesToDefaultSidebarRoutesHostedExtensionToExtensionSidebar() {
        withExtensionsBeta(true) {
            let hosted = BmuxExtensionSidebarSelection.hostedExtensionsProviderId
            #expect(!BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(effectiveProviderId: hosted))
            #expect(
                BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(effectiveProviderId: hosted)
                    == (BmuxExtensionSidebarSelection.descriptor(for: hosted).id
                        == BmuxSidebarProviderDescriptor.defaultWorkspacesID)
            )
        }
    }

    /// An unknown/stale provider id (e.g. a deleted custom sidebar) has no
    /// renderable provider, so routing falls back to the default workspaces
    /// sidebar — exactly as `descriptor(for:)`'s `?? .defaultWorkspaces` did.
    @Test
    func resolvesToDefaultSidebarFallsBackForUnknownProvider() {
        withExtensionsBeta(true) {
            let unknown = "com.example.bmux.sidebar.does-not-exist-\(UUID().uuidString)"
            #expect(BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(effectiveProviderId: unknown))
            #expect(
                BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(effectiveProviderId: unknown)
                    == (BmuxExtensionSidebarSelection.descriptor(for: unknown).id
                        == BmuxSidebarProviderDescriptor.defaultWorkspacesID)
            )

            // A custom-prefixed selection whose backing file does not exist also
            // falls back to the default sidebar.
            let missingCustom = BmuxExtensionSidebarSelection.customSidebarProviderPrefix
                + "missing-\(UUID().uuidString)"
            #expect(BmuxExtensionSidebarSelection.resolvesToDefaultSidebar(effectiveProviderId: missingCustom))
        }
    }

    /// Custom provider ids are persisted strings, so the fast path must keep the
    /// old descriptor enumeration boundary: only files directly inside the
    /// sidebars directory are renderable.
    @Test
    func customSidebarFileURLRejectsPathTraversalProviderIds() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-custom-sidebar-test-\(UUID().uuidString)", isDirectory: true)
        let sidebarsDirectory = root.appendingPathComponent("sidebars", isDirectory: true)
        try FileManager.default.createDirectory(at: sidebarsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let validName = "valid-\(UUID().uuidString)"
        let validURL = sidebarsDirectory.appendingPathComponent("\(validName).swift", isDirectory: false)
        try Data().write(to: validURL)
        #expect(
            BmuxExtensionSidebarSelection.customSidebarFileURL(
                forProviderId: BmuxExtensionSidebarSelection.customSidebarProviderPrefix + validName,
                sidebarsDirectory: sidebarsDirectory
            ) == validURL
        )

        let escapedName = "outside-\(UUID().uuidString)"
        let escapedURL = root.appendingPathComponent("\(escapedName).swift", isDirectory: false)
        try Data().write(to: escapedURL)
        #expect(
            BmuxExtensionSidebarSelection.customSidebarFileURL(
                forProviderId: BmuxExtensionSidebarSelection.customSidebarProviderPrefix + "../\(escapedName)",
                sidebarsDirectory: sidebarsDirectory
            ) == nil
        )
    }

    private static func populatedSnapshot(workspaceCount: Int) -> BmuxSidebarProviderSnapshot {
        let workspaces = (0..<workspaceCount).map { index in
            BmuxSidebarProviderWorkspace(
                id: UUID(),
                title: "Workspace \(index)",
                customDescription: nil,
                isPinned: false,
                rootPath: "/tmp/ws\(index)",
                projectRootPath: "/tmp/ws\(index)",
                branchSummary: "main",
                remoteDisplayTarget: nil,
                remoteConnectionState: "disconnected",
                unreadCount: 0,
                latestNotificationText: nil,
                listeningPorts: []
            )
        }
        return BmuxSidebarProviderSnapshot(
            sequence: 1,
            selectedWorkspaceId: nil,
            workspaces: workspaces
        )
    }
}
