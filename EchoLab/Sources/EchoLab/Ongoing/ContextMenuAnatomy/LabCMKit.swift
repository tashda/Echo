import SwiftUI

/// One context menu item. A menu is a list of groups (separators between them).
struct LabCMItem: Hashable {
    enum Role: Hashable { case open, create, copy, script, tasks, refresh, connection, info, danger, toggle }
    let title: String
    var symbol: String?
    var role: Role = .open
    var children: [[LabCMItem]] = []

    static func sub(_ title: String, _ symbol: String?, role: Role = .tasks, _ children: [[LabCMItem]]) -> LabCMItem {
        LabCMItem(title: title, symbol: symbol, role: role, children: children)
    }

    /// Symbols the system uses for the same action everywhere (HIG › Standard icons).
    var isFamiliar: Bool { [.copy, .refresh, .info, .danger].contains(role) || title.hasPrefix("New ") }
}

/// The rules every menu follows (round 42.1).
struct LabCMRules {
    enum Icons: String, CaseIterable {
        case none = "MI0 · No icons (as your screenshot shows)"
        case familiar = "MI1 · Icons only for familiar actions: New, Copy, Refresh, Properties, Drop"
        case all = "MI2 · An icon on every item"
    }

    enum Properties: String, CaseIterable {
        case lastAfterDrop = "PL0 · Drop, then Properties last (today)"
        case dropLast = "PL1 · Properties, then Drop last"
        case early = "PL2 · Properties in the first group, after Open"

        var summary: String {
            switch self {
            case .lastAfterDrop: "Properties at the menu's bottom edge, the easiest place to hit; Drop sits above it in its own group, away from the edge."
            case .dropLast: "Apple's rule for destructive items on iPhone and iPad; on a Mac it puts Drop on the edge where the pointer lands."
            case .early: "Like Finder's Get Info: you reach it without passing the commands."
            }
        }
    }

    var icons: Icons = .familiar
    var properties: Properties = .lastAfterDrop
    var title = true
    var copyName = true
    var redDrop = false

    static let today = LabCMRules(icons: .none, properties: .lastAfterDrop, title: false, copyName: false, redDrop: false)

    @MainActor static func from(_ v: RoundValues) -> LabCMRules {
        LabCMRules(icons: Icons(rawValue: v["icons"]) ?? .familiar, properties: Properties(rawValue: v["properties"]) ?? .lastAfterDrop,
                   title: (v["title"].isEmpty ? LabCMTitle.name : LabCMTitle(rawValue: v["title"]) ?? .name) == .name,
                   copyName: (v["copyName"].isEmpty ? LabCMCopyName.yes : LabCMCopyName(rawValue: v["copyName"]) ?? .yes) == .yes,
                   redDrop: (LabCMDrop(rawValue: v["drop"]) ?? .plain) == .red)
    }

    /// Puts a proposal's commands in the agreed order: open and create, then copy, script and tasks,
    /// then refresh and connection, then Properties and Drop as the rule says.
    func arrange(_ items: [LabCMItem]) -> [[LabCMItem]] {
        var list = items
        if !copyName { list.removeAll { $0.title == "Copy Name" } }
        let first = list.filter { [.open, .create].contains($0.role) }
        let middle = list.filter { [.copy, .script, .tasks].contains($0.role) }
        let third = list.filter { [.refresh, .connection, .toggle].contains($0.role) }
        let info = list.filter { $0.role == .info }
        let danger = list.filter { $0.role == .danger }
        switch properties {
        case .lastAfterDrop: return [first, middle, third, danger, info].filter { !$0.isEmpty }
        case .dropLast: return [first, middle, third, info, danger].filter { !$0.isEmpty }
        case .early: return [first + info, middle, third, danger].filter { !$0.isEmpty }
        }
    }
}

enum LabCMTitle: String, CaseIterable { case none = "MT0 · No title (today)", name = "MT1 · The object's name in grey at the top" }
enum LabCMCopyName: String, CaseIterable { case no = "CN0 · No (today)", yes = "CN1 · Copy Name in every object's menu" }
enum LabCMDrop: String, CaseIterable { case plain = "DR0 · In ordinary text, in its own group (today)", red = "DR1 · In red" }

/// A context menu drawn as macOS 26 draws one: a glass panel, 13pt items, separators, a chevron
/// for submenus, and an icon column when any item has an icon. The first submenu can be shown open.
struct LabCMMenuView: View {
    let groups: [[LabCMItem]]
    let rules: LabCMRules
    var title: String?
    var openSubmenu: String?

