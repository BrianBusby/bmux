import SwiftUI

struct ExpandedTurnRequestView: View {
    let request: ExpandedTurnRequest
    @State private var showsRaw = false
    @State private var showsFullObjective = false
    @State private var showsFullPrompt = false

    var body: some View {
        ExpandedTurnSection(title: String(localized: "agentSession.expanded.asked", defaultValue: "What was asked")) {
            if let objective = request.objective, request.hasObjective {
                if !request.identical {
                    Text(String(localized: "agentSession.factual.objective", defaultValue: "Objective")).font(.caption).foregroundStyle(.secondary)
                }
                if let replies = request.replies {
                    parsedReplies(replies)
                } else {
                    plain(objective, expanded: $showsFullObjective)
                }
            }
            if let prompt = request.prompt, request.hasPrompt, !request.identical {
                Text(String(localized: "agentSession.factual.prompt", defaultValue: "Prompt")).font(.caption).foregroundStyle(.secondary)
                plain(prompt, expanded: $showsFullPrompt)
            }
            if !request.hasObjective && !request.hasPrompt {
                Text(String(localized: "agentSession.factual.prompt.missing", defaultValue: "No prompt captured"))
                    .foregroundStyle(.secondary)
            } else {
                DisclosureGroup(String(localized: "agentSession.expanded.rawPrompt", defaultValue: "Show raw prompt"), isExpanded: $showsRaw) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let objective = request.objective {
                            rawSource(String(localized: "agentSession.factual.objective", defaultValue: "Objective"), objective)
                        }
                        // Preserve both originals even when only boundary whitespace differs.
                        if let prompt = request.prompt, prompt != request.objective {
                            rawSource(String(localized: "agentSession.factual.prompt", defaultValue: "Prompt"), prompt)
                        }
                    }.padding(10).background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                if request.identical {
                    Text(String(localized: "agentSession.expanded.identical", defaultValue: "The objective and the prompt were identical for this turn, so the text is shown once."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func parsedReplies(_ replies: [ExpandedTurnRequest.Reply]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "agentSession.expanded.type", defaultValue: "Type")).font(.caption).foregroundStyle(.secondary)
                ExpandedTurnEvidenceText(text: "send_user_message_question_reply", monospaced: true)
                    .padding(5).background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            }
            // Request items are immutable, ordered data with no independent disclosure state.
            ForEach(replies.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "agentSession.expanded.question", defaultValue: "Question")).font(.caption).foregroundStyle(.secondary)
                    ExpandedTurnEvidenceText(text: replies[index].question)
                    Text(String(localized: "agentSession.expanded.answer", defaultValue: "Your answer")).font(.caption).foregroundStyle(.secondary)
                    ExpandedTurnEvidenceText(text: replies[index].answer).fontWeight(.semibold)
                }
            }
        }
    }

    private func plain(_ text: String, expanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ExpandedTurnEvidenceText(text: text, lineLimit: expanded.wrappedValue ? nil : 6)
            Button(expanded.wrappedValue
                   ? String(localized: "agentSession.expanded.showLess", defaultValue: "Show less")
                   : String(localized: "agentSession.expanded.showMore", defaultValue: "Show more")) {
                expanded.wrappedValue.toggle()
            }
            .accessibilityValue(expanded.wrappedValue
                ? String(localized: "agentSession.expanded.expanded", defaultValue: "Expanded")
                : String(localized: "agentSession.expanded.collapsed", defaultValue: "Collapsed"))
        }
    }

    private func rawSource(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            ExpandedTurnEvidenceText(text: text, monospaced: true)
        }
    }
}
