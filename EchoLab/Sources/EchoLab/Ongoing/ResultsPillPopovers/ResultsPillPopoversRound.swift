import SwiftUI

/// Round 41.5 · Results: a popover for each footer pill. Echo today (BottomPanelStatusBar+Metrics):
/// tapping anywhere on the right-hand pills toggles one statistics popover (First row, Total, Rows,
/// Memory), the same for the rows, time and status pills. The owner wants each pill to open its own
/// popover with what that pill is about.
///
/// Accepted 2026-10-01: PP2, PR0, PT0 and PS0. Built into Echo as FTR-2.5 and 2.9 to 2.11. Server CPU
/// and the session (SPID) are not shown yet: Echo doesn't get them from the drivers.
@MainActor
enum ResultsPillPopoversRound {
    enum Style: String, CaseIterable {
        case today = "PP0 · One popover for all three (today)"
        case each = "PP1 · Each pill its own popover, figures only"
        case eachWithActions = "PP2 · Each pill its own popover, with the actions that go with it"
    }

    static let spec = RoundSpec(
        controls: [
            .of("style", "Popovers", Style.self, default: .eachWithActions,
                question: "Click the rows, time and status pills in each exhibit. Which popovers are worth opening?",
                recommend: .eachWithActions,
                why: "A popover that answers the pill you clicked, and lets you act on it (export the rows, run again, see the error), turns three labels into three small tools. Figures only is the step before, if actions feel crowded."),
            .of("scenario", "Run", LabPPScenario.self, default: .done),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "Every pill opens the same popover.", isEchoToday: true, isWide: true, designWidth: 760, designHeight: 440) { values in
                LabPPCard(style: .today, scenario: LabPPScenario(rawValue: values["scenario"]) ?? .done)
            },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls. Click each pill.", isWide: true, designWidth: 760, designHeight: 440) { values in
                LabPPCard(style: Style(rawValue: values["style"]) ?? .eachWithActions, scenario: LabPPScenario(rawValue: values["scenario"]) ?? .done)
            },
        ],
        questions: [
            .init(id: "rows", title: "Rows",
                  question: "What should the rows pill's popover hold?",
                  choices: [.init(id: "full", name: "PR0 · Rows and columns, result sets (1 of 3), loaded vs total, memory; Export and Copy All"),
                            .init(id: "small", name: "PR1 · Rows and columns only")],
                  recommended: "full",
                  why: "Export lives nowhere obvious today (round 3–8 removed the footer's Export); the rows pill is where 'I want these rows' starts."),
            .init(id: "time", title: "Time",
                  question: "What should the time pill's popover hold?",
                  choices: [.init(id: "timeline", name: "PT0 · A timeline: sent, first row, last row; server CPU; started and finished at; the last runs of this tab"),
                            .init(id: "figures", name: "PT1 · Today's four figures")],
                  recommended: "timeline",
                  why: "'Why was it slow?' is answered by where the time went (waiting for the first row vs streaming rows); the last runs say whether it's slower than usual. The execution metrics from Messages land here (41.4)."),
            .init(id: "status", title: "Status",
                  question: "What should the status pill's popover hold?",
                  choices: [.init(id: "context", name: "PS0 · What happened and when, the session (SPID 52), transaction state, and Show in Editor / Messages / Run Again"),
                            .init(id: "word", name: "PS1 · Nothing: the status is a label")],
                  recommended: "context",
                  why: "The status is the one pill that changes meaning (Running, Error, Cancelled): its popover is where you act on it, including Cancel while running."),
        ],
        presets: [.init(id: "recommended", name: "My recommendation", values: ["style": Style.eachWithActions.rawValue], isRecommended: true)]
    )
}

enum LabPPScenario: String, CaseIterable {
    case done = "1,204 rows in 1.3 s"
    case failed = "Failed"
    case running = "Running"
}

