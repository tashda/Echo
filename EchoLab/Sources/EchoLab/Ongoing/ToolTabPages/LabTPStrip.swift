import SwiftUI

/// How a tool's pages sit in its tab (round 36.1).
enum LabTPStyle: String, CaseIterable {
    case today = "TP0 · Chips on a grey track inside the tab (today)"
    case flat = "TP1 · Plain words in the tab; the page shown is bold with a dot under it"
    case segments = "TP2 · The tab becomes the pages: each page a segment, the shown one raised"
    case menu = "TP3 · Title › page, with the pages in a menu"
    case inTab = "TP4 · Not in the tab bar: the pages lead the tab's own header"
    case group = "TP5 · The tool becomes a group: a tinted label, then each page a tab of its own"
    case beside = "TP6 · A normal tab, its pages beside it on the strip as plain words"
    case hanging = "TP7 · A normal tab, its pages in a slim row hanging under it"

    /// The styles added in revision 2, after the owner found TP0 to TP4 unfinished.
    static let revision2: [LabTPStyle] = [.group, .beside, .hanging]

    var summary: String {
        switch self {
        case .today: "A capsule inside a capsule inside the strip: three nested shapes, which reads as a second control that doesn't belong."
        case .flat: "No inner shape at all; the pages read as the tab's own text, like a breadcrumb you can click."
        case .segments: "The tab's raised plate moves from page to page, so the strip has one shape language: the plate shows where you are."
        case .menu: "The narrowest: one title, the page after a chevron; switching takes two clicks."
        case .inTab: "The tab stays a normal tab; the pages are the first thing in the tool's header (round 37), like Activity Monitor's toolbar segments in macOS."
        case .group: "No plate holds the title any more: the tool's name is a tinted label, and every page is drawn exactly like a tab in the strip, so there is only one shape and nothing nested."
        case .beside: "The tab is a tab like any other; its pages follow it on the strip's track as words, the shown one in the accent colour, so no shape sits inside another."
        case .hanging: "The strip keeps its normal tabs; the active tool's pages sit in a 24pt row joined to the bottom of its tab, like a folder tab, so long page lists have room."
        }
    }
}

/// How the strip draws a single tab.
enum LabTPSingle: String, CaseIterable {
    case fill = "SW0 · It fills the strip (today)"
    case leading = "SW1 · Its own width, at the leading edge"
    case centred = "SW2 · Its own width, centred"
}

/// A tab in the strip.
struct LabTPTab: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    var pages: [String] = []
    var tint: Color = ColorTokens.Text.secondary

    static let activityMonitor = LabTPTab(id: "am", title: "Activity Monitor", symbol: "waveform.path.ecg",
                                          pages: ["Processes", "Waits", "I/O", "Queries", "XEvents", "Profiler"], tint: ColorTokens.Status.warning)
    static let policy = LabTPTab(id: "pm", title: "Policy Management", symbol: "checkmark.shield", pages: ["Policies", "Conditions", "Facets", "History"], tint: ColorTokens.Status.success)
    static let maintenance = LabTPTab(id: "mt", title: "Maintenance", symbol: "wrench.and.screwdriver", pages: ["Health", "Tables", "Indexes", "Backups", "Query Store"], tint: ColorTokens.Status.info)
    static let dbSecurity = LabTPTab(id: "ds", title: "Database Security", symbol: "lock.shield",
                                     pages: ["Users", "Roles", "App Roles", "Schemas", "Certificates", "Masking", "RLS", "Audit Specs", "Encryption"], tint: ColorTokens.Status.error)
    static let serverProperties = LabTPTab(id: "sp", title: "Server Properties", symbol: "server.rack",
                                           pages: ["Overview", "Control", "Variables", "Status", "Logs", "Configuration"], tint: ColorTokens.Status.info)
    static let query2 = LabTPTab(id: "q2", title: "Query 2", symbol: "tablecells")
    static let jobs = LabTPTab(id: "jobs", title: "Jobs", symbol: "clock")
    static let profiler = LabTPTab(id: "pr", title: "SQL Profiler", symbol: "chart.xyaxis.line")
}

