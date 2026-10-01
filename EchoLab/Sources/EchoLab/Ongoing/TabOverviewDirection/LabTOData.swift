import SwiftUI

/// The tabs every round 35 page shows: nine tabs on two servers, a mix of queries and tool tabs,
/// one running, one failed, one never run.
struct LabTOTab: Identifiable, Hashable {
    enum Kind: String { case query = "Queries", jobs = "Jobs", activity = "Activity Monitor", diagram = "Diagrams" }
    enum Status: Hashable { case notRun, done(rows: String), running(String), failed }

    let id: String
    let title: String
    let kind: Kind
    let server: String
    let database: String?
    let sql: [String]
    let status: Status
    let ago: String

    var symbol: String {
        switch kind {
        case .query: "tablecells"
        case .jobs: "clock"
        case .activity: "waveform.path.ecg"
        case .diagram: "point.3.connected.trianglepath.dotted"
        }
    }

    var statusText: String {
        switch status {
        case .notRun: "Not run"
        case .done(let rows): rows
        case .running(let time): "Running \(time)"
        case .failed: "Failed"
        }
    }

    var statusTint: Color {
        switch status {
        case .notRun: ColorTokens.Text.tertiary
        case .done: ColorTokens.Status.success
        case .running: ColorTokens.Status.warning
        case .failed: ColorTokens.Status.error
        }
    }

    static let servers = ["dkloosql10-p", "postgres18"]

    static let samples: [LabTOTab] = [
        .init(id: "q1", title: "Query 1", kind: .query, server: "dkloosql10-p", database: "ESB_INTEGRATION",
              sql: ["select *", "from dbo.aml_checkpoint", "", "update aml_checkpoint", "set keyValue = '20260801'"], status: .done(rows: "3 rows"), ago: "57 s ago"),
        .init(id: "q2", title: "Query 2", kind: .query, server: "dkloosql10-p", database: "ESB_INTEGRATION", sql: [], status: .notRun, ago: "2 min ago"),
        .init(id: "q3", title: "Bag history", kind: .query, server: "dkloosql10-p", database: "ccsLDK10",
              sql: ["select bagno, histDate, Centre", "from ba_history", "where histDate > '2026-09-01'"], status: .running("0:12"), ago: "now"),
        .init(id: "q4", title: "Query 4", kind: .query, server: "dkloosql10-p", database: "ccsLDK10",
              sql: ["select *", "from ba_tbl", "where uniqueBagID <> 123456"], status: .failed, ago: "4 min ago"),
        .init(id: "jobs", title: "Jobs", kind: .jobs, server: "dkloosql10-p", database: nil, sql: [], status: .done(rows: "24 jobs"), ago: "6 min ago"),
        .init(id: "am", title: "Activity Monitor", kind: .activity, server: "dkloosql10-p", database: nil, sql: [], status: .running("live"), ago: "now"),
        .init(id: "pg1", title: "orders.sql", kind: .query, server: "postgres18", database: "shop",
              sql: ["select o.id, c.name, o.total", "from orders o", "join customers c on c.id = o.customer_id"], status: .done(rows: "1,204 rows"), ago: "12 min ago"),
        .init(id: "pg2", title: "Query 6", kind: .query, server: "postgres18", database: "analytics",
              sql: ["select date_trunc('day', at), count(*)", "from events group by 1"], status: .done(rows: "31 rows"), ago: "1 h ago"),
        .init(id: "pgd", title: "shop diagram", kind: .diagram, server: "postgres18", database: "shop", sql: [], status: .notRun, ago: "1 h ago"),
    ]

    static let activeID = "q1"
}

/// What a card's picture shows (round 35.2).
enum LabTOThumbnail: String, CaseIterable {
    case today = "TP0 · The SQL on a blue wash (today)"
    case code = "TP1 · The SQL as the editor shows it"
    case result = "TP2 · The result: a few rows of the grid"
    case split = "TP3 · SQL above, the result's first rows below"
    case symbol = "TP4 · No picture: the tab's symbol on a tint"
    case snapshot = "TP5 · A snapshot of the whole tab"
}

