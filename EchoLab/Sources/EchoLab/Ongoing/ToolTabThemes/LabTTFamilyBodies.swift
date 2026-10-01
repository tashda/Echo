import SwiftUI

/// One family's tab in the unified design: 37.2's two-row header with 37.3's controls, then the
/// family's own body.
struct LabTTFamilyTab: View {
    let family: LabTTFamily
    var tilesOnMonitors = true
    var fixButtons = true
    var applyBar = true

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LabTTHeaderView(tool: tool, look: LabTTLook(), running: false)
            bodyView
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    private var tool: LabTTTool {
        switch family {
        case .monitor: .activity
        case .manage: .policy
        case .health: LabTTTool(name: "Maintenance", symbol: "stethoscope", tint: Color(nsColor: .systemPink), subtitle: "dkloosql10-p · ccsLDK10 · checked 3 min ago",
                                pages: ["Health", "Tables", "Indexes", "Backups"], primary: ("Check Now", "checkmark.circle"), searchPrompt: "Search findings")
        case .properties: LabTTTool(name: "Server Properties", symbol: "server.rack", tint: Color(nsColor: .systemGray), subtitle: "dkloosql10-p · SQL Server 2017",
                                    pages: ["Overview", "Memory", "Processors", "Security", "Connections"], searchPrompt: "Search settings")
        case .canvas: LabTTTool(name: "Schema Diagram", symbol: "point.3.connected.trianglepath.dotted", tint: Color(nsColor: .systemPurple),
                                subtitle: "postgres18 · shop · 12 tables", primary: ("Add Table", "plus"), secondary: [("square.and.arrow.up", "Export")])
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        switch family {
        case .monitor: monitor
        case .manage: manage
        case .health: health
        case .properties: properties
        case .canvas: canvas
        }
    }

    private var monitor: some View {
        VStack(spacing: SpacingTokens.xs) {
            if tilesOnMonitors {
                HStack(spacing: SpacingTokens.xs) {
                    ForEach([("CPU", "12%"), ("Waiting", "179"), ("I/O", "2 MB/s"), ("Throughput", "154/s")], id: \.0) { tile in
                        VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                            Text(tile.0).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                            Text(tile.1).font(TypographyTokens.title2.monospacedDigit())
                            LabTTSparkline().frame(height: SpacingTokens.lg)
                        }
                        .padding(SpacingTokens.sm).frame(maxWidth: .infinity, alignment: .leading).workspaceCard()
                    }
                }
            }
            LabTTRows(columns: ["ID", "User", "Wait", "Command", "CPU"], rows: [["52", "sa", "LCK_M_S", "SELECT", "120 ms"], ["53", "app", "", "UPDATE", "4 ms"],
                                                                                ["61", "GLOBAL\\k", "PAGEIOLATCH", "SELECT", "2 s"], ["70", "sa", "", "BACKUP", "18 s"]])
                .workspaceCard()
        }
    }

