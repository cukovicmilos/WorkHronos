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
            }
        }
        .padding(.vertical, 4)
        // Neprovidna pozadina — materijal propušta sadržaj ispod liste.
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
        .shadow(radius: 4, y: 2)
        .frame(maxWidth: 300)
    }
}
