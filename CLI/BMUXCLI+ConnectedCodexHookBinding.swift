import Foundation

extension BMUXCLI {
    /// An owned host has no controlling TTY. Never fall back from its exact binding
    /// to another surface when its terminal has moved or closed.
    func connectedCodexHookBindingIsCurrent(client: SocketClient, environment: [String: String]) -> Bool {
        guard environment["BMUX_CODEX_CONNECTED_HOST"] == "1" else { return true }
        guard let workspace = environment["BMUX_WORKSPACE_ID"].flatMap(UUID.init(uuidString:)),
              let surface = environment["BMUX_SURFACE_ID"].flatMap(UUID.init(uuidString:)),
              let result = try? client.sendV2(method: "surface.list", params: ["workspace_id": workspace.uuidString]),
              let surfaces = result["surfaces"] as? [[String: Any]] else { return false }
        return surfaces.contains { ($0["id"] as? String).flatMap(UUID.init(uuidString:)) == surface }
    }
}