    private var showsIcons: Bool { rules.icons != .none }

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xxs) {
            panel(groups, title: rules.title ? title : nil)
            if let openSubmenu, let item = groups.joined().first(where: { $0.title == openSubmenu }) {
                panel(item.children, title: nil).padding(.top, SpacingTokens.lg2)
            }
        }
    }

    private func panel(_ groups: [[LabCMItem]], title: String?) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.none) {
            if let title {
                Text(title).font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.tertiary).lineLimit(1)
                    .padding(.horizontal, SpacingTokens.sm).padding(.top, SpacingTokens.xxs2).padding(.bottom, SpacingTokens.xxs)
            }
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 { Divider().padding(.horizontal, SpacingTokens.sm).padding(.vertical, SpacingTokens.xxs) }
                ForEach(group, id: \.self) { item in row(item, iconColumn: showsIcons && groups.joined().contains { icon(for: $0) != nil }) }
            }
        }
        .padding(.vertical, SpacingTokens.xxs2)
        .frame(width: 230, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.sm, style: .continuous))
    }

    private func icon(for item: LabCMItem) -> String? {
        switch rules.icons {
        case .none: nil
        case .familiar: item.isFamiliar ? item.symbol : nil
        case .all: item.symbol
        }
    }

    private func row(_ item: LabCMItem, iconColumn: Bool) -> some View {
        HStack(spacing: SpacingTokens.xs) {
            if iconColumn {
                Group { if let symbol = icon(for: item) { Image(systemName: symbol) } else { Color.clear } }
                    .frame(width: SpacingTokens.md)
            }
            Text(item.title).lineLimit(1)
            Spacer(minLength: SpacingTokens.sm)
            if !item.children.isEmpty { Image(systemName: "chevron.right").font(TypographyTokens.detail.weight(.semibold)).foregroundStyle(ColorTokens.Text.secondary) }
        }
        .font(TypographyTokens.standard)
        .foregroundStyle(item.role == .danger && rules.redDrop ? ColorTokens.Status.error : ColorTokens.Text.primary)
        .padding(.horizontal, SpacingTokens.sm)
        .frame(height: SpacingTokens.lg - SpacingTokens.xxxs)
        .background { if item.title == openSubmenu { RoundedRectangle(cornerRadius: SpacingTokens.xxs2).fill(ColorTokens.accent).padding(.horizontal, SpacingTokens.xxs) } }
    }
}

/// The right-clicked row in the tree with its menu beside it.
struct LabCMScene: View {
    let row: (symbol: String, tint: Color, title: String)
    let groups: [[LabCMItem]]
    let rules: LabCMRules
    var title: String?
    var openSubmenu: String?

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.xs) {
            VStack(alignment: .leading, spacing: SpacingTokens.none) {
                LabSHRow(title: "ccsLDK10")
                LabSHRow(title: row.title, symbol: row.symbol, tint: row.tint, indent: SidebarRowConstants.indentStep)
                    .background(RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius).strokeBorder(ColorTokens.accent, lineWidth: 2)
                        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding))
                LabSHRow(title: "dbo.048_tmp", symbol: "tablecells", tint: Color(nsColor: .systemTeal), indent: SidebarRowConstants.indentStep)
                Spacer()
            }
            .padding(.vertical, SpacingTokens.xs)
            .frame(width: 220).frame(maxHeight: .infinity).workspaceCard()
            LabCMMenuView(groups: groups, rules: rules, title: title, openSubmenu: openSubmenu).padding(.top, SpacingTokens.lg2)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ColorTokens.Workspace.canvas)
    }
}

/// Exhibits shared by the object pages: Echo today's menu and the proposal's, beside the row.
@MainActor
enum LabCMExhibits {
    static func pair(_ id: String, row: (symbol: String, tint: Color, title: String), today: [[LabCMItem]]?, todayNote: String = "As built.",
                     openSubmenu: String? = nil, proposal: @escaping (RoundValues) -> [LabCMItem]) -> [RoundSpec.Exhibit] {
        [
            .init(id: "\(id)Today", title: "Echo today: \(row.title)", summary: todayNote, isEchoToday: true, isWide: true, designWidth: 640, designHeight: 470) { _ in
                if let today {
                    LabCMScene(row: row, groups: today, rules: .today, openSubmenu: openSubmenu)
                } else {
                    LabCMScene(row: row, groups: [], rules: .today).overlay {
                        Text("No menu: right-clicking does nothing").font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.secondary)
                    }
                }
            },
            .init(id: "\(id)Proposal", title: "Proposal: \(row.title)", summary: "The commands below, arranged by 42.1's recommended rules.", isWide: true,
                  designWidth: 640, designHeight: 470) { values in
                LabCMScene(row: row, groups: LabCMRules().arrange(proposal(values)), rules: LabCMRules(), title: row.title, openSubmenu: openSubmenu)
            },
        ]
    }
}
