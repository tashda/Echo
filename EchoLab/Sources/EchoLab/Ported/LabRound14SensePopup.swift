import SwiftUI

/// ES1 rows with the ES4 footer. Names use the editor font with the typed letters highlighted
/// (ESR1, ESR2); same-named columns show their alias (ESR3); the popup uses the card material
/// (ESR5) and the footer is an inset rounded panel, concentric with the popup.
struct LabRound14SensePopup: View {
    let suggestions: [LabSuggestion]
    let typed: String
    let selectedIndex: Int
    let isSolid: Bool
    let cornerRadius: CGFloat
    let onPick: (Int) -> Void

    private var padding: CGFloat { LayoutTokens.DesignLabRound14.sensePopupPadding }
    private var innerRadius: CGFloat { max(cornerRadius - padding, SpacingTokens.xxs) }
    private var ambiguousNames: Set<String> {
        Set(Dictionary(grouping: suggestions, by: \.name).filter { $0.value.count > 1 }.keys)
    }

    var body: some View {
        VStack(spacing: padding) {
            VStack(spacing: SpacingTokens.none) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    row(suggestion, isSelected: index == selectedIndex)
                        .onTapGesture { onPick(index) }
                }
            }
            if suggestions.indices.contains(selectedIndex) {
                footer(suggestions[selectedIndex])
            }
        }
        .padding(padding)
        .frame(width: LayoutTokens.DesignLabRound14.sensePopupWidth)
        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(ColorTokens.Workspace.cardEdge.opacity(LayoutTokens.Workspace.cardEdgeOpacity), lineWidth: LayoutTokens.Workspace.cardEdgeWidth))
        .shadow(color: ColorTokens.DesignLabRound14.liftShadow, radius: SpacingTokens.xs2, y: SpacingTokens.xxs)
    }

    private func row(_ suggestion: LabSuggestion, isSelected: Bool) -> some View {
        let solid = isSelected && isSolid
        return HStack(spacing: SpacingTokens.xs) {
            Text(suggestion.kind.rawValue)
                .font(TypographyTokens.label.weight(.bold))
                .foregroundStyle(solid ? ColorTokens.DesignLabRound14.senseSolidTitle : suggestion.badgeColor)
                .frame(width: LayoutTokens.DesignLabRound14.senseBadgeSize, height: LayoutTokens.DesignLabRound14.senseBadgeSize)
                .background((solid ? ColorTokens.DesignLabRound14.senseSolidTitle : suggestion.badgeColor).opacity(0.16),
                            in: .rect(cornerRadius: LayoutTokens.DesignLabRound14.senseBadgeCornerRadius))
            highlightedName(suggestion.name, onSolid: solid)
                .font(TypographyTokens.DesignLabRound14.editor)
                .lineLimit(1)
            if let alias = suggestion.alias, ambiguousNames.contains(suggestion.name) || suggestion.kind == .column {
                Text(alias)
                    .font(TypographyTokens.detail.weight(.medium))
                    .padding(.horizontal, SpacingTokens.xxs1)
                    .background(solid ? ColorTokens.DesignLabRound14.senseSolidTitle.opacity(0.2) : ColorTokens.DesignLabRound14.senseAlias,
                                in: .rect(cornerRadius: SpacingTokens.xxs))
            }
            Spacer(minLength: SpacingTokens.xs)
            Text(suggestion.type)
                .font(TypographyTokens.detail)
                .foregroundStyle(solid ? ColorTokens.DesignLabRound14.senseSolidTitle.opacity(0.8) : ColorTokens.Text.tertiary)
        }
        .foregroundStyle(solid ? ColorTokens.DesignLabRound14.senseSolidTitle : ColorTokens.Text.primary)
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: LayoutTokens.DesignLabRound14.senseRowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(solid ? ColorTokens.DesignLabRound14.senseSolid : ColorTokens.DesignLabRound14.senseTint)
            }
        }
        .contentShape(Rectangle())
    }

    /// The typed letters in bold accent: a prefix match, or the first place the text appears.
    private func highlightedName(_ name: String, onSolid: Bool) -> Text {
        guard let range = name.range(of: typed, options: .caseInsensitive), !typed.isEmpty else { return Text(name) }
        let before = String(name[name.startIndex..<range.lowerBound])
        let match = String(name[range])
        let after = String(name[range.upperBound...])
        let matched = Text(match).font(TypographyTokens.DesignLabRound14.editorBold)
        return Text("\(Text(before))\(onSolid ? matched : matched.foregroundStyle(ColorTokens.accent))\(Text(after))")
    }

    private func footer(_ suggestion: LabSuggestion) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
            HStack(spacing: SpacingTokens.xxs2) {
                Text(suggestion.insertion).font(TypographyTokens.DesignLabRound14.editorBold)
                Text(suggestion.type).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            Text([suggestion.source, suggestion.detail].compactMap { $0 }.joined(separator: " · "))
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
                .lineLimit(1)
            HStack(spacing: SpacingTokens.sm) {
                Text("↩ Insert")
                Text("⇥ Complete")
                Text("↑↓ Choose")
                Text("⌘I Open")
            }
            .font(TypographyTokens.label)
            .foregroundStyle(ColorTokens.Text.tertiary)
            .padding(.top, SpacingTokens.xxxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.xs)
        .background(ColorTokens.DesignLabRound14.senseFooter, in: .rect(cornerRadius: innerRadius))
        .contentTransition(.opacity)
    }
}
