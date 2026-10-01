import SwiftUI

/// Round 43.4 (TP0): the grid as the preview of Settings › Results. Sample rows; it follows row
/// numbers, alternate shading and monospaced cells.
struct ResultsSettingsPreview: View {
    let settings: GlobalSettings

    private static let rows: [(String, String, String)] = [
        ("1", "Ada Lovelace", "1,204.50"), ("2", "Grace Hopper", "88.00"), ("3", "Edsger Dijkstra", "NULL"),
        ("4", "Barbara Liskov", "310.25"), ("5", "Donald Knuth", "9,999.99"), ("6", "Margaret Hamilton", "42.00"),
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            gridRow(number: "", id: "id", name: "name", amount: "amount", isHeader: true, index: 0)
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                gridRow(number: "\(index + 1)", id: row.0, name: row.1, amount: row.2, isHeader: false, index: index)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.card)
        .clipShape(.rect(cornerRadius: SpacingTokens.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous)
                .strokeBorder(ColorTokens.Separator.primary, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }

    private func gridRow(number: String, id: String, name: String, amount: String, isHeader: Bool, index: Int) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            if settings.resultsShowRowNumbers {
                Text(number).foregroundStyle(ColorTokens.Text.tertiary).frame(width: SpacingTokens.md2, alignment: .trailing)
            }
            Text(id).frame(width: SpacingTokens.lg, alignment: .trailing)
            Text(name).frame(maxWidth: .infinity, alignment: .leading)
            Text(amount).foregroundStyle(amount == "NULL" && !isHeader ? ColorTokens.Text.tertiary : ColorTokens.Text.primary)
                .frame(width: SpacingTokens.xxxl, alignment: .trailing)
        }
        .font(isHeader ? TypographyTokens.detail.weight(.semibold) : (settings.resultsMonospacedCells ? TypographyTokens.standard.monospaced() : TypographyTokens.standard))
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: SpacingTokens.md2 + SpacingTokens.xxs)
        .background(!isHeader && settings.resultsAlternateRowShading && index % 2 == 1 ? ColorTokens.Sidebar.hoverFill : .clear)
    }
}
