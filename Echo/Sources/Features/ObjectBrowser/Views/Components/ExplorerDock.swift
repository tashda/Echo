import SwiftUI

/// One section a server's dock can show.
struct ExplorerDockItem: Identifiable, Equatable {
    /// The section node's ID.
    let id: String
    /// The section's kind, the same for every server of a type; what dock choices are saved as.
    let key: String
    let title: String
    let symbol: String
    let color: Color
    let count: Int?
}

/// The dock's sections: the ones in the capsule, in order, and the rest, which sit under More.
struct ExplorerDockLayout: Equatable {
    let shown: [ExplorerDockItem]
    let overflow: [ExplorerDockItem]

    var all: [ExplorerDockItem] { shown + overflow }
}

/// TC1 and round 16: under each server's name, a dock of its top-level sections (Databases,
/// Security, Agent Jobs, Management…) switches what the card shows. Which sections the capsule
/// shows comes from the server's own choice, then its type's (Settings), then the blueprint;
/// the rest are listed under More. Built from the tree the blueprints made, so it knows nothing
/// about database types.
@MainActor
enum ExplorerDock {
    static func dockNodeID(_ connectionID: UUID) -> String { "dock|\(connectionID.uuidString)" }
    /// More (»), the section that lists whatever the capsule leaves out (round 19, M2).
    static func moreItemID(_ connectionID: UUID) -> String { "dock-more|\(connectionID.uuidString)" }
    /// The capsule shows at most this many sections (round 19).
    static let capsuleLimit = 5

    /// The servers' children replaced by their dock and the chosen section's contents. Servers
    /// with fewer than two sections, or sections the dock can't describe, keep their tree.
    /// `savedKeys` gives a server's saved dock (its own, or its type's), nil for the default.
    static func apply(
        to roots: [ObjectBrowserNode],
        selections: [UUID: String],
        savedKeys: (ConnectionSession) -> [String]? = { _ in nil }
    ) -> [ObjectBrowserNode] {
        roots.map { root in
            guard case .server(let session) = root.row else { return root }
            let connectionID = session.connection.id
            guard let layout = layout(for: root.children, session: session, saved: savedKeys(session)) else { return root }
            let selected = selectedID(in: layout, connectionID: connectionID, saved: selections[connectionID])
            let dock = ObjectBrowserNode(id: dockNodeID(connectionID), row: .dock(session, layout, selectedID: selected))
            return ObjectBrowserNode(id: root.id, row: root.row, children: [dock] + content(of: root, layout: layout, selected: selected))
        }
    }

    /// The saved section if it still exists (More only while something is left out), else the first.
    static func selectedID(in layout: ExplorerDockLayout, connectionID: UUID, saved: String?) -> String {
        if let saved, layout.all.contains(where: { $0.id == saved }) { return saved }
        if saved == moreItemID(connectionID), !layout.overflow.isEmpty { return moreItemID(connectionID) }
        return layout.shown.first?.id ?? ""
    }

