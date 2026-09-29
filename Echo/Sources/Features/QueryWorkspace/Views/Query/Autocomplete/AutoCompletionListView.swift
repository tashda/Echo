import SwiftUI
import AppKit
import EchoSense

/// The EchoSense popup (Design/05-components › EchoSense): rows, then the details footer, on the
/// card material. Its corner follows Settings › Appearance › Card Corners, capped so the rows and
/// footer inside keep concentric corners. The window around it draws the shadow.
struct AutoCompletionListView: View {
    let suggestions: [SQLAutoCompletionSuggestion]
    let selectedID: String?
    /// True once the selection moved with the arrow keys (ESR4): the row turns solid.
    let isChoosing: Bool
    let typed: String
    let nameFont: NSFont
    let cardCornerRadius: CGFloat
    let statusMessage: String?
    let onSelect: @MainActor (SQLAutoCompletionSuggestion) -> Void

    private var cornerRadius: CGFloat { LayoutTokens.EchoSense.cornerRadius(cardCornerRadius: cardCornerRadius) }
    private var innerRadius: CGFloat { LayoutTokens.EchoSense.rowCornerRadius(cardCornerRadius: cardCornerRadius) }
    private var font: Font { Font(nameFont) }

    private var selectedSuggestion: SQLAutoCompletionSuggestion? {
        guard let selectedID else { return nil }
        return suggestions.first { $0.id == selectedID }
    }

    /// Wide enough for the longest name plus its badge, chip and type, within the popup's limits.
    var preferredWidth: CGFloat {
        let widest = suggestions.map { suggestion -> CGFloat in
            let name = (suggestion.nameAndQualifier.name as NSString).size(withAttributes: [.font: nameFont]).width
            let chip = suggestion.nameAndQualifier.qualifier.map { ($0 as NSString).size(withAttributes: [.font: TypographyTokens.AppKit.detail]).width + LayoutTokens.EchoSense.chipHorizontalPadding * 2 + LayoutTokens.EchoSense.rowSpacing } ?? 0
            let trailing = suggestion.trailingText.map { ($0 as NSString).size(withAttributes: [.font: TypographyTokens.AppKit.detail]).width + LayoutTokens.EchoSense.rowSpacing } ?? 0
            return name + chip + trailing
        }.max() ?? 0
        let chrome = LayoutTokens.EchoSense.padding * 2 + LayoutTokens.EchoSense.rowHorizontalPadding * 2
            + LayoutTokens.EchoSense.badgeSize + LayoutTokens.EchoSense.rowSpacing * 2
        return min(LayoutTokens.EchoSense.maxWidth, max(LayoutTokens.EchoSense.minWidth, ceil(widest + chrome)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.EchoSense.padding) {
            if let statusMessage {
                Text(statusMessage)
                    .font(TypographyTokens.detail.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, LayoutTokens.EchoSense.rowHorizontalPadding)
                    .padding(.top, SpacingTokens.xxs)
            }
            rows
            if let selectedSuggestion {
                AutoCompletionDetailFooter(suggestion: selectedSuggestion, nameFont: font, cornerRadius: innerRadius)
            }
        }
        .padding(LayoutTokens.EchoSense.padding)
        .frame(width: preferredWidth, alignment: .leading)
        .background(ColorTokens.EchoSense.background, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.EchoSense.edge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.none) {
                    ForEach(suggestions) { suggestion in
                        AutoCompletionRowView(
                            suggestion: suggestion, typed: typed, isSelected: suggestion.id == selectedID,
                            isChoosing: isChoosing, nameFont: font, cornerRadius: innerRadius
                        ) { onSelect(suggestion) }
                        .id(suggestion.id)
                    }
                }
            }
            .frame(height: LayoutTokens.EchoSense.rowHeight * CGFloat(min(suggestions.count, LayoutTokens.EchoSense.visibleRows)))
            .onChange(of: selectedID) { _, id in if let id { proxy.scrollTo(id) } }
        }
    }
}
