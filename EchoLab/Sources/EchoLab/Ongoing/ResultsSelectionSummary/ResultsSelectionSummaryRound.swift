import SwiftUI

/// Round 41.2 · Results: the selection summary. Echo today (GridSelectionSummary,
/// BottomPanelStatusBar+Metrics): selecting cells puts a pill first on the footer's right with the
/// count, sum and average in full ("89 cells · Sum 34.630.054.833.231 · Avg 389.101.739.699,22"),
/// which pushes the other pills and can't be copied. Tapping any right-hand pill opens the one
/// statistics popover (41.5).
@MainActor
enum ResultsSelectionSummaryRound {
    enum Pill: String, CaseIterable {
        case today = "SP0 · Count, sum and average in full (today)"
        case compact = "SP1 · Count and a compact sum: 89 · Σ 34,6 bio."
        case sumOnly = "SP2 · Only the compact sum: Σ 34,6 bio."
        case countOnly = "SP3 · Only the count: 89 cells"

        var summary: String {
            switch self {
            case .today: "Exact, but as wide as the footer allows; the other pills move left."
            case .compact: "Short, in your locale's compact form (bio. for billions in Danish, B in English); exact figures in the popover."
            case .sumOnly: "The sum is what you select numbers for; the count is in the popover."
            case .countOnly: "Never wide; the numbers are one click away."
            }
        }
    }

    enum Popover: String, CaseIterable {
        case grid = "PO0 · A grid of figures, each copied with a click"
        case list = "PO1 · A list with a Copy button on each row and Copy All"
        case chart = "PO2 · PO1 with a small histogram of the values"
    }

    static let spec = RoundSpec(
        controls: [
            .of("pill", "Pill", Pill.self, default: .compact,
                question: "Select the column in each exhibit and compare the pill.",
                recommend: .compact,
                why: "You asked for 'Sum 34m'-like text: the count says how many you picked (which catches a wrong selection) and Σ with the locale's compact number says the size. Both fit in about 120pt where today's takes 420pt.",
                summary: \.summary),
            .of("popover", "Popover", Popover.self, default: .list,
                question: "Click the pill in the Proposal. Which popover makes the exact numbers easiest to read and copy?",
                recommend: .list,
                why: "Labels on the left, exact figures on the right in tabular digits, and a Copy button that appears on the row you point at; Copy All puts them on the clipboard as label–value lines. The histogram is lovely for one numeric column and noise for mixed text."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "89 cells of bagno selected.", isEchoToday: true, isWide: true, designWidth: 760, designHeight: 300) { _ in
                LabSSCard(pill: .today, popover: .list)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click the pill.", isWide: true, designWidth: 760, designHeight: 460) { values in
                LabSSCard(pill: Pill(rawValue: values["pill"]) ?? .compact, popover: Popover(rawValue: values["popover"]) ?? .list)
            },
        ],
        questions: [
            .init(id: "figures", title: "Which figures",
                  question: "What should the popover list for a numeric selection?",
                  choices: [.init(id: "five", name: "FG0 · Count, Sum, Average, Min, Max"),
                            .init(id: "more", name: "FG1 · FG0, plus Distinct, Empty (NULL) and Median")],
                  recommended: "more",
                  why: "NULLs and distinct values are what you check when a sum looks wrong; the popover has room, the pill doesn't."),
            .init(id: "text", title: "Text cells",
                  question: "When the selection is text (names, codes), what does the pill show?",
                  choices: [.init(id: "count", name: "TX0 · The count; the popover lists Distinct and Empty"), .init(id: "hide", name: "TX1 · No pill")],
                  recommended: "count",
                  why: "Knowing you selected 89 cells, 12 distinct, is useful for text too, and the pill not appearing would look like a bug."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["pill": Pill.compact.rawValue, "popover": Popover.list.rawValue], isRecommended: true)]
    )
}

/// The figures for the sample selection.
private enum LabSSFigures {
    static let rows: [(String, String)] = [
        ("Count", "89"), ("Sum", "34.630.054.833.231"), ("Average", "389.101.739.699,22"), ("Min", "10.385.498"),
        ("Max", "355.000.056.209"), ("Median", "355.000.006.209"), ("Distinct", "89"), ("Empty", "0"),
    ]
    static let compactSum = Double(34_630_054_833_231).formatted(.number.notation(.compactName).precision(.fractionLength(1)))
}

