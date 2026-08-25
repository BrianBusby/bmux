import SwiftUI

struct SessionTranscriptTurnCardList: View, Equatable {
    let cards: [SessionTranscriptTurnCard]
    @State private var expandedCardIDs: Set<String> = []

    static func == (lhs: SessionTranscriptTurnCardList, rhs: SessionTranscriptTurnCardList) -> Bool {
        lhs.cards == rhs.cards
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(cards) { card in
                    SessionTranscriptTurnCardView(
                        card: card,
                        isExpanded: expandedCardIDs.contains(card.id)
                    ) {
                        if expandedCardIDs.contains(card.id) {
                            expandedCardIDs.remove(card.id)
                        } else {
                            expandedCardIDs.insert(card.id)
                        }
                    }
                    .id(card.id)
                }
            }
            .padding(10)
        }
        .background(Color.primary.opacity(0.018))
    }
}
