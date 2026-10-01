import SwiftUI

/// Round 21's shared pieces: a query tab as Echo draws it (tab strip, editor card, results card with
/// the floating footer), simplified from the As built specimens and built only from tokens.

/// A tab's transaction state, as `PostgresSessionConnection` reports it.
enum PgTxn: Equatable {
    case idle
    case inTransaction(statements: Int, seconds: Int)
    case failed
    case lost

    var isOpen: Bool {
        switch self {
        case .inTransaction, .failed: true
        default: false
        }
    }
}

/// A tab in the strip. `badge` is drawn after the title.
struct PgTab: Identifiable {
    let id: Int
    let title: String
    var icon = "doc.text"
    var badge: AnyView?
}

/// The tab strip: one plate per tab, the active one lifted.
struct PgTabStrip: View {
    let tabs: [PgTab]
    let active: Int
    var onClose: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            ForEach(tabs) { tab in
                HStack(spacing: SpacingTokens.xxs) {
                    Image(systemName: tab.icon).font(TypographyTokens.compact).foregroundStyle(ColorTokens.Text.secondary)
                    Text(tab.title).font(TypographyTokens.standard).lineLimit(1)
                    if let badge = tab.badge { badge }
                    if let onClose, tab.id == active {
                        Button { onClose(tab.id) } label: {
                            Image(systemName: "xmark").font(TypographyTokens.micro)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .help("Close tab")
                    }
                }
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.vertical, SpacingTokens.xxs2)
                .frame(maxWidth: .infinity)
                .background(tab.id == active ? ColorTokens.Workspace.card : Color.clear, in: .capsule)
            }
        }
        .padding(SpacingTokens.xxxs)
        .glassEffect(.regular, in: .capsule)
    }
}

/// The editor card with numbered lines. `decorate` draws on a line (underline, band, note).
struct PgEditorCard<Decoration: View>: View {
    let lines: [String]
    var highlightedLine: Int?
    @ViewBuilder var decorate: (Int) -> Decoration

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sm) {
                    Text("\(index + 1)")
                        .font(TypographyTokens.code)
                        .foregroundStyle(ColorTokens.Text.quaternary)
                        .frame(width: SpacingTokens.lg, alignment: .trailing)
                    ZStack(alignment: .leading) {
                        Text(line).font(TypographyTokens.code)
                        decorate(index)
                    }
                    Spacer(minLength: SpacingTokens.none)
                }
                .padding(.vertical, SpacingTokens.xxxs)
                .background(highlightedLine == index ? ColorTokens.Text.primary.opacity(0.05) : Color.clear,
                            in: RoundedRectangle(cornerRadius: ShapeTokens.CornerRadius.extraSmall))
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }
}

extension PgEditorCard where Decoration == EmptyView {
    init(lines: [String], highlightedLine: Int? = nil) {
        self.init(lines: lines, highlightedLine: highlightedLine) { _ in EmptyView() }
    }
}

/// A glass pill in the footer (status, rows, time, …).
struct PgPill<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) { content() }
            .font(TypographyTokens.detail)
            .padding(.horizontal, SpacingTokens.xs)
            .padding(.vertical, SpacingTokens.xxxs)
            .background((tint ?? Color.clear).opacity(tint == nil ? 0 : 0.14), in: .capsule)
            .glassEffect(.regular, in: .capsule)
    }
}

/// The floating footer: segments at the left, the server/database chip, pills at the right.
struct PgFooter<Trailing: View>: View {
    var segment = "Results"
    var segments = ["Results", "Messages"]
    var database = "localhost · shop"
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xxs) {
                ForEach(segments, id: \.self) { name in
                    Text(name)
                        .font(TypographyTokens.detail)
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, SpacingTokens.xxxs)
                        .background(name == segment ? ColorTokens.Text.primary.opacity(0.08) : Color.clear, in: .capsule)
                }
            }
            PgPill { Image(systemName: "cylinder.split.1x2"); Text(database) }
            Spacer(minLength: SpacingTokens.none)
            trailing()
        }
        .padding(SpacingTokens.xs)
    }
}

/// A small results grid.
struct PgGrid: View {
    let columns: [String]
    let rows: [[String?]]
    var rightAligned: Set<Int> = []
    var cell: ((Int, Int, String?) -> AnyView)?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xxs) {
            GridRow {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, name in
                    Text(name).font(TypographyTokens.labelBold).foregroundStyle(ColorTokens.Text.secondary)
                        .gridColumnAlignment(rightAligned.contains(index) ? .trailing : .leading)
                }
            }
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, value in
                        if let cell {
                            cell(rowIndex, column, value)
                        } else if let value {
                            Text(value).font(TypographyTokens.standard).lineLimit(1)
                        } else {
                            Text("NULL").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.tertiary)
                        }
                    }
                }
            }
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// A row of small buttons that drive an exhibit's simulation.
struct PgSimBar: View {
    let actions: [(String, () -> Void)]

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                Button(action.0, action: action.1)
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

/// A status dot and word, as the footer's status pill draws it (FTR-2.6).
struct PgStatusLabel: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: SpacingTokens.xxs) {
            Circle().fill(color).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
            Text(text)
        }
    }
}

/// `m:ss` for a duration in seconds.
func pgDuration(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
