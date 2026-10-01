import SwiftUI

/// A few lines of SQL in the editor's Aurora/Midnight look: 13pt monospaced, numbers in the gutter,
/// keywords blue, strings red, numbers green. Sample text only; shared by the walkthrough rounds.
struct LabWKEditor: View {
    var lines: [String] = LabWKEditor.sample
    /// A line (1-based) to mark with a statement band, or nil.
    var markedLine: Int?

    static let sample = ["select *", "from dbo.aml_checkpoint", "", "", "update aml_checkpoint", "set keyValue = '20260801'", "where keyName = 'aml_last_oh'"]
    static let failing = ["select *", "from ba_tbl", "where uniqueBagID <> 123456"]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(spacing: SpacingTokens.md) {
                    Text("\(index + 1)")
                        .font(TypographyTokens.detail.monospacedDigit())
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SpacingTokens.md, alignment: .trailing)
                    LabWKSQLText(line: line)
                    Spacer(minLength: 0)
                }
                .frame(height: SpacingTokens.lg + SpacingTokens.xxxs)
                .background(alignment: .leading) {
                    if markedLine == index + 1 {
                        ColorTokens.accent.opacity(0.08).padding(.leading, SpacingTokens.xl)
                    }
                }
            }
        }
        .padding(.top, SpacingTokens.xs)
        .padding(.leading, SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// One line of SQL, coloured by a tiny tokenizer (keywords, strings, numbers).
struct LabWKSQLText: View {
    let line: String
    private static let keywords: Set<String> = ["select", "from", "where", "update", "set", "and", "or", "order", "by", "desc", "insert", "into", "values", "join", "on", "group"]

    var body: some View {
        Text(attributed).font(TypographyTokens.code)
    }

    private var attributed: AttributedString {
        var result = AttributedString()
        for (index, word) in line.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
            var part = AttributedString((index == 0 ? "" : " ") + word)
            let text = String(word)
            if Self.keywords.contains(text.lowercased()) {
                part.foregroundColor = Color(nsColor: .systemBlue)
            } else if text.hasPrefix("'") {
                part.foregroundColor = Color(nsColor: .systemRed)
            } else if Double(text) != nil {
                part.foregroundColor = Color(nsColor: .systemGreen)
            } else {
                part.foregroundColor = ColorTokens.Text.primary
            }
            result += part
        }
        return result
    }
}

/// The results grid: a `#` column, two-line headers (name over type) and zebra rows.
struct LabWKGrid: View {
    struct Column: Hashable { let name: String; let type: String; var width: CGFloat = 120 }
    var columns: [Column] = LabWKGrid.checkpointColumns
    var rows: [[String]] = LabWKGrid.checkpointRows
    /// How the header is separated from the rows (round 41.1 decides it).
    var headerRule: HeaderRule = .single
    var selectedColumn: Int?

    enum HeaderRule { case single, doubled, none, thick, soft }
    @Environment(\.labWKStriped) private var striped

    static let checkpointColumns: [Column] = [.init(name: "keyName", type: "varchar"), .init(name: "keyValue", type: "varchar"),
                                              .init(name: "lastUpdated", type: "datetime2", width: 190)]
    static let checkpointRows: [[String]] = [["AML_LAST_BA", "20261001", "2026-10-01 13:49:05.73"],
                                            ["AML_LAST_CU", "20261001", "2026-10-01 15:04:16.99"],
                                            ["AML_LAST_OH", "20260801", "2026-10-01 12:21:21.47"]]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(spacing: SpacingTokens.none) {
                Text("#").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).frame(width: SpacingTokens.xl)
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: SpacingTokens.none) {
                        Text(column.name).font(TypographyTokens.standard.weight(.semibold))
                        Text(column.type).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.tertiary)
                    }
                    .padding(.horizontal, SpacingTokens.xs)
                    .frame(width: column.width, alignment: .leading)
                    .overlay(alignment: .trailing) { Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1, height: SpacingTokens.md) }
                }
            }
            .frame(height: SpacingTokens.xl2)
            .overlay(alignment: .bottom) { rule }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: SpacingTokens.none) {
                    Text("\(index + 1)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.tertiary)
                        .frame(width: SpacingTokens.xl)
                    ForEach(Array(row.enumerated()), id: \.offset) { column, value in
                        Text(value).font(TypographyTokens.standard).lineLimit(1)
                            .padding(.horizontal, SpacingTokens.xs)
                            .frame(width: columns[safe: column]?.width ?? 120, alignment: .leading)
                            .background(selectedColumn == column ? ColorTokens.accent.opacity(0.14) : .clear)
                    }
                }
                .frame(height: SpacingTokens.lg + SpacingTokens.xxs)
                .background(index.isMultiple(of: 2) || !striped ? Color.clear : ColorTokens.Sidebar.hoverFill)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var rule: some View {
        switch headerRule {
        case .single: Rectangle().fill(ColorTokens.Separator.primary).frame(height: 0.5)
        case .thick: Rectangle().fill(ColorTokens.Separator.primary).frame(height: 1)
        case .doubled:
            // Echo today (measured): ResultTableHeaderView's 1pt line, and the system header's own
            // 0.5pt line about 4pt below it.
            VStack(spacing: SpacingTokens.none) {
                Rectangle().fill(ColorTokens.Separator.primary).frame(height: 1)
                Color.clear.frame(height: SpacingTokens.xxs - 0.5)
                Rectangle().fill(ColorTokens.Separator.primary).frame(height: 0.5)
            }
            .offset(y: SpacingTokens.xxs + 0.5)
        case .soft:
            LinearGradient(colors: [ColorTokens.Text.primary.opacity(0.07), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: SpacingTokens.xxs2).offset(y: SpacingTokens.xxs2)
        case .none: EmptyView()
        }
    }
}

extension EnvironmentValues {
    /// Whether the walkthrough grid stripes every second row (round 32.1).
    @Entry var labWKStriped = true
}
