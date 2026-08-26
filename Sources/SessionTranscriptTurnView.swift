import BmuxFoundation
import SwiftUI

struct SessionTranscriptTurnView: View, Equatable {
    let row: SessionTranscriptDisplayRow
    @Environment(\.colorScheme) private var colorScheme

    static func == (lhs: SessionTranscriptTurnView, rhs: SessionTranscriptTurnView) -> Bool {
        lhs.row == rhs.row
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 3) {
                Text(row.isContinuation ? "" : row.role.label)
                    .bmuxFont(size: 10, weight: .semibold)
                    .foregroundColor(row.role.foregroundColor(colorScheme: colorScheme))
                    .lineLimit(1)
                    .frame(width: 58, alignment: .trailing)
                if row.isContinuation {
                    Circle()
                        .fill(row.role.foregroundColor(colorScheme: colorScheme).opacity(0.38))
                        .frame(width: 3, height: 3)
                }
            }
            Text(row.text)
                .bmuxFont(size: row.role.bodyFontSize, design: row.role.bodyFontDesign)
                .foregroundColor(row.role.bodyForegroundColor(colorScheme: colorScheme))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(row.role.foregroundColor(colorScheme: colorScheme).opacity(0.46))
                .frame(width: 2)
        }
        .background(row.role.backgroundColor(colorScheme: colorScheme))
    }
}