    /// The dock for a server's sections, or nil when it keeps its tree.
    static func layout(for sections: [ObjectBrowserNode], session: ConnectionSession, saved: [String]?) -> ExplorerDockLayout? {
        let described = sections.compactMap(describe)
        guard described.count == sections.count, described.count >= 2 else { return nil }
        let blueprintDefault = ExplorerBlueprint.blueprint(for: session.connection.databaseType).dock?.map(\.rawValue)
        let arranged = arrange(keys: described.map(\.key), saved: saved, preferred: blueprintDefault, limit: capsuleLimit)
        let byKey = Dictionary(described.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        return ExplorerDockLayout(shown: arranged.shown.compactMap { byKey[$0] }, overflow: arranged.overflow.compactMap { byKey[$0] })
    }

    /// Which section keys the capsule shows, in order, and which go under More. The saved order
    /// wins, then the blueprint's; keys neither mentions go under More. The capsule is never
    /// empty and holds at most `limit` sections.
    nonisolated static func arrange(keys: [String], saved: [String]?, preferred: [String]?, limit: Int = 5) -> (shown: [String], overflow: [String]) {
        let wanted = (saved ?? preferred)?.filter(keys.contains) ?? keys
        let shown = Array((wanted.isEmpty ? keys : wanted).prefix(limit))
        return (shown, keys.filter { !shown.contains($0) })
    }

    /// What the card shows below the dock: a section's contents, the section itself when it is a
    /// single tool, or for More the left-out sections as ordinary folders.
    static func content(of server: ObjectBrowserNode, layout: ExplorerDockLayout, selected: String) -> [ObjectBrowserNode] {
        if case .server(let session) = server.row, selected == moreItemID(session.connection.id) {
            let left = Set(layout.overflow.map(\.id))
            return server.children.filter { left.contains($0.id) }
        }
        guard let section = server.children.first(where: { $0.id == selected }) else { return [] }
        return section.children.isEmpty ? [section] : section.children
    }

    /// Each docked server's current section name, for its header ("SQL Server 2022 · Security").
    static func currentTitles(in roots: [ObjectBrowserNode]) -> [UUID: String] {
        var titles: [UUID: String] = [:]
        for root in roots {
            guard case .dock(let session, let layout, let selectedID) = root.children.first?.row else { continue }
            let connectionID = session.connection.id
            titles[connectionID] = selectedID == moreItemID(connectionID) ? "More" : layout.all.first { $0.id == selectedID }?.title
        }
        return titles
    }

    /// The section node a dock item stands for.
    static func section(for itemID: String, in roots: [ObjectBrowserNode]) -> ObjectBrowserNode? {
        for root in roots {
            if let match = root.children.first(where: { $0.id == itemID }) { return match }
        }
        return nil
    }

    private static func describe(_ node: ObjectBrowserNode) -> ExplorerDockItem? {
        switch node.row {
        case .folder(let folder), .section(let folder):
            ExplorerDockItem(id: node.id, key: folder.kind.rawValue, title: folder.kind.title, symbol: folder.kind.symbol,
                             color: folder.kind.role.color, count: folder.count)
        case .action(_, let kind, _):
            ExplorerDockItem(id: node.id, key: kind.rawValue, title: kind.title, symbol: kind.symbol, color: kind.role.color, count: nil)
        case .database(_, let database, _):
            ExplorerDockItem(id: node.id, key: "database:\(database.name)", title: database.name, symbol: "cylinder",
                             color: ExplorerIconRole.database.color, count: nil)
        default:
            nil
        }
    }
}

/// What the dock's buttons and menus call back into the Explorer with.
struct ExplorerDockActions {
    /// Chooses a section: the server's connection and the item's ID.
    var select: @MainActor (UUID, String) -> Void = { _, _ in }
    /// The right-click menu for one section's icon, or for the capsule when the item is nil.
    var menu: @MainActor (UUID, String?) -> NSMenu = { _, _ in NSMenu() }
}

extension EnvironmentValues {
    @Entry var explorerDockActions = ExplorerDockActions()
    /// Each docked server's current section name, shown after its product in the header.
    @Entry var explorerDockSectionTitles: [UUID: String] = [:]
}

extension LayoutTokens {
    /// The section dock under a server's name (Design/05-components › Explorer tree).
    enum ExplorerDock {
        /// The dock row's slot over an ordinary row: room for the capsule's edge and shadow.
        static let extraHeight: CGFloat = SpacingTokens.xs
        /// C5 (round 19): the capsule's hairline edge, as a share of the card edge's colour.
        static let edgeOpacity: Double = 0.8
        /// C5: the capsule's soft shadow.
        static let shadowOpacity: Double = 0.08
        /// A hovered icon grows by this much (round 19).
        static let hoverScale: CGFloat = 1.12

        /// The capsule's height, following the sidebar size.
        static func capsuleHeight(for density: SidebarDensity) -> CGFloat {
            switch density {
            case .compact: SpacingTokens.md2 + SpacingTokens.xxxs
            case .small: SpacingTokens.lg
            case .medium: SpacingTokens.lg + SpacingTokens.xxs
            case .large: SpacingTokens.xl
            }
        }
    }
}