/// What a card says under its picture (round 35.2).
enum LabTOInfo: String, CaseIterable {
    case today = "CI0 · Title with an Active badge, then chips: when and rows (today)"
    case twoLines = "CI1 · Title, then database · status"
    case titleOnly = "CI2 · Title only; status on the picture"
}

/// How a card shows a running or failed tab (round 35.2).
enum LabTOStatusLook: String, CaseIterable {
    case dot = "SD0 · A coloured dot by the words (today)"
    case ring = "SD1 · The card's edge in the colour while running or failed"
    case badge = "SD2 · A badge on the picture's corner"
}

/// One tab's card, in the look a direction or round 35.2 asks for.
struct LabTOCard: View {
    let tab: LabTOTab
    var thumbnail: LabTOThumbnail = .snapshot
    var isActive = false
    var showsDatabase = true
    var compact = false
    var info: LabTOInfo = .twoLines
    var statusLook: LabTOStatusLook = .dot
    var closeOnHover = true
    @State private var isHovering = false

    private var isAlarm: Bool {
        switch tab.status {
        case .running, .failed: true
        default: false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            picture
                .frame(height: compact ? SpacingTokens.xxxl : SpacingTokens.xxxl + SpacingTokens.lg2)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if statusLook == .badge || info == .titleOnly, tab.statusText != "Not run" {
                        Text(tab.statusText).font(TypographyTokens.label.weight(.semibold)).foregroundStyle(ColorTokens.Text.onFill)
                            .padding(.horizontal, SpacingTokens.xxs2).padding(.vertical, SpacingTokens.xxxs)
                            .background(tab.statusTint, in: Capsule()).padding(SpacingTokens.xxs2)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if closeOnHover, isHovering {
                        Image(systemName: "xmark").font(TypographyTokens.label.weight(.bold))
                            .frame(width: SpacingTokens.md, height: SpacingTokens.md)
                            .glassEffect(.regular, in: Circle()).padding(SpacingTokens.xxs2)
                    }
                }
            footer.padding(SpacingTokens.xs)
        }
        .background(ColorTokens.Workspace.card)
        .clipShape(.rect(cornerRadius: SpacingTokens.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SpacingTokens.sm, style: .continuous)
                .strokeBorder(edgeColor, lineWidth: isActive || (statusLook == .ring && isAlarm) ? 2 : 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .onHover { isHovering = $0 }
    }

    private var edgeColor: Color {
        if statusLook == .ring, isAlarm { return tab.statusTint }
        return isActive ? ColorTokens.accent : ColorTokens.Separator.primary
    }

    @ViewBuilder
    private var footer: some View {
        switch info {
        case .today:
            VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
                HStack(spacing: SpacingTokens.xxs2) {
                    Circle().fill(tab.statusTint).frame(width: SpacingTokens.xs, height: SpacingTokens.xs)
                    Text(tab.title).font(TypographyTokens.standard.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    if isActive {
                        Text("Active").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.accent)
                            .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                            .background(ColorTokens.accent.opacity(0.12), in: Capsule())
                    }
                }
                HStack(spacing: SpacingTokens.xxs) {
                    chip(tab.ago.uppercased(), symbol: "clock")
                    chip(tab.statusText, symbol: "tablecells")
                }
            }
        case .twoLines, .titleOnly:
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                HStack(spacing: SpacingTokens.xxs2) {
                    Image(systemName: tab.symbol).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    Text(tab.title).font(TypographyTokens.standard.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    if case .running = tab.status { ProgressView().controlSize(.mini) }
                }
                if info == .twoLines {
                    HStack(spacing: SpacingTokens.xxs) {
                        if statusLook == .dot { Circle().fill(tab.statusTint).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2) }
                        Text([showsDatabase ? tab.database : nil, tab.statusText].compactMap { $0 }.joined(separator: " · "))
                            .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                    }
                }
            }
        }
    }