    private var manage: some View {
        HStack(spacing: SpacingTokens.xs) {
            LabTTRows(columns: ["", "Policy", "Category"], rows: [["●", "Backups less than 24 h old", "Database Maintenance"], ["●", "Password policy", "Security"],
                                                                 ["○", "Auto shrink off", "Database Maintenance"], ["●", "Page verify CHECKSUM", "Database Maintenance"]],
                      selected: 0)
                .workspaceCard()
            VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                Text("Backups less than 24 h old").font(TypographyTokens.headline)
                LabeledContent("Condition", value: "LastBackupDate > now − 1 day")
                LabeledContent("Targets", value: "Every user database")
                LabeledContent("Evaluation", value: "On schedule · daily 06:00")
                LabeledContent("Last run", value: "Today 06:00 · 2 violations")
                Spacer()
            }
            .font(TypographyTokens.standard)
            .padding(SpacingTokens.sm).frame(width: 300).workspaceCard()
        }
    }

    private var health: some View {
        VStack(spacing: SpacingTokens.none) {
            ForEach([("xmark.octagon.fill", ColorTokens.Status.error, "Last full backup 9 days ago", "ccsLDK10 has no full backup since 22 Sep."),
                     ("exclamationmark.triangle.fill", ColorTokens.Status.warning, "Index fragmentation 64%", "IX_ba_tbl_bagno on dbo.ba_tbl"),
                     ("exclamationmark.triangle.fill", ColorTokens.Status.warning, "Auto-grow by 1 MB", "The log file grows in 1 MB steps."),
                     ("checkmark.circle.fill", ColorTokens.Status.success, "Integrity check passed", "DBCC CHECKDB on Sat 23:00")], id: \.2) { item in
                HStack(spacing: SpacingTokens.sm) {
                    Image(systemName: item.0).foregroundStyle(item.1)
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(item.2).font(TypographyTokens.standard.weight(.medium))
                        Text(item.3).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    }
                    Spacer()
                    if fixButtons, item.1 != ColorTokens.Status.success {
                        Text(item.1 == ColorTokens.Status.error ? "Back Up Now" : "Fix")
                            .font(TypographyTokens.detail.weight(.medium))
                            .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.xl2 + SpacingTokens.xxs)
                Divider().padding(.leading, SpacingTokens.xl2)
            }
            Spacer(minLength: 0)
        }
        .workspaceCard()
    }

    private var properties: some View {
        VStack(spacing: SpacingTokens.none) {
            Form {
                Section("Memory") {
                    LabeledContent("Minimum server memory", value: "0 MB")
                    LabeledContent("Maximum server memory", value: "28,672 MB")
                }
                Section("Processors") {
                    LabeledContent("Max degree of parallelism", value: "4")
                    LabeledContent("Cost threshold for parallelism", value: "50")
                }
            }
            .formStyle(.grouped).scrollContentBackground(.hidden)
            if applyBar {
                HStack {
                    Text("2 changes").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                    Button("Revert") {}
                    Button("Apply") {}.buttonStyle(.borderedProminent)
                }
                .padding(SpacingTokens.sm)
            }
        }
        .workspaceCard()
    }

    private var canvas: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                ForEach(Array(["orders", "customers", "order_items", "products"].enumerated()), id: \.offset) { index, name in
                    VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                        Text(name).font(TypographyTokens.detail.weight(.semibold))
                        ForEach(["id", "name", "created_at"], id: \.self) { Text($0).font(TypographyTokens.label.monospaced()).foregroundStyle(ColorTokens.Text.secondary) }
                    }
                    .padding(SpacingTokens.xs).frame(width: 120, alignment: .leading)
                    .background(ColorTokens.Workspace.card, in: .rect(cornerRadius: SpacingTokens.xs))
                    .overlay(RoundedRectangle(cornerRadius: SpacingTokens.xs).strokeBorder(ColorTokens.Separator.primary))
                    .offset(x: CGFloat(index % 2) * 200 - 100, y: CGFloat(index / 2) * 100 - 60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: SpacingTokens.md) {
                Image(systemName: "minus"); Text("100%").font(TypographyTokens.detail.monospacedDigit()); Image(systemName: "plus")
                Divider().frame(height: SpacingTokens.md)
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass"); Image(systemName: "square.grid.3x3")
            }
            .padding(.horizontal, SpacingTokens.md).frame(height: SpacingTokens.lg2)
            .glassEffect(.regular, in: .capsule)
            .padding(SpacingTokens.sm)
        }
        .background(ColorTokens.Sidebar.hoverFill)
        .workspaceCard()
    }
}

/// A plain table: a header line and rows, no stripes (37.1's UT1 with 32.1's ZB1).
struct LabTTRows: View {
    let columns: [String]
    let rows: [[String]]
    var selected: Int?

    var body: some View {
        VStack(spacing: SpacingTokens.none) {
            HStack { ForEach(columns, id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: .leading) } }
                .font(TypographyTokens.detail.weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg2)
            Divider()
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack { ForEach(Array(row.enumerated()), id: \.offset) { _, value in Text(value).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading) } }
                    .font(TypographyTokens.detail)
                    .padding(.horizontal, SpacingTokens.sm).frame(height: SpacingTokens.lg + SpacingTokens.xxs)
                    .background(selected == index ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: SpacingTokens.xxs2))
                    .padding(.horizontal, SpacingTokens.xxs)
            }
            Spacer(minLength: 0)
        }
    }
}

/// A sparkline drawn from fixed sample points.
struct LabTTSparkline: View {
    private let points: [CGFloat] = [0.3, 0.35, 0.28, 0.5, 0.42, 0.6, 0.38, 0.45, 0.7, 0.55]
    var body: some View {
        GeometryReader { geo in
            Path { path in
                for (index, value) in points.enumerated() {
                    let point = CGPoint(x: geo.size.width * CGFloat(index) / CGFloat(points.count - 1), y: geo.size.height * (1 - value))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(ColorTokens.accent, lineWidth: 1.5)
        }
    }
}
