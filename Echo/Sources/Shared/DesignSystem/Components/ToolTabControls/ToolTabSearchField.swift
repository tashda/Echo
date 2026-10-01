import SwiftUI

/// A tool tab's search (round 37.3, SF1): a 28pt glass capsule at the right of the header line.
struct ToolTabSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ColorTokens.Text.secondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .frame(width: LayoutTokens.ToolTab.searchFieldWidth)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(ColorTokens.Text.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
                .accessibilityLabel("Clear search")
            }
        }
        .font(TypographyTokens.standard)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: LayoutTokens.ToolTab.controlHeight)
        .glassEffect(.regular, in: .capsule)
    }
}
