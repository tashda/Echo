import SwiftUI
import EchoSense

/// One EchoSense row: a kind badge, the name in the editor's font with the typed letters
/// highlighted, the column's qualifier as a chip, and its type or schema on the right.
/// Tinted while typing; solid once the selection moves with the arrow keys.
struct AutoCompletionRowView: View {
    let suggestion: SQLAutoCompletionSuggestion
    let typed: String
    let isSelected: Bool
    let isChoosing: Bool
    let nameFont: Font
    let cornerRadius: CGFloat
    let action: () -> Void

    private var isSolid: Bool { isSelected && isChoosing }

    var body: some View {
        Button(action: action) {
            HStack(spacing: LayoutTokens.EchoSense.rowSpacing) {
                badge
                AutoCompletionMatchText(text: suggestion.nameAndQualifier.name, typed: typed, font: nameFont, isOnAccent: isSolid)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let qualifier = suggestion.nameAndQualifier.qualifier {
                    Text(qualifier)
                        .font(TypographyTokens.detail.weight(.medium))
                        .padding(.horizontal, LayoutTokens.EchoSense.chipHorizontalPadding)
                        .background(isSolid ? ColorTokens.EchoSense.choosingText.opacity(0.2) : ColorTokens.EchoSense.chip,
                                    in: .rect(cornerRadius: LayoutTokens.EchoSense.badgeCornerRadius))
                }
                Spacer(minLength: LayoutTokens.EchoSense.rowSpacing)
                if let trailing = suggestion.trailingText, !trailing.isEmpty {
                    Text(trailing)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(isSolid ? ColorTokens.EchoSense.choosingText.opacity(0.8) : ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSolid ? ColorTokens.EchoSense.choosingText : ColorTokens.Text.primary)
            .padding(.horizontal, LayoutTokens.EchoSense.rowHorizontalPadding)
            .frame(height: LayoutTokens.EchoSense.rowHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSolid ? ColorTokens.EchoSense.choosingSelection : ColorTokens.EchoSense.typingSelection)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(suggestion.title), \(suggestion.displayKindTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var badge: some View {
        let color = isSolid ? ColorTokens.EchoSense.choosingText : suggestion.badgeColor
        return Text(suggestion.badgeText)
            .font(TypographyTokens.label.weight(.bold))
            .foregroundStyle(color)
            .frame(width: LayoutTokens.EchoSense.badgeSize, height: LayoutTokens.EchoSense.badgeSize)
            .background(color.opacity(ColorTokens.EchoSense.badgeFillOpacity), in: .rect(cornerRadius: LayoutTokens.EchoSense.badgeCornerRadius))
            .accessibilityHidden(true)
    }
}

/// A name with the typed letters in bold accent: the first place the typed text appears, or,
/// for fuzzy matches, each typed letter in order.
struct AutoCompletionMatchText: View {
    let text: String
    let typed: String
    let font: Font
    var isOnAccent = false

    var body: some View {
        Text(attributed).font(font)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        guard !typed.isEmpty else { return result }
        for range in Self.matchRanges(of: typed, in: text) {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
            result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            if !isOnAccent { result[lower..<upper].foregroundColor = ColorTokens.EchoSense.match }
        }
        return result
    }

    /// Ranges in `text` to highlight for `typed`: one contiguous match when there is one,
    /// otherwise each typed character in order (fuzzy).
    static func matchRanges(of typed: String, in text: String) -> [Range<String.Index>] {
        if let range = text.range(of: typed, options: [.caseInsensitive, .diacriticInsensitive]) { return [range] }
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex
        for character in typed {
            guard let found = text[searchStart...].firstIndex(where: { String($0).caseInsensitiveCompare(String(character)) == .orderedSame }) else { return [] }
            let next = text.index(after: found)
            ranges.append(found..<next)
            searchStart = next
        }
        return ranges
    }
}
