import EchoSense
import SwiftUI

/// Round 28.15: every mark in the editor under one language, each on a line of code, then the
/// floating pieces, then three lines with several marks together.
struct LabQEMarkSampler: View {
    static let width: CGFloat = 620
    static let height: CGFloat = 600

    let language: LabQEMarkLanguage

    private let font = LabQEFonts.nsFont(.sfMono, size: 13, ligatures: false)
    private var advance: CGFloat { LabQEFonts.metrics(.sfMono, size: 13).advance }
    private let lineHeight = SpacingTokens.md2

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            row("Word at the caret", "WHERE shipped_at IS NULL", [(6, 16, .word)])
            row("Find match", "FROM orders AS o", [(5, 11, .find)])
            row("Current find match", "UPDATE orders", [(7, 13, .findCurrent)])
            row("Mistake", "JOIN custmers AS c", [(5, 13, .mistake)])
            row("Replacement", "FROM orders orders_2026 AS o", [(5, 11, .removed), (12, 23, .added)], strike: 5..<11)
            row("Statement", "SELECT o.order_id", [], bracket: true)
            Divider().padding(.vertical, SpacingTokens.xxxs)
            floatingRow
            Divider().padding(.vertical, SpacingTokens.xxxs)
            Text(verbatim: "Together").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            together
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.card)
        .workspaceCard()
    }

    private func row(_ title: String, _ code: String, _ marks: [(Int, Int, LabQEMarkLanguage.Kind)],
                     strike: Range<Int>? = nil, bracket: Bool = false) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Text(title).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 130, alignment: .leading)
            ZStack(alignment: .leading) {
                if bracket {
                    Capsule().fill(language.color(for: .statement).opacity(language.opacity(for: .statement)))
                        .frame(width: LayoutTokens.EditorGutter.statementBracketWidth, height: lineHeight - SpacingTokens.xxs)
                        .offset(x: -SpacingTokens.xs)
                }
                ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in markShape(mark.0, mark.1, mark.2) }
                codeText(code, strike: strike)
            }
            .frame(height: lineHeight)
        }
    }

    private func markShape(_ start: Int, _ end: Int, _ kind: LabQEMarkLanguage.Kind) -> some View {
        let letters = ceil(font.ascender - font.descender) + LayoutTokens.EditorGutter.highlightPadding * 2
        let height = language.height == .line ? lineHeight : letters
        let padding = kind == .mistake ? SpacingTokens.xxs : SpacingTokens.micro
        let width = CGFloat(end - start) * advance + padding * 2
        return RoundedRectangle(cornerRadius: language.cornerRadius(for: kind, height: height), style: .continuous)
            .fill(language.color(for: kind).opacity(language.opacity(for: kind)))
            .frame(width: width, height: height)
            .offset(x: CGFloat(start) * advance - padding)
    }

    private func codeText(_ code: String, strike: Range<Int>?) -> some View {
        var text = AttributedString(code)
        if let strike, let range = Range(NSRange(location: strike.lowerBound, length: strike.count), in: text) {
            text[range].strikethroughStyle = Text.LineStyle(pattern: .solid, color: ColorTokens.Status.error)
            text[range].foregroundColor = ColorTokens.Status.error
        }
        return Text(text).font(Font(font)).fixedSize()
    }

    private var floatingRow: some View {
        HStack(spacing: SpacingTokens.md) {
            Text(verbatim: "Floating").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: 130, alignment: .leading)
            floating(symbol: "checkmark.circle.fill", tint: ColorTokens.Status.success, words: "14,870 rows · 10.1 s")
            floating(symbol: "exclamationmark.octagon.fill", tint: ColorTokens.Status.error, words: "Unknown table")
            floating(symbol: "plus.magnifyingglass", tint: ColorTokens.Text.secondary, words: "100%")
        }
    }

    @ViewBuilder
    private func floating(symbol: String, tint: Color, words: String) -> some View {
        let label = HStack(spacing: SpacingTokens.xxs) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(words).foregroundStyle(ColorTokens.Text.secondary)
        }
        .font(TypographyTokens.detail)
        .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
        switch language.floating {
        case .glass: label.glassEffect(.regular, in: .capsule)
        case .card:
            label.background(ColorTokens.Workspace.card, in: Capsule())
                .overlay(Capsule().strokeBorder(ColorTokens.Separator.primary, lineWidth: LayoutTokens.EditorGutter.edgeWidth))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
        }
    }

    private var together: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            row("", "JOIN custmers AS c ON c.customer_id", [(5, 13, .mistake), (22, 33, .word)])
            row("", "WHERE shipped_at IS NULL", [(6, 16, .word)])
            row("", "UPDATE orders orders_2026", [(7, 13, .removed), (14, 25, .added)], strike: 7..<13)
        }
    }
}
