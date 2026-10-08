import SwiftUI

/// Selectable plain evidence. Text(verbatim:) intentionally bypasses Markdown interpretation.
struct ExpandedTurnEvidenceText: View {
    let text: String
    var monospaced = false
    var lineLimit: Int? = nil

    @ScaledMetric(relativeTo: .body) private var bodySize = 15
    @ScaledMetric(relativeTo: .body) private var codeSize = 12

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: monospaced ? codeSize : bodySize, design: monospaced ? .monospaced : .default))
            .textSelection(.enabled)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