    private func chip(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
            .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
    }

    @ViewBuilder
    private var picture: some View {
        switch thumbnail {
        case .today:
            LabTOCode(lines: tab.sql, size: 8).padding(SpacingTokens.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LinearGradient(colors: [ColorTokens.accent.opacity(0.18), ColorTokens.accent.opacity(0.06)], startPoint: .top, endPoint: .bottom))
        case .code:
            LabTOCode(lines: tab.sql, size: 8, coloured: true).padding(SpacingTokens.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(ColorTokens.Sidebar.hoverFill)
        case .result:
            LabTOMiniGrid(tab: tab).background(ColorTokens.Sidebar.hoverFill)
        case .split:
            VStack(spacing: SpacingTokens.none) {
                LabTOCode(lines: Array(tab.sql.prefix(2)), size: 7, coloured: true).padding(SpacingTokens.xxs2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Divider()
                LabTOMiniGrid(tab: tab)
            }
            .background(ColorTokens.Sidebar.hoverFill)
        case .symbol:
            Image(systemName: tab.symbol).font(TypographyTokens.title2).foregroundStyle(tab.statusTint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tab.statusTint.opacity(0.08))
        case .snapshot:
            LabTOSnapshot(tab: tab)
        }
    }
}

/// SQL drawn small.
struct LabTOCode: View {
    let lines: [String]
    var size: CGFloat = 8
    var coloured = false
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            if lines.isEmpty {
                Text("Empty query").font(TypographyTokens.compact.monospaced()).italic().foregroundStyle(ColorTokens.Text.tertiary)
            }
            ForEach(Array(lines.prefix(6).enumerated()), id: \.offset) { _, line in
                if coloured { LabWKSQLText(line: line).font(TypographyTokens.compact.monospaced()).lineLimit(1) }
                else { Text(line).font(TypographyTokens.compact.monospaced()).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1) }
            }
        }
    }
}

/// A few rows of a result, or the tool's own content, drawn small.
struct LabTOMiniGrid: View {
    let tab: LabTOTab
    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: SpacingTokens.xxs) {
                    ForEach(0..<4, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(row == 0 ? ColorTokens.Text.secondary.opacity(0.5) : ColorTokens.Text.tertiary.opacity(0.35))
                            .frame(height: SpacingTokens.xxs)
                            .frame(maxWidth: column == 0 ? SpacingTokens.lg : .infinity)
                    }
                }
                .frame(height: SpacingTokens.xs2)
                .padding(.horizontal, SpacingTokens.xxs2)
                .background(row.isMultiple(of: 2) ? Color.clear : ColorTokens.Sidebar.hoverFill)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, SpacingTokens.xxs)
    }
}

/// The whole tab, shrunk: editor over results for a query, or the tool's panes.
struct LabTOSnapshot: View {
    let tab: LabTOTab
    var body: some View {
        VStack(spacing: SpacingTokens.xxxs) {
            switch tab.kind {
            case .query:
                LabTOCode(lines: tab.sql, size: 6, coloured: true).padding(SpacingTokens.xxs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xxs))
                if case .notRun = tab.status {} else {
                    LabTOMiniGrid(tab: tab).frame(maxHeight: .infinity)
                        .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xxs))
                }
            case .jobs, .activity:
                HStack(spacing: SpacingTokens.xxxs) {
                    LabTOMiniGrid(tab: tab).background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xxs))
                    LabTOMiniGrid(tab: tab).background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xxs))
                }
            case .diagram:
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2).strokeBorder(ColorTokens.accent.opacity(0.6))
                            .frame(width: SpacingTokens.xl, height: SpacingTokens.lg)
                            .offset(x: CGFloat(index - 1) * SpacingTokens.xl2, y: CGFloat(index % 2) * SpacingTokens.sm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xxs))
            }
        }
        .padding(SpacingTokens.xxs)
        .background(ColorTokens.Workspace.canvas)
    }
}
