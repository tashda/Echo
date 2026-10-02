import SwiftUI

/// Every kind of tab with its icon today and the proposed one; it says which today's icons repeat
/// and which do not exist on macOS 26 (and so draw nothing).
struct LabTBarIconGallery: View {
    let icons: LabTBarIcons

    private var repeats: [String: [String]] {
        Dictionary(grouping: LabTBarKind.all, by: \.today).mapValues { $0.map(\.name) }.filter { $0.value.count > 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            header
            ForEach(LabTBarKind.all) { kind in row(kind) }
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.sm) {
            Text("Tab").frame(width: 190, alignment: .leading)
            Text("Today").frame(width: 190, alignment: .leading)
            Text("Proposed").frame(width: 110, alignment: .leading)
            Text("Family").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
    }

    private func row(_ kind: LabTBarKind) -> some View {
        let missing = !LabTBarKind.exists(kind.today)
        let sharedWith = (repeats[kind.today] ?? []).filter { $0 != kind.name }
        return HStack(spacing: SpacingTokens.sm) {
            Text(kind.name).font(TypographyTokens.detail).frame(width: 190, alignment: .leading)
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: kind.today).frame(width: SpacingTokens.md)
                if missing {
                    Text("does not exist: draws nothing").foregroundStyle(ColorTokens.Status.error)
                } else if !sharedWith.isEmpty {
                    Text("same as \(sharedWith.first ?? "")").foregroundStyle(ColorTokens.Status.warning)
                }
            }
            .font(TypographyTokens.detail).frame(width: 190, alignment: .leading)
            Image(systemName: kind.proposed)
                .foregroundStyle(icons == .family ? kind.family.tint : ColorTokens.Text.primary)
                .frame(width: 110, alignment: .leading)
            Text(familyName(kind.family)).font(TypographyTokens.detail).foregroundStyle(kind.family.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(TypographyTokens.standard)
    }

    private func familyName(_ family: LabTBarFamily) -> String {
        switch family {
        case .query: "Query"
        case .monitor: "Monitor"
        case .manage: "Manage"
        case .health: "Health"
        case .properties: "Properties"
        case .canvas: "Canvas"
        }
    }
}

/// How much room each tool's pages need, and in which windows they fit (FP1 and FP3).
struct LabTBarMeasurements: View {
    private struct Row: Identifiable {
        var id: String { title + engine }
        let title: String
        let engine: String
        let pages: [String]
    }

