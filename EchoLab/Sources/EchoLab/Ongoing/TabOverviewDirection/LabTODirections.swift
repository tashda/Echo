import SwiftUI

/// Round 35.1's eight directions for the whole overview, all drawn from `LabTOTab.samples`.
enum LabTODirection: String, CaseIterable {
    case today = "TO0 · Grouped by server, database and kind (today)"
    case grid = "TO1 · Safari: one grid of snapshots per server"
    case columns = "TO2 · A column per server"
    case list = "TO3 · A list you can search"
    case stacks = "TO4 · A stack per database, fanned"
    case timeline = "TO5 · By when you last used it"
    case palette = "TO6 · A floating palette over the tab"
    case sidebar = "TO7 · Servers on the left, their tabs on the right"

    var summary: String {
        switch self {
        case .today: "Server name in large bold with a count, a tinted band per database, UPPERCASE kind headings, cards with a blue SQL picture."
        case .grid: "Safari's tab overview: big snapshots of the real tab, a quiet server heading, the active tab ringed in accent. Nothing else."
        case .columns: "Each server is a column of compact cards, side by side; scales from one server to four."
        case .list: "One row per tab with its first line of SQL, status and when; a search field on top. Fastest with many tabs."
        case .stacks: "A database's tabs fan out like a stack of papers; click a stack to spread it."
        case .timeline: "Now, Earlier today, Older: cards in rows by when you last looked at them, whatever their server."
        case .palette: "No full-screen view: the ⌘K palette turned to this window's tabs (\"Tab Overview\", ⇧⌘O), over the dimmed tab. ⌫ closes, ⌘D duplicates, ⌥⌫ closes the others."
        case .sidebar: "Like Mail: servers and databases with counts on the left, the selected one's cards on the right."
        }
    }
}

/// The overview in a direction, filling its exhibit.
struct LabTODirectionView: View {
    let direction: LabTODirection
    var thumbnail: LabTOThumbnail = .snapshot
    private var tabs: [LabTOTab] { LabTOTab.samples }

