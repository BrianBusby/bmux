import SwiftUI
import BmuxAppKitSupportUI
import ProvenanceEngineContracts

struct AgentSessionProposedPlanObservationsView: View {
    let observations: [ProvenanceFactualProposedPlanObservation]
    let isPartial: Bool
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isPartial {
                Text(detail).foregroundStyle(Color(nsColor: MatteTheme.dynamicColor(.textTertiary)))
            }
            if observations.isEmpty {
                Text(String(localized: "agentSession.factual.proposalNone", defaultValue: "No proposal found in scanned records; source availability is unknown."))
                    .foregroundStyle(Color(nsColor: MatteTheme.dynamicColor(.textTertiary)))
            }
            ForEach(observations) { observation in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(observation.timestamp, style: .date)
                        Text(observation.timestamp, style: .time)
                    }
                    .foregroundStyle(Color(nsColor: MatteTheme.dynamicColor(.textTertiary)))
                    HStack {
                        Text(String(localized: "agentSession.factual.proposalSource", defaultValue: "Source:"))
                        Text(observation.proposal.provider)
                        Text(observation.source?.rawValue ?? "")
                        Text(observation.origin?.rawValue ?? "")
                        Text(String(localized: "agentSession.factual.proposalEvidence", defaultValue: "Evidence:"))
                        Text(observation.id).textSelection(.enabled)
                    }
                    .foregroundStyle(Color(nsColor: MatteTheme.dynamicColor(.textTertiary)))
                    Text(observation.proposal.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if observation.proposal.truncated {
                        Text(String(localized: "agentSession.factual.proposalTruncated", defaultValue: "Proposal text was truncated."))
                            .foregroundStyle(Color(nsColor: MatteTheme.dynamicColor(.textTertiary)))
                    }
                }
            }
        }
    }
}
