import SwiftUI

/// A window as round 37.5 draws it: the toolbar, the tab strip (36.1 as built), the tool's header
/// line with whatever stays on it, and the content card.
struct LabTBWindow: View {
    let tabs: [LabTBTab]
    let active: LabTBTab
    let look: LabTBLook
    /// Echo today: the tool's controls all on its header line, nothing in the toolbar.
    var isToday = false

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            LabTBToolbar(tab: isToday && !active.isQuery ? .noButtons : active, look: isToday ? .today : look)
            LabTPStrip(tabs: tabs.map(\.stripTab), activeID: active.id, style: .today, refine: .accepted)
                .padding(.horizontal, SpacingTokens.sm)
            if !active.isQuery { header.padding(.horizontal, SpacingTokens.sm) }
            content
                .padding(.horizontal, SpacingTokens.sm)
                .padding(.bottom, SpacingTokens.sm)
        }
        .padding(.top, SpacingTokens.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    /// The tool's header line: tile, name and subtitle, then what stays on it.
    private var header: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: active.symbol).font(TypographyTokens.prominent.weight(.semibold)).foregroundStyle(active.tint)
                .frame(width: LayoutTokens.Toolbar.glyph, height: LayoutTokens.Toolbar.glyph)
                .background(active.tint.opacity(0.12), in: .rect(cornerRadius: SpacingTokens.xxs3, style: .continuous))
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                Text(active.title).font(TypographyTokens.standard.weight(.semibold))
                Text(active.subtitle).font(TypographyTokens.detail.monospacedDigit()).foregroundStyle(ColorTokens.Text.secondary)
            }
            Spacer()
            HStack(spacing: SpacingTokens.xs) {
                if isToday || look.move != .everything {
                    if let picker = active.picker { pill { Text(picker); Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold)) } }
                    if let search = active.search { pill { Image(systemName: "magnifyingglass"); Text(search).foregroundStyle(ColorTokens.Text.tertiary) } }
                }
                if isToday || look.move == .main {
                    ForEach(Array(active.groups.enumerated()), id: \.offset) { _, group in
                        pill { ForEach(group, id: \.self) { Image(systemName: $0.symbol) } }
                    }
                }
                if isToday, let main = active.main {
                    pill { Image(systemName: main.symbol).foregroundStyle(ColorTokens.accent); Text(main.title).foregroundStyle(ColorTokens.Text.secondary) }
                }
            }
        }
        .frame(height: SpacingTokens.xl2)
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: SpacingTokens.xs) { content() }
            .font(TypographyTokens.standard)
            .padding(.horizontal, SpacingTokens.sm)
            .frame(height: LayoutTokens.Toolbar.glyph)
            .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            if active.isQuery {
                Text("select * from orders").font(TypographyTokens.code)
                Text("where placed > '2026-09-01';").font(TypographyTokens.code)
            } else {
                ForEach(0..<4, id: \.self) { row in
                    HStack {
                        Text(["Nightly backup", "Index maintenance", "Stats refresh", "Log cleanup"][row])
                        Spacer()
                        Text(["Succeeded", "Running", "Succeeded", "Failed"][row]).foregroundStyle(ColorTokens.Text.secondary)
                    }
                    .font(TypographyTokens.detail)
                }
            }
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .workspaceCard()
    }
}

extension LabTBTab {
    /// The tab as the strip draws it, with its pages.
    var stripTab: LabTPTab { LabTPTab(id: id, title: title, symbol: symbol, pages: pages, tint: tint) }
}

/// Click the tabs and watch the toolbar's section follow (SW0 to SW3).
struct LabTBSwitching: View {
    let look: LabTBLook
    private let tabs: [LabTBTab] = [.query, .profiler, .policy, .activity, .noButtons]
    @State private var activeID = LabTBTab.query.id
    @Environment(\.echoMotion) private var motion

    private var active: LabTBTab { tabs.first { $0.id == activeID } ?? .query }

    var body: some View {
        VStack(spacing: SpacingTokens.xs) {
            LabTBToolbar(tab: active, look: look)
            HStack(spacing: SpacingTokens.xs) {
                ForEach(tabs) { tab in
                    Button { select(tab) } label: {
                        Label(tab.title, systemImage: tab.symbol)
                            .font(TypographyTokens.detail)
                            .padding(.horizontal, SpacingTokens.sm)
                            .frame(height: SpacingTokens.lg)
                            .background { if tab.id == activeID { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) } }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(SpacingTokens.xxxs)
            .background(ColorTokens.TabStrip.Background.plate, in: Capsule())
            .padding(.horizontal, SpacingTokens.sm)
            Text("Click a tab: the toolbar's section changes with it. Availability Groups has no buttons of its own.")
                .font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary)
                .padding(.horizontal, SpacingTokens.sm)
            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.top, SpacingTokens.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    private func select(_ tab: LabTBTab) {
        switch look.motion {
        case .melt: withAnimation(motion.press) { activeID = tab.id }
        case .fade: withAnimation(motion.settle) { activeID = tab.id }
        case .morph, .slide: withAnimation(motion.standard) { activeID = tab.id }
        }
    }
}

/// Every tie, or every way to arrange the groups, on the query tab's toolbar, one per row.
struct LabTBGallery: View {
    enum Kind { case ties, groups, runs }
    let kind: Kind
    let look: LabTBLook

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(rows, id: \.0) { row in
                Text(row.0).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                    .padding(.horizontal, SpacingTokens.sm)
                LabTBToolbar(tab: .query, look: row.1)
            }
        }
        .padding(.vertical, SpacingTokens.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ColorTokens.Workspace.canvas)
    }

    private var rows: [(String, LabTBLook)] {
        switch kind {
        case .ties: LabTBTie.allCases.map { tie in var l = look; l.tie = tie; return (tie.rawValue, l) }
        case .groups: LabTBGroups.allCases.map { groups in var l = look; l.groups = groups; return (groups.rawValue, l) }
        case .runs: LabTBRun.allCases.flatMap { run in [false, true].map { running in
            var l = look; l.run = run; l.running = running
            return (run.rawValue + (running ? ", running" : ""), l)
        } }
        }
    }
}
