import SwiftUI

/// Sample data and the shared column for round 39's pages.
struct LabRTBookmark: Identifiable, Hashable {
    let id: String
    let title: String
    let sql: String
    let server: String
    let database: String
    var folder = "Unfiled"
    var note: String?

    static let samples: [LabRTBookmark] = [
        .init(id: "b1", title: "Last checkpoints", sql: "select * from dbo.aml_checkpoint", server: "dkloosql10-p", database: "ESB_INTEGRATION", folder: "AML"),
        .init(id: "b2", title: "Reset OH checkpoint", sql: "update aml_checkpoint set keyValue = '20260801' where keyName = 'aml_last_oh'",
              server: "dkloosql10-p", database: "ESB_INTEGRATION", folder: "AML", note: "Only after the OH import failed"),
        .init(id: "b3", title: "Bags without seal", sql: "select bagno, Centre from ba_tbl where seal is null", server: "dkloosql10-p", database: "ccsLDK10", folder: "Bags"),
        .init(id: "b4", title: "Blocking sessions", sql: "exec sp_WhoIsActive @find_block_leaders = 1", server: "dkloosql10-p", database: "DBA", folder: "DBA"),
        .init(id: "b5", title: "Orders today", sql: "select count(*) from orders where created_at::date = current_date", server: "postgres18", database: "shop"),
    ]
}

struct LabRTHistoryEntry: Identifiable, Hashable {
    let id: String
    let sql: String
    let database: String
    let time: String
    let day: String
    let duration: String
    let rows: String
    let failed: Bool

    static let samples: [LabRTHistoryEntry] = [
        .init(id: "h1", sql: "select * from dbo.aml_checkpoint", database: "ESB_INTEGRATION", time: "15:34", day: "Today", duration: "117 ms", rows: "3 rows", failed: false),
        .init(id: "h2", sql: "select * from ba_tbl where uniqueBagID <> 123456", database: "ccsLDK10", time: "15:31", day: "Today", duration: "104 ms", rows: "Error 248", failed: true),
        .init(id: "h3", sql: "update aml_checkpoint set keyValue = '20260801'…", database: "ESB_INTEGRATION", time: "14:02", day: "Today", duration: "12 ms", rows: "1 row changed", failed: false),
        .init(id: "h4", sql: "select bagno, histDate, Centre from ba_history…", database: "ccsLDK10", time: "11:47", day: "Today", duration: "4.2 s", rows: "89,214 rows", failed: false),
        .init(id: "h5", sql: "exec sp_WhoIsActive @find_block_leaders = 1", database: "DBA", time: "17:20", day: "Yesterday", duration: "880 ms", rows: "12 rows", failed: false),
        .init(id: "h6", sql: "select count(*) from orders where …", database: "shop", time: "09:12", day: "Yesterday", duration: "3 ms", rows: "1 row", failed: false),
    ]
}

struct LabRTSnippet: Identifiable, Hashable {
    let id: String
    let name: String
    let prefix: String
    let body: String
    let group: String
    var isYours = false

    static let samples: [LabRTSnippet] = [
        .init(id: "s1", name: "Select top rows", prefix: "sel", body: "SELECT TOP (100) * FROM ${table}", group: "Queries"),
        .init(id: "s2", name: "Begin transaction", prefix: "tran", body: "BEGIN TRAN;\n${cursor}\nROLLBACK;", group: "Transactions"),
        .init(id: "s3", name: "Table sizes", prefix: "sizes", body: "SELECT t.name, SUM(p.rows) FROM sys.tables t …", group: "Server"),
        .init(id: "s4", name: "Who is active", prefix: "who", body: "EXEC sp_WhoIsActive @get_plans = 1", group: "Yours", isYours: true),
        .init(id: "s5", name: "AML checkpoint reset", prefix: "amlreset", body: "UPDATE aml_checkpoint SET keyValue = '${date}' WHERE keyName = '${key}'", group: "Yours", isYours: true),
    ]
}

/// The left column as a card (where the tree is), with a header.
struct LabRTColumn<Content: View>: View {
    let title: String
    var subtitle: String?
    var trailing: AnyView?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(title).font(SidebarRowConstants.serverHeaderFont)
                    if let subtitle { Text(subtitle).font(SidebarRowConstants.trailingFont).foregroundStyle(ColorTokens.Text.tertiary) }
                }
                Spacer()
                if let trailing { trailing }
            }
            .padding(.horizontal, SpacingTokens.sm).padding(.top, SpacingTokens.sm).padding(.bottom, SpacingTokens.xs)
            content
            Spacer(minLength: 0)
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .workspaceCard()
    }
}

/// The rail beside a column, with the tool pill's selected tool.
struct LabRTRail: View {
    var symbols = ["bookmark", "curlybraces", "clock", "list.clipboard"]
    var selected: Int?
    var body: some View {
        VStack {
            Text("DP").font(TypographyTokens.caption2.weight(.bold)).foregroundStyle(ColorTokens.Text.secondary)
                .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2).padding(SpacingTokens.xxs).glassEffect(.regular, in: .capsule)
            Spacer()
            VStack(spacing: SpacingTokens.xxs) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                    Image(systemName: symbol).font(TypographyTokens.standard)
                        .foregroundStyle(selected == index ? ColorTokens.accent : ColorTokens.Text.secondary)
                        .frame(width: SpacingTokens.lg2, height: SpacingTokens.lg2)
                        .background { if selected == index { Circle().fill(ColorTokens.Workspace.railSelection).shadow(ShadowTokens.railSelection) } }
                }
            }
            .padding(SpacingTokens.xxs).glassEffect(.regular, in: .capsule)
        }
        .frame(width: SpacingTokens.xl2)
    }
}

/// Rail, column and a slice of the editor, as the window shows them.
struct LabRTScene<Column: View>: View {
    var symbols = ["bookmark", "curlybraces", "clock", "list.clipboard"]
    var selected: Int? = 0
    @ViewBuilder var column: Column

    var body: some View {
        HStack(spacing: SpacingTokens.xs) {
            LabRTRail(symbols: symbols, selected: selected)
            column
            LabWKEditor().workspaceCard()
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Workspace.canvas)
    }
}
