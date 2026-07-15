import SwiftUI

struct ProjectAutocomplete: View {
    let suggestions: [String]
    let highlightIndex: Int?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    Text(suggestion)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(index == highlightIndex ? Color.accentColor.opacity(0.25) : .clear)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        // Neprovidna pozadina; senka na samoj formi, ne na sadržaju (inače pada i na tekst).
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(radius: 4, y: 2)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        .frame(maxWidth: 300)
    }
}
