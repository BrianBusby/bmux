import Foundation

@MainActor
final class AgentSessionWebRendererSession {
    private let ownedCoordinator: AgentSessionWebRendererCoordinator

    init(workProvenanceRuntime: WorkProvenanceRuntime? = nil) {
        self.ownedCoordinator = AgentSessionWebRendererCoordinator(
            workProvenanceRuntime: workProvenanceRuntime
        )
    }

    var onHasActiveProviderChanged: ((Bool) -> Void)? {
        didSet {
            ownedCoordinator.onHasActiveProviderChanged = onHasActiveProviderChanged
        }
    }
    var onHasActiveWorkChanged: ((Bool) -> Void)? {
        didSet {
            ownedCoordinator.onHasActiveWorkChanged = onHasActiveWorkChanged
        }
    }
    var onProviderIDChanged: ((AgentSessionProviderID) -> Void)? {
        didSet {
            ownedCoordinator.onProviderIDChanged = onProviderIDChanged
        }
    }

    func coordinator(
        panelId: UUID,
        workspaceId: UUID,
        rendererKind: AgentSessionRendererKind,
        initialProviderID: AgentSessionProviderID,
        workingDirectory: String?,
        theme: AgentSessionWebTheme,
        isFocused: Bool
    ) -> AgentSessionWebRendererCoordinator {
        ownedCoordinator.bind(
            panelId: panelId,
            workspaceId: workspaceId,
            rendererKind: rendererKind,
            initialProviderID: initialProviderID,
            workingDirectory: workingDirectory,
            theme: theme,
            isFocused: isFocused
        )
        return ownedCoordinator
    }

    func focus() {
        ownedCoordinator.focus()
    }

    func unfocus() {
        ownedCoordinator.unfocus()
    }

    func close() {
        ownedCoordinator.close()
    }
}