    private static let rows: [Row] = [
        Row(title: "Advanced Objects", engine: "PostgreSQL", pages: LabTBarTool.advanced.pages(.all)),
        Row(title: "Advanced Objects", engine: "PostgreSQL, grouped", pages: LabTBarTool.advanced.pages(.grouped)),
        Row(title: "Activity Monitor", engine: "PostgreSQL", pages: LabTBarTool.activity.pages(.all)),
        Row(title: "Database Security", engine: "MySQL", pages: LabTBarTool.security.pages(.all)),
        Row(title: "Activity Monitor", engine: "MySQL", pages: ["Overview", "Processes", "Queries", "Waits", "I/O", "InnoDB", "Repl", "Reports", "Variables"]),
        Row(title: "Database Security", engine: "SQL Server", pages: ["Users", "Roles", "App Roles", "Schemas", "Certificates", "Masking", "RLS", "Audit Specs", "Encryption"]),
        Row(title: "Server Properties", engine: "SQL Server", pages: ["Overview", "Control", "Variables", "Status", "Logs", "Configuration"]),
        Row(title: "Table Structure", engine: "PostgreSQL", pages: ["Columns", "Indexes", "Constraints", "Relations", "Partitions", "Inheritance"]),
        Row(title: "Maintenance", engine: "SQL Server", pages: LabTBarTool.maintenance.pages(.all)),
        Row(title: "Policy Management", engine: "SQL Server", pages: LabTBarTool.policy.pages(.all)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
            HStack(spacing: SpacingTokens.sm) {
                Text("Tool").frame(width: 230, alignment: .leading)
                Text("Pages").frame(width: 44, alignment: .trailing)
                Text("Tab needs").frame(width: 80, alignment: .trailing)
                Text("Compact").frame(width: 70, alignment: .trailing)
                ForEach(LabTBarWindow.allCases, id: \.self) { window in
                    Text("\(Int(window.windowWidth))").frame(width: 70, alignment: .center)
                }
            }
            .font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
            ForEach(Self.rows) { row in line(row) }
            Text("Needs: title, hairline, icon, close and every page at 11pt. Compact: 6pt page padding and shorter names. A window fits a tool when the tool tab can take the strip less 40pt for each of three other tabs.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 400, alignment: .leading).padding(.top, SpacingTokens.xs)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    private func line(_ row: Row) -> some View {
        let tab = LabTBarTab(id: row.id, title: row.title, kind: .query, server: 0, pages: row.pages)
        let full = LabTBarMetrics.needed(tab, compact: false, icon: true)
        let compact = LabTBarMetrics.needed(tab, compact: true, icon: true)
        return HStack(spacing: SpacingTokens.sm) {
            Text("\(row.title) · \(row.engine)").frame(width: 230, alignment: .leading)
            Text("\(row.pages.count)").frame(width: 44, alignment: .trailing)
            Text("\(Int(full)) pt").frame(width: 80, alignment: .trailing)
            Text("\(Int(compact)) pt").frame(width: 70, alignment: .trailing)
            ForEach(LabTBarWindow.allCases, id: \.self) { window in
                let room = window.stripWidth - 3 * LabTBarMetrics.iconOnlyWidth
                Text(full <= room ? "full" : (compact <= room ? "compact" : "no"))
                    .foregroundStyle(full <= room ? ColorTokens.Status.success : (compact <= room ? ColorTokens.Status.warning : ColorTokens.Status.error))
                    .frame(width: 70, alignment: .center)
            }
        }
        .font(TypographyTokens.detail)
    }
}

/// The results footer's server / database pill, with and without the server's dot.
struct LabTBarPill: View {
    let showsDot: Bool

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            if showsDot {
                Circle().fill(ColorTokens.Status.success).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
            }
            Text("dkloosql10-p › shop").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.primary)
        }
        .padding(.horizontal, LayoutTokens.Footer.chipHorizontalPadding)
        .frame(height: LayoutTokens.Footer.chipHeight)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Today's pill beside the proposal's, on the footer's own line.
struct LabTBarPillPair: View {
    let proposalShowsDot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            row("Echo today", showsDot: true)
            row("Proposal", showsDot: proposalShowsDot)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    private func row(_ name: String, showsDot: Bool) -> some View {
        HStack(spacing: SpacingTokens.md) {
            Text(name).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).frame(width: 80, alignment: .leading)
            LabTBarPill(showsDot: showsDot)
            Spacer(minLength: 0)
            Text("1,204 rows · 1.3 s").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
        }
    }
}

/// AO2: the four tools that Advanced Objects (PostgreSQL) would become, with the room each needs.
struct LabTBarSplitMap: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            ForEach(LabTBarSplitPart.allCases, id: \.self) { part in
                let tab = LabTBarTab(id: part.rawValue, title: part.rawValue, kind: .named("Advanced Objects (PostgreSQL)"), server: 0, pages: part.pages)
                HStack(spacing: SpacingTokens.sm) {
                    Label(part.rawValue, systemImage: tab.kind.proposed).font(TypographyTokens.detail.weight(.medium))
                        .frame(width: 190, alignment: .leading)
                    HStack(spacing: LabTBarMetrics.chipSpacing) {
                        ForEach(part.pages, id: \.self) { page in
                            Text(page).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                                .padding(.horizontal, LabTBarMetrics.chipPadding).frame(height: LayoutTokens.TabPages.chipHeight)
                                .background(ColorTokens.TabStrip.Pages.selected.opacity(0.5), in: Capsule())
                        }
                    }
                    Spacer(minLength: 0)
                    Text("\(part.pages.count) pages · \(Int(LabTBarMetrics.needed(tab, compact: false, icon: true))) pt")
                        .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                }
            }
            Text("Each opens from its own row under Advanced Objects in the Explorer; none has a page that is not in the list. Total: 13 pages, as today.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                .fixedSize(horizontal: false, vertical: true).frame(minWidth: 400, alignment: .leading)
        }
        .padding(SpacingTokens.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }
}
