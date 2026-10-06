import BmuxMobileShellModel
import BmuxMobileSupport
import SwiftUI

struct WorkspaceRow: View {
    let workspace: MobileWorkspacePreview
    let isSelected: Bool
    var closeWorkspace: (() -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ticketInfoBlock

            if hasSessionDetails {
                Rectangle()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 4) {
                    if let lastPrompt = workspace.lastPrompt, !lastPrompt.isEmpty {
                        Text(lastPrompt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let branchLine {
                        Text(branchLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.2),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var ticketInfoBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(workspace.ticketTitle ?? workspace.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)

                if let closeWorkspace {
                    Button(action: closeWorkspace) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("mobile.workspace.close.action", defaultValue: "Close Workspace"))
                }
            }

            if let ticketID = workspace.ticketID, !ticketID.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "ticket")
                    Text(ticketID)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .overlay(Capsule().stroke(Color.secondary.opacity(0.28), lineWidth: 1))
                .fixedSize()
            }

            if let projectTitle = workspace.projectTitle, !projectTitle.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(projectTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .font(.body)
            }

            if let summary = workspace.workSummary ?? workspace.previewText, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if hasPullRequest {
                Button {
                    if let pullRequestURL = workspace.pullRequestURL {
                        openURL(pullRequestURL)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.secondary)
                        Text(pullRequestText)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.body)
                }
                .buttonStyle(.plain)
                .disabled(workspace.pullRequestURL == nil)
            }

            if workspace.ownerName != nil || workspace.ownerAvatarURL != nil {
                HStack(spacing: 8) {
                    WorkspaceOwnerAvatar(name: workspace.ownerName, url: workspace.ownerAvatarURL)
                    if let ownerName = workspace.ownerName, !ownerName.isEmpty {
                        Text(ownerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var hasPullRequest: Bool {
        workspace.pullRequestNumber != nil || workspace.pullRequestTitle != nil
    }

    private var pullRequestText: String {
        let number = workspace.pullRequestNumber.map { "#\($0)" }
        let title = workspace.pullRequestTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [number, title?.isEmpty == false ? title : nil].compactMap { $0 }.joined(separator: " · ")
    }

    private var hasSessionDetails: Bool {
        workspace.lastPrompt?.isEmpty == false || branchLine != nil
    }

    private var branchLine: String? {
        let branch = workspace.branch?.trimmingCharacters(in: .whitespacesAndNewlines)
        let status: String? = workspace.isDirty.map { dirty in
            dirty
                ? L10n.string("mobile.workspace.card.uncommittedChanges", defaultValue: "Uncommitted changes")
                : L10n.string("mobile.workspace.card.clean", defaultValue: "Clean")
        }
        let line = [branch?.isEmpty == false ? branch : nil, status].compactMap { $0 }.joined(separator: " · ")
        return line.isEmpty ? nil : line
    }

}

private struct WorkspaceOwnerAvatar: View {
    let name: String?
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .background(Circle().fill(Color.secondary.opacity(0.15)))
    }

    private var initials: some View {
        Text(initialsText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private var initialsText: String {
        let parts = (name ?? "").split(whereSeparator: { $0 == " " || $0 == "_" || $0 == "-" })
        if parts.count == 1, let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