private struct LabSSCard: View {
    let pill: ResultsSelectionSummaryRound.Pill
    let popover: ResultsSelectionSummaryRound.Popover
    @State private var showsPopover = false

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            LabWKGrid(columns: [.init(name: "bagno", type: "char"), .init(name: "histDate", type: "char"), .init(name: "Centre", type: "char", width: 90)],
                      rows: [["10385498", "", "10"], ["230166744027", "", "10"], ["230174723054", "", "10"], ["230186043605", "", "10"], ["230187327962", "", "10"]],
                      selectedColumn: 0)
            Spacer(minLength: 0)
            LabWKFooter(server: "dkloosql10-p · ccsLDK10", pills: pills)
                .popover(isPresented: $showsPopover, arrowEdge: .top) { LabSSPopover(style: popover) }
        }
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    private var pills: [LabWKPill] {
        let summary: LabWKPill = switch pill {
        case .today:
            LabWKPill(id: "sel") { Text("89 cells · Sum 34.630.054.833.231 · Avg 389.101.739.699,22").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary) }
        case .compact:
            LabWKPill(id: "sel", onTap: { showsPopover.toggle() }) {
                Text("89 · Σ \(LabSSFigures.compactSum)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
            }
        case .sumOnly:
            LabWKPill(id: "sel", onTap: { showsPopover.toggle() }) {
                Text("Σ \(LabSSFigures.compactSum)").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
            }
        case .countOnly:
            LabWKPill(id: "sel", onTap: { showsPopover.toggle() }) {
                Text("89 cells").font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
            }
        }
        return [summary, .rows("1,204"), .time("0s"), .status("Completed", tint: ColorTokens.Status.success)]
    }
}

/// The popover with the exact figures.
private struct LabSSPopover: View {
    let style: ResultsSelectionSummaryRound.Popover
    @State private var hovered: String?
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack {
                Text("89 cells in bagno").font(TypographyTokens.headline)
                Spacer()
                if style != .grid { Button("Copy All") { copied = "all" }.controlSize(.small) }
            }
            if style == .chart { LabSSHistogram().frame(height: SpacingTokens.xl2) }
            if style == .grid {
                Grid(alignment: .leading, horizontalSpacing: SpacingTokens.md, verticalSpacing: SpacingTokens.xs) {
                    ForEach(0..<4, id: \.self) { row in
                        GridRow {
                            ForEach(0..<2, id: \.self) { column in
                                let item = LabSSFigures.rows[row * 2 + column]
                                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                                    Text(item.0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                                    Text(item.1).font(TypographyTokens.standard.monospacedDigit()).textSelection(.enabled)
                                }
                                .onTapGesture { copied = item.0 }
                            }
                        }
                    }
                }
            } else {
                ForEach(LabSSFigures.rows, id: \.0) { item in
                    HStack {
                        Text(item.0).foregroundStyle(ColorTokens.Text.secondary)
                        Spacer()
                        Text(item.1).monospacedDigit().textSelection(.enabled)
                        Image(systemName: copied == item.0 ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copied == item.0 ? ColorTokens.Status.success : ColorTokens.Text.secondary)
                            .opacity(hovered == item.0 || copied == item.0 ? 1 : 0)
                            .onTapGesture { copied = item.0 }
                    }
                    .font(TypographyTokens.standard)
                    .onHover { hovered = $0 ? item.0 : nil }
                }
            }
        }
        .padding(SpacingTokens.md)
        .frame(width: 300)
    }
}

private struct LabSSHistogram: View {
    private let bars: [CGFloat] = [0.1, 0.05, 0.08, 0.15, 0.1, 0.05, 0.02, 0.9, 0.3, 0.05]
    var body: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.xxxs) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 1).fill(ColorTokens.accent.opacity(0.6)).frame(maxHeight: .infinity, alignment: .bottom)
                    .scaleEffect(y: value, anchor: .bottom)
            }
        }
    }
}