    var body: some View {
        Group {
            switch direction {
            case .today: LabTOToday()
            case .grid: grid
            case .columns: columns
            case .list: LabTOList(tabs: tabs)
            case .stacks: stacks
            case .timeline: timeline
            case .palette: palette
            case .sidebar: sidebar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }

    private func serverTabs(_ server: String) -> [LabTOTab] { tabs.filter { $0.server == server } }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md) {
                ForEach(LabTOTab.servers, id: \.self) { server in
                    Text("\(server)  ").font(TypographyTokens.headline)
                        + Text("\(serverTabs(server).count) tabs").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm), count: 4), spacing: SpacingTokens.sm) {
                        ForEach(serverTabs(server)) { LabTOCard(tab: $0, thumbnail: thumbnail, isActive: $0.id == LabTOTab.activeID) }
                    }
                }
            }
            .padding(SpacingTokens.md)
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            ForEach(LabTOTab.servers, id: \.self) { server in
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Label(server, systemImage: "cylinder.split.1x2").font(TypographyTokens.headline)
                    ScrollView {
                        VStack(spacing: SpacingTokens.xs) {
                            ForEach(serverTabs(server)) { LabTOCard(tab: $0, thumbnail: thumbnail, isActive: $0.id == LabTOTab.activeID, compact: true) }
                        }
                    }
                }
                .padding(SpacingTokens.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ColorTokens.Sidebar.hoverFill, in: .rect(cornerRadius: SpacingTokens.md, style: .continuous))
            }
        }
        .padding(SpacingTokens.md)
    }

    private var stacks: some View {
        let groups = Dictionary(grouping: tabs) { "\($0.server) · \($0.database ?? "Server")" }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.lg), count: 3), spacing: SpacingTokens.lg) {
            ForEach(groups.keys.sorted(), id: \.self) { key in
                let group = groups[key] ?? []
                VStack(spacing: SpacingTokens.xs) {
                    ZStack {
                        ForEach(Array(group.prefix(3).enumerated().reversed()), id: \.offset) { index, tab in
                            LabTOCard(tab: tab, thumbnail: thumbnail, isActive: tab.id == LabTOTab.activeID, compact: true)
                                .rotationEffect(.degrees(Double(index) * 4 - 4))
                                .offset(x: CGFloat(index) * SpacingTokens.xxs2, y: CGFloat(index) * -SpacingTokens.xxs)
                        }
                    }
                    Text(key).font(TypographyTokens.detail.weight(.semibold)).lineLimit(1)
                    Text("\(group.count) \(group.count == 1 ? "tab" : "tabs")").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                }
            }
        }
        .padding(SpacingTokens.lg)
    }

    private var timeline: some View {
        let sections: [(String, [LabTOTab])] = [
            ("Now", tabs.filter { $0.ago == "now" || $0.ago.hasSuffix("s ago") }),
            ("Earlier today", tabs.filter { $0.ago.hasSuffix("min ago") }),
            ("Over an hour ago", tabs.filter { $0.ago.hasSuffix("h ago") }),
        ]
        return VStack(alignment: .leading, spacing: SpacingTokens.md) {
            ForEach(sections, id: \.0) { title, items in
                Text(title).font(TypographyTokens.headline)
                ScrollView(.vertical) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm), count: 5), spacing: SpacingTokens.sm) {
                        ForEach(items) { LabTOCard(tab: $0, thumbnail: thumbnail, isActive: $0.id == LabTOTab.activeID, compact: true) }
                    }
                }
                .frame(maxHeight: SpacingTokens.xxxl * 2)
            }
        }
        .padding(SpacingTokens.md)
    }

    private var palette: some View {
        ZStack {
            LabWKEditor().workspaceCard().padding(SpacingTokens.md).opacity(0.5)
            ColorTokens.Workspace.canvas.opacity(0.4)
            VStack(spacing: SpacingTokens.none) {
                HStack {
                    Image(systemName: "square.grid.2x2").foregroundStyle(ColorTokens.Text.secondary)
                    Text("Tab Overview: search this window's tabs").foregroundStyle(ColorTokens.Text.tertiary)
                    Spacer()
                }
                .font(TypographyTokens.prominent)
                .padding(SpacingTokens.sm)
                LabTOList(tabs: tabs, compact: true, showsSearch: false)
                HStack(spacing: SpacingTokens.sm) {
                    Text("↩ Go to Tab"); Text("⌫ Close Tab"); Text("⌘D Duplicate"); Text("⌥⌫ Close Others"); Text("⎋ Done")
                    Spacer()
                }
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
                .padding(SpacingTokens.sm)
            }
            .frame(width: 440, height: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.md2))
        }
    }

    private var sidebar: some View {
        HStack(spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                ForEach(LabTOTab.servers, id: \.self) { server in
                    Text(server).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary).padding(.top, SpacingTokens.xs)
                    let databases = Array(Set(serverTabs(server).map { $0.database ?? "Server" })).sorted()
                    ForEach(databases, id: \.self) { database in
                        HStack {
                            Label(database, systemImage: database == "Server" ? "server.rack" : "cylinder")
                            Spacer()
                            Text("\(serverTabs(server).filter { ($0.database ?? "Server") == database }.count)").foregroundStyle(ColorTokens.Text.tertiary)
                        }
                        .font(TypographyTokens.standard)
                        .padding(.horizontal, SpacingTokens.xs).frame(height: SpacingTokens.lg)
                        .background(database == "ESB_INTEGRATION" ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: SpacingTokens.xxs2))
                    }
                }
                Spacer()
            }
            .padding(SpacingTokens.sm)
            .frame(width: 210)
            .workspaceCard()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sm), count: 2), spacing: SpacingTokens.sm) {
                ForEach(tabs.filter { $0.database == "ESB_INTEGRATION" }) { LabTOCard(tab: $0, thumbnail: thumbnail, isActive: $0.id == LabTOTab.activeID) }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(SpacingTokens.md)
    }
}

