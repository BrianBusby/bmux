import SwiftUI

struct ExpandedTurnStatus {
    let raw: String

    var color: Color {
        switch raw.lowercased() {
        case "succeeded", "completed", "success": .green
        case "failed", "error": .red
        case "running", "started", "pending": .orange
        default: .secondary
        }
    }

    var failed: Bool { ["failed", "error"].contains(raw.lowercased()) }
}
