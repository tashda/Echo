import SwiftUI

/// Which sections a server's capsule shows and which are left out.
enum LabSDDockArrangement {
    static func arrange(_ server: LabSDServer, options: LabSDOptions) -> (shown: [LabSDSection], overflow: [LabSDSection]) {
        let sections = server.sections
        switch options.overflow {
        case .scroll, .shrink, .secondRow:
            return (sections, [])
        case .menu, .menuWithActions, .moreSection:
            // Echo today: SQL Server's blueprint docks four; the others dock everything.
            let limit = options.usesBlueprintDock ? (server.id == "ms" ? 4 : sections.count) : (options.limit.count ?? sections.count)
            guard sections.count > limit else { return (sections, []) }
            return (Array(sections.prefix(limit)), Array(sections.dropFirst(limit)))
        }
    }
}

/// The tree's rows, worked out from the servers alone: every row has a fixed height for its kind,
/// so each card's place is known without measuring (Echo's `ExplorerTreeLayout`).
struct LabSDLayout {
    enum Kind {
        case gap
        case server(LabSDServer)
        case dock(LabSDServer)
        case heading(String)
        case node(LabSDNode, isLoading: Bool)
        case spinner(String)
    }

    struct Row: Identifiable {
        let id: String
        let kind: Kind
        let depth: Int
        let minY: CGFloat
        let height: CGFloat
        let serverID: String?
    }

    struct Group: Identifiable {
        let id: String
        let serverID: String?
        let sectionID: String
        let header: [Row]
        let rows: [Row]
        var headerHeight: CGFloat { header.reduce(0) { $0 + $1.height } }
        var bodyHeight: CGFloat { rows.reduce(0) { $0 + $1.height } }
    }

    struct Card: Identifiable {
        let id: String
        let minY: CGFloat
        let height: CGFloat
    }

    private(set) var groups: [Group] = []
    private(set) var cards: [Card] = []
    private(set) var contentHeight: CGFloat = 0

    var rows: [Row] { groups.flatMap { $0.header + $0.rows } }

    @MainActor
    init(servers: [LabSDServer], state: LabSDTreeState, options: LabSDOptions) {
        let slot = options.density.rowSlot
        var y: CGFloat = 0
        func row(_ id: String, _ kind: Kind, depth: Int = 0, height: CGFloat? = nil, server: String?) -> Row {
            defer { y += height ?? slot }
            return Row(id: id, kind: kind, depth: depth, minY: y, height: height ?? slot, serverID: server)
        }

        for (index, server) in servers.enumerated() {
            if index > 0 {
                let gap = row("gap.\(server.id)", .gap, height: SpacingTokens.xs, server: nil)
                groups.append(Group(id: gap.id, serverID: nil, sectionID: "", header: [], rows: [gap]))
            }
            let cardTop = y
            let isCollapsed = state.collapsed.contains(server.id)
            let hasDock = server.sections.count >= 2
            var header = [row("server.\(server.id)", .server(server), height: slot + SpacingTokens.xs + SpacingTokens.sm, server: server.id)]
            if hasDock && !isCollapsed {
                header.append(row("dock.\(server.id)", .dock(server), height: LabSDCapsuleMetrics.rowHeight(server, options: options), server: server.id))
            }
            let sectionID = state.chosenSection(server)
            var body: [Row] = []
            if !isCollapsed {
                let shown = sectionID == LabSDTreeState.moreID ? nil : server.section(sectionID)
                if options.sectionName == .aboveRows, hasDock {
                    body.append(row("heading.\(server.id).\(sectionID)", .heading(shown?.title ?? "More"), server: server.id))
                }
                for (node, depth, loading, title) in Self.flatten(server, sectionID: sectionID, state: state, options: options) {
                    switch node {
                    case .some(let node): body.append(row(node.id, .node(node, isLoading: loading), depth: depth, server: server.id))
                    case .none: body.append(row("spinner.\(server.id).\(sectionID).\(title)", .spinner("Loading \(title)"), depth: depth, server: server.id))
                    }
                }
            }
            y += LayoutTokens.Workspace.treeCardBottomPadding
            groups.append(Group(id: "group.\(server.id)", serverID: server.id, sectionID: sectionID, header: header, rows: body))
            cards.append(Card(id: server.id, minY: cardTop, height: y - cardTop))
        }
        contentHeight = y
    }

    /// The chosen section's rows: nodes with their depth, or nil for a spinner row. While the
    /// section loads for the first time, folders and tools show at once (folders first) and the
    /// items wait behind one spinner row.
    @MainActor
    private static func flatten(_ server: LabSDServer, sectionID: String, state: LabSDTreeState, options: LabSDOptions) -> [(LabSDNode?, Int, Bool, String)] {
        let nodes: [LabSDNode]
        if sectionID == LabSDTreeState.moreID {
            nodes = LabSDDockArrangement.arrange(server, options: options).overflow.map {
                LabSDNodes.folder("more.\(server.id).\($0.id)", $0.title, symbol: $0.symbol, color: $0.color, $0.nodes)
            }
        } else {
            nodes = server.section(sectionID)?.nodes ?? []
        }
        let sectionLoading = state.isLoading(server, sectionID)
        var rows: [(LabSDNode?, Int, Bool, String)] = []
        func walk(_ nodes: [LabSDNode], depth: Int, title: String) {
            var waiting = false
            for node in nodes {
                if sectionLoading && node.isItem { waiting = true; continue }
                rows.append((node, depth, sectionLoading && node.isFolder, ""))
                guard node.isFolder, state.expanded.contains(node.id) else { continue }
                if sectionLoading { rows.append((nil, depth + 1, true, node.title)) } else { walk(node.children, depth: depth + 1, title: node.title) }
            }
            if waiting { rows.append((nil, depth, true, title)) }
        }
        walk(nodes, depth: 0, title: server.section(sectionID)?.title ?? "More")
        return rows
    }

    func serverTop(_ serverID: String) -> CGFloat {
        cards.first { $0.id == serverID }?.minY ?? 0
    }
}