/// The tab strip with one tool tab active, drawn in a page style.
struct LabTPStrip: View {
    let tabs: [LabTPTab]
    let activeID: String
    let style: LabTPStyle
    var single: LabTPSingle = .fill
    /// TP0 refined (revision 3); nil draws the style as it is.
    var refine: LabTPRefine? = nil
    @State var page: [String: String] = [:]
    @State var hangX: CGFloat = 0
    @Environment(\.echoMotion) var motion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            strip
            if style == .hanging, let tool = tabs.first(where: { $0.id == activeID }), !tool.pages.isEmpty {
                hangingRow(tool)
            }
        }
        .coordinateSpace(.named(Self.space))
    }

    static let space = "labTPStrip"

    private var strip: some View {
        HStack(spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.none) {
                ForEach(tabs) { tab in
                    if tabs.count == 1 && single != .fill {
                        tabView(tab).fixedSize()
                    } else {
                        tabView(tab).layoutPriority(tab.id == activeID ? 1 : 0)
                    }
                }
            }
            .padding(SpacingTokens.xxxs)
            .frame(maxWidth: .infinity, alignment: tabs.count == 1 && single == .centred ? .center : .leading)
            .background(ColorTokens.Sidebar.hoverFill, in: Capsule())
            Image(systemName: "plus").font(TypographyTokens.standard)
                .frame(width: SpacingTokens.lg2 - SpacingTokens.xxxs, height: SpacingTokens.lg2 - SpacingTokens.xxxs)
                .glassEffect(.regular, in: Circle())
        }
        .frame(height: SpacingTokens.lg2 + SpacingTokens.xxs)
    }

    func selected(_ tab: LabTPTab) -> String { page[tab.id] ?? tab.pages.first ?? "" }

    @ViewBuilder
    private func tabView(_ tab: LabTPTab) -> some View {
        let isActive = tab.id == activeID
        if isActive, !tab.pages.isEmpty, let refine {
            refinedTab(tab, refine)
        } else if isActive, !tab.pages.isEmpty, style == .group {
            groupView(tab)
        } else if isActive, !tab.pages.isEmpty, style == .beside {
            HStack(spacing: SpacingTokens.xs) { plainTab(tab).fixedSize(); besidePages(tab) }
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            plainOrNestedTab(tab, isActive: isActive)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minX } action: { x in
                    if isActive { hangX = x }
                }
        }
    }

    @ViewBuilder
    private func plainOrNestedTab(_ tab: LabTPTab, isActive: Bool) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            if isActive, !tab.pages.isEmpty, style == .segments {
                Image(systemName: tab.symbol).font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.secondary).padding(.leading, SpacingTokens.xs)
                ForEach(tab.pages, id: \.self) { name in segment(tab, name) }
            } else {
                Label(isActive && style == .menu && !tab.pages.isEmpty ? "\(tab.title) › \(selected(tab))" : tab.title, systemImage: tab.symbol)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(isActive ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    .lineLimit(1).fixedSize()
                if isActive, style == .menu, !tab.pages.isEmpty {
                    Image(systemName: "chevron.down").font(TypographyTokens.compact.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary)
                }
                if isActive, !tab.pages.isEmpty, style == .today { todayChips(tab) }
                if isActive, !tab.pages.isEmpty, style == .flat { flatPages(tab) }
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: SpacingTokens.lg + SpacingTokens.xxxs)
        .frame(maxWidth: .infinity)
        .background {
            if isActive, !(style == .segments && !tab.pages.isEmpty) {
                Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection)
            }
        }
    }

    private func todayChips(_ tab: LabTPTab) -> some View {
        HStack(spacing: LayoutTokens.TabPages.spacing) {
            ForEach(tab.pages, id: \.self) { name in
                let on = name == selected(tab)
                Text(name).font(TypographyTokens.label.weight(on ? .semibold : .regular))
                    .foregroundStyle(on ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    .padding(.horizontal, LayoutTokens.TabPages.chipHorizontalPadding)
                    .frame(height: LayoutTokens.TabPages.chipHeight - LayoutTokens.TabPages.spacing * 2)
                    .background { if on { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) } }
                    .onTapGesture { withAnimation(motion.press) { page[tab.id] = name } }
            }
        }
        .padding(.horizontal, LayoutTokens.TabPages.spacing)
        .frame(height: LayoutTokens.TabPages.chipHeight)
        .background(ColorTokens.Sidebar.selectedFill, in: Capsule())
    }

    private func flatPages(_ tab: LabTPTab) -> some View {
        HStack(spacing: SpacingTokens.sm) {
            Rectangle().fill(ColorTokens.Separator.primary).frame(width: 1, height: SpacingTokens.sm)
            ForEach(tab.pages, id: \.self) { name in
                let on = name == selected(tab)
                Text(name).font(TypographyTokens.detail.weight(on ? .semibold : .regular))
                    .foregroundStyle(on ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
                    .overlay(alignment: .bottom) {
                        if on { Circle().fill(ColorTokens.accent).frame(width: SpacingTokens.xxs, height: SpacingTokens.xxs).offset(y: SpacingTokens.xxs2) }
                    }
                    .fixedSize()
                    .onTapGesture { withAnimation(motion.press) { page[tab.id] = name } }
            }
        }
    }

    private func segment(_ tab: LabTPTab, _ name: String) -> some View {
        let on = name == selected(tab)
        return Text(name).font(TypographyTokens.detail.weight(on ? .semibold : .regular))
            .foregroundStyle(on ? ColorTokens.Text.primary : ColorTokens.Text.secondary)
            .fixedSize()
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: SpacingTokens.lg + SpacingTokens.xxxs)
            .background { if on { Capsule().fill(ColorTokens.Workspace.card).shadow(ShadowTokens.railSelection) } }
            .onTapGesture { withAnimation(motion.press) { page[tab.id] = name } }
    }
}

/// The tool's own header when the pages live in the tab (TP4, round 37's header).
struct LabTPInTabHeader: View {
    let tab: LabTPTab
    @State private var page = ""
    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Picker("Page", selection: Binding(get: { page.isEmpty ? (tab.pages.first ?? "") : page }, set: { page = $0 })) {
                ForEach(tab.pages, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            Spacer()
            Text("Updated 5 sec ago").font(TypographyTokens.detail).foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(SpacingTokens.sm)
    }
}