/// TO3: one row per tab, grouped by server, with a search field.
struct LabTOList: View {
    let tabs: [LabTOTab]
    var compact = false
    var showsSearch = true
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            if showsSearch {
                TextField("Search tabs", text: $query, prompt: Text("Search tabs, SQL and databases"))
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                    .padding(.bottom, SpacingTokens.xs)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.none) {
                    ForEach(LabTOTab.servers, id: \.self) { server in
                        Text(server).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.top, SpacingTokens.xs).padding(.bottom, SpacingTokens.xxxs)
                        ForEach(filtered.filter { $0.server == server }) { row($0) }
                    }
                }
            }
        }
        .padding(compact ? SpacingTokens.xs : SpacingTokens.md)
    }

    private var filtered: [LabTOTab] {
        guard !query.isEmpty else { return tabs }
        return tabs.filter { ($0.title + ($0.database ?? "") + $0.sql.joined()).localizedCaseInsensitiveContains(query) }
    }

    private func row(_ tab: LabTOTab) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            Image(systemName: tab.symbol).foregroundStyle(ColorTokens.Text.secondary).frame(width: SpacingTokens.md)
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                HStack(spacing: SpacingTokens.xxs2) {
                    Text(tab.title).font(TypographyTokens.standard.weight(.medium))
                    if let database = tab.database { Text(database).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary) }
                }
                if !compact, let first = tab.sql.first {
                    Text(first).font(TypographyTokens.detail.monospaced()).foregroundStyle(ColorTokens.Text.secondary).lineLimit(1)
                }
            }
            Spacer()
            Circle().fill(tab.statusTint).frame(width: SpacingTokens.xxs2, height: SpacingTokens.xxs2)
            Text(tab.statusText).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
            Text(tab.ago).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary).frame(width: SpacingTokens.xxxl, alignment: .trailing)
        }
        .padding(.horizontal, SpacingTokens.xs)
        .frame(height: compact ? SpacingTokens.lg + SpacingTokens.xxs : SpacingTokens.xl2)
        .background(tab.id == LabTOTab.activeID ? ColorTokens.Sidebar.selectedFill : .clear, in: .rect(cornerRadius: SpacingTokens.xxs2))
    }
}

/// TO0: the overview as built (TabOverviewHeader, +ServerGroup, +DatabaseGroup, TabPreviewCard).
struct LabTOToday: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.md2) {
                HStack(spacing: SpacingTokens.sm) {
                    Text("Open Tabs").font(TypographyTokens.headline)
                    Text("9 tabs · 2 running").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    Spacer()
                    Button("Collapse All") {}.controlSize(.small)
                    Button("Expand All") {}.controlSize(.small)
                }
                ForEach(LabTOTab.servers, id: \.self) { server in
                    let serverTabs = LabTOTab.samples.filter { $0.server == server }
                    HStack(spacing: SpacingTokens.sm) {
                        Image(systemName: "chevron.down").font(TypographyTokens.caption2.weight(.bold)).foregroundStyle(ColorTokens.Text.secondary)
                        Label(server, systemImage: "cylinder.split.1x2").font(TypographyTokens.title2.weight(.bold))
                        Text("\(serverTabs.count) tabs").font(TypographyTokens.caption2.weight(.medium)).foregroundStyle(ColorTokens.Text.secondary)
                            .padding(.horizontal, SpacingTokens.xs).padding(.vertical, SpacingTokens.xxxs)
                            .background(ColorTokens.Text.primary.opacity(0.06), in: Capsule())
                    }
                    let databases = Array(Set(serverTabs.map { $0.database ?? server })).sorted()
                    ForEach(databases, id: \.self) { database in
                        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
                            HStack {
                                Image(systemName: "chevron.down").font(TypographyTokens.label.weight(.bold))
                                Label(database, systemImage: "cylinder").font(TypographyTokens.prominent.weight(.semibold))
                                    .foregroundStyle(database == "ESB_INTEGRATION" ? ColorTokens.accent : ColorTokens.Text.primary)
                                Spacer()
                            }
                            .padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xs)
                            .background(LinearGradient(colors: [ColorTokens.accent.opacity(0.1), ColorTokens.accent.opacity(0.03)], startPoint: .leading, endPoint: .trailing),
                                        in: .rect(cornerRadius: SpacingTokens.sm, style: .continuous))
                            let inDatabase = serverTabs.filter { ($0.database ?? server) == database }
                            Text("\(inDatabase.first?.kind.rawValue.uppercased() ?? "")  \(inDatabase.count)")
                                .font(TypographyTokens.detail.weight(.bold)).foregroundStyle(ColorTokens.Text.secondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(200), spacing: SpacingTokens.md), count: 3), alignment: .leading, spacing: SpacingTokens.md) {
                                ForEach(inDatabase) { LabTOCard(tab: $0, thumbnail: .today, isActive: $0.id == LabTOTab.activeID, showsDatabase: false, info: .today, closeOnHover: false) }
                            }
                        }
                        .padding(.leading, SpacingTokens.lg2)
                    }
                }
            }
            .padding(SpacingTokens.lg)
        }
    }
}
