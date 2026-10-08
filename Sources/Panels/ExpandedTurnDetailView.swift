import SwiftUI

struct ExpandedTurnDetailView: View {
    let presentation: ExpandedTurnPresentation
    let commands: [ExpandedTurnCommandRow]
    @Binding var navigation: ExpandedTurnCommandNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ExpandedTurnSection(title: String(localized: "agentSession.factual.finalOutput", defaultValue: "Final output")) {
                if let finalOutput = presentation.finalOutput {
                    ExpandedTurnEvidenceText(text: finalOutput)
                        .padding(14).background(.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Text(presentation.detail == nil
                         ? String(localized: "agentSession.expanded.detailUnavailable", defaultValue: "Detailed evidence is unavailable for this turn.")
                         : String(localized: "agentSession.expanded.noFinal", defaultValue: "No final output recorded."))
                        .foregroundStyle(.secondary)
                }
                if let summary = presentation.summary {
                    Text(String(localized: "agentSession.factual.summaryLabel", defaultValue: "Summary")).font(.caption).foregroundStyle(.secondary)
                    ExpandedTurnEvidenceText(text: summary)
                }
            }
            ExpandedTurnRunView(presentation: presentation)
            ExpandedTurnRequestView(request: presentation.request)
            if presentation.count(presentation.detail?.completedCommands.count) != 0 {
                ExpandedTurnCommandsView(commands: commands, navigation: $navigation)
            }
            DisclosureGroup(String(localized: "agentSession.expanded.referenceIDs", defaultValue: "Reference IDs")) {
                VStack(alignment: .leading, spacing: 12) {
                    ExpandedTurnReferenceRow(label: String(localized: "agentSession.factual.providerTurnID", defaultValue: "Provider turn ID"), value: presentation.reference.providerTurnID)
                    ExpandedTurnReferenceRow(label: String(localized: "agentSession.factual.peTurnID", defaultValue: "PE turn ID"), value: presentation.reference.turnID)
                    if let threadID = presentation.reference.threadID {
                        ExpandedTurnReferenceRow(label: String(localized: "agentSession.factual.peThreadID", defaultValue: "PE thread ID"), value: threadID)
                    }
                }.padding(.top, 8)
            }
        }
        .padding(12)
        .foregroundStyle(Color.workspaceReferenceTextPrimary)
        .background(Color.workspaceReferenceSurface, in: RoundedRectangle(cornerRadius: 6))
        // Session uses the fixed dark workspace palette regardless of system appearance.
        .environment(\.colorScheme, .dark)
    }
}