private struct LabPPCard: View {
    let style: ResultsPillPopoversRound.Style
    let scenario: LabPPScenario
    @State private var open: String?

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            LabWKGrid(rows: scenario == .done ? LabWKGrid.checkpointRows + LabWKGrid.checkpointRows : [])
            Spacer(minLength: 0)
            LabWKFooter(pills: pills)
        }
        .workspaceCard()
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Workspace.canvas)
    }

    private func toggle(_ id: String) { open = open == id ? nil : id }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { open == id }, set: { if !$0, open == id { open = nil } })
    }

    private var pills: [LabWKPill] {
        let rows = LabWKPill(id: "rows", onTap: { toggle("rows") }) {
            HStack(spacing: SpacingTokens.xxxs) {
                Text(scenario == .done ? "1,204" : "0").font(TypographyTokens.detail.monospaced().weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
                Text("rows").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
            }
            .popover(isPresented: binding("rows"), arrowEdge: .top) {
                if style == .today { LabPPTodayPopover() } else { LabPPRowsPopover(actions: style == .eachWithActions) }
            }
        }
        let time = LabWKPill(id: "time", onTap: { toggle("time") }) {
            Text(scenario == .running ? "0:12" : "1.3s").font(TypographyTokens.detail.monospaced().weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
                .popover(isPresented: binding("time"), arrowEdge: .top) {
                    if style == .today { LabPPTodayPopover() } else { LabPPTimePopover(actions: style == .eachWithActions) }
                }
        }
        let (word, tint): (String, Color) = switch scenario {
        case .done: ("Completed", ColorTokens.Status.success)
        case .failed: ("Error", ColorTokens.Status.error)
        case .running: ("Running", ColorTokens.Status.warning)
        }
        let status = LabWKPill(id: "status", onTap: { toggle("status") }) {
            HStack(spacing: SpacingTokens.xxs) {
                Circle().fill(tint).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
                Text(word).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            }
            .popover(isPresented: binding("status"), arrowEdge: .top) {
                if style == .today { LabPPTodayPopover() } else { LabPPStatusPopover(scenario: scenario, actions: style == .eachWithActions) }
            }
        }
        return [rows, time, status]
    }
}

/// Today's one popover.
private struct LabPPTodayPopover: View {
    var body: some View {
        HStack(spacing: SpacingTokens.lg) {
            ForEach([("First row", "—"), ("Total", "104 ms"), ("Rows", "0"), ("Memory", "367,7 MB")], id: \.0) { item in
                VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                    Text(item.0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    Text(item.1).font(TypographyTokens.prominent.monospacedDigit())
                }
            }
        }
        .padding(SpacingTokens.md)
    }
}

/// A label–value line in a popover.
private struct LabPPLine: View {
    let label: String
    let value: String
    var body: some View {
        HStack { Text(label).foregroundStyle(ColorTokens.Text.secondary); Spacer(); Text(value).monospacedDigit() }.font(TypographyTokens.standard)
    }
}

private struct LabPPRowsPopover: View {
    let actions: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("1,204 rows · 3 columns").font(TypographyTokens.headline)
            LabPPLine(label: "Result", value: "1 of 1")
            LabPPLine(label: "Loaded", value: "1,204 of 1,204")
            LabPPLine(label: "In memory", value: "412 KB")
            if actions {
                Divider()
                HStack { Button("Export…") {}; Button("Copy All") {}; Spacer() }.controlSize(.small)
            }
        }
        .padding(SpacingTokens.md).frame(width: 260)
    }
}

private struct LabPPTimePopover: View {
    let actions: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            Text("1.3 s").font(TypographyTokens.headline)
            GeometryReader { geo in
                HStack(spacing: SpacingTokens.none) {
                    Rectangle().fill(ColorTokens.Text.tertiary).frame(width: geo.size.width * 0.06)
                    Rectangle().fill(ColorTokens.Status.warning).frame(width: geo.size.width * 0.54)
                    Rectangle().fill(ColorTokens.accent)
                }
                .clipShape(Capsule())
            }
            .frame(height: SpacingTokens.xs)
            HStack(spacing: SpacingTokens.sm) {
                Label("Sent", systemImage: "circle.fill").foregroundStyle(ColorTokens.Text.tertiary)
                Label("Waiting 0.7 s", systemImage: "circle.fill").foregroundStyle(ColorTokens.Status.warning)
                Label("Rows 0.5 s", systemImage: "circle.fill").foregroundStyle(ColorTokens.accent)
            }
            .font(TypographyTokens.detail).labelStyle(LabPPDotLabel())
            LabPPLine(label: "Server CPU", value: "24 ms")
            LabPPLine(label: "Started", value: "15:34:50")
            LabPPLine(label: "Last runs", value: "1.1 s · 1.4 s · 1.2 s")
            if actions { Divider(); HStack { Button("Run Again") {}; Button("Execution Plan") {}; Spacer() }.controlSize(.small) }
        }
        .padding(SpacingTokens.md).frame(width: 300)
    }
}

private struct LabPPStatusPopover: View {
    let scenario: LabPPScenario
    let actions: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            switch scenario {
            case .done:
                Text("Completed at 15:34:51").font(TypographyTokens.headline)
                LabPPLine(label: "Session", value: "SPID 52")
                LabPPLine(label: "Transaction", value: "None open")
                LabPPLine(label: "Messages", value: "None")
            case .failed:
                Text("Failed on line 7").font(TypographyTokens.headline)
                Text("The conversion of the varchar value '2610000125260' overflowed an int column.").font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.secondary).fixedSize(horizontal: false, vertical: true)
                if actions { HStack { Button("Show in Editor") {}; Button("Messages") {}; Spacer() }.controlSize(.small) }
            case .running:
                Text("Running for 0:12").font(TypographyTokens.headline)
                LabPPLine(label: "Session", value: "SPID 52 · waiting LCK_M_S")
                if actions { HStack { Button("Cancel") {}; Spacer() }.controlSize(.small) }
            }
        }
        .padding(SpacingTokens.md).frame(width: 280)
    }
}

private struct LabPPDotLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: SpacingTokens.xxs) { configuration.icon.font(TypographyTokens.compact); configuration.title.foregroundStyle(ColorTokens.Text.secondary) }
    }
}
