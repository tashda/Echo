import SwiftUI

/// One button in a server's section dock.
struct ExplorerDockItem: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let count: Int?
}

/// TC1 (design board, round 14): under each server's name, a dock of its top-level sections
/// (Databases, Security, Agent Jobs, Management…) switches what the card shows. The first four
/// get their own button; the rest share More. Built from the tree the blueprints made, so it
/// knows nothing about database types.
@MainActor
enum ExplorerDock {
    static let buttonLimit = 4

    static func dockNodeID(_ connectionID: UUID) -> String { "dock|\(connectionID.uuidString)" }
    static func moreItemID(_ connectionID: UUID) -> String { "dock-more|\(connectionID.uuidString)" }

    /// The servers' children replaced by their dock and the chosen section's contents. Servers
    /// with fewer than two sections, or sections the dock can't describe, keep their tree.
    static func apply(to roots: [ObjectBrowserNode], selections: [UUID: String]) -> [ObjectBrowserNode] {
        roots.map { root in
            guard case .server(let session) = root.row else { return root }
            let connectionID = session.connection.id
            guard let items = items(for: root.children, connectionID: connectionID) else { return root }
            let selected = selectedID(in: items, saved: selections[connectionID])
            let dock = ObjectBrowserNode(id: dockNodeID(connectionID), row: .dock(session, items, selectedID: selected))
            return ObjectBrowserNode(id: root.id, row: root.row, children: [dock] + content(of: root, selected: selected, connectionID: connectionID))
        }
    }

    static func selectedID(in items: [ExplorerDockItem], saved: String?) -> String {
        if let saved, items.contains(where: { $0.id == saved }) { return saved }
        return items.first?.id ?? ""
    }

    static func items(for sections: [ObjectBrowserNode], connectionID: UUID) -> [ExplorerDockItem]? {
        let described = sections.compactMap(describe)
        guard described.count == sections.count, described.count >= 2 else { return nil }
        guard described.count > buttonLimit + 1 else { return described }
        let more = ExplorerDockItem(id: moreItemID(connectionID), title: "More", symbol: "ellipsis.circle",
                                    color: ColorTokens.Text.secondary, count: nil)
        return Array(described.prefix(buttonLimit)) + [more]
    }

    /// What the card shows below the dock: a folder's contents, a single tool, or, for More,
    /// the remaining sections as folders.
    static func content(of server: ObjectBrowserNode, selected: String, connectionID: UUID) -> [ObjectBrowserNode] {
        if selected == moreItemID(connectionID) { return Array(server.children.dropFirst(buttonLimit)) }
        guard let section = server.children.first(where: { $0.id == selected }) else { return [] }
        return section.children.isEmpty ? [section] : section.children
    }

    /// The section node a dock item stands for, if it is one (More is not).
    static func section(for itemID: String, in roots: [ObjectBrowserNode]) -> ObjectBrowserNode? {
        for root in roots {
            if let match = root.children.first(where: { $0.id == itemID }) { return match }
        }
        return nil
    }

    private static func describe(_ node: ObjectBrowserNode) -> ExplorerDockItem? {
        switch node.row {
        case .folder(let folder), .section(let folder):
            ExplorerDockItem(id: node.id, title: folder.kind.title, symbol: folder.kind.symbol, color: folder.kind.role.color, count: folder.count)
        case .action(_, let kind):
            ExplorerDockItem(id: node.id, title: kind.title, symbol: kind.symbol, color: kind.role.color, count: nil)
        case .database(_, let database, _):
            ExplorerDockItem(id: node.id, title: database.name, symbol: "cylinder", color: ExplorerIconRole.database.color, count: nil)
        default:
            nil
        }
    }
}

struct SelectExplorerDockSectionKey: EnvironmentKey {
    static let defaultValue: @MainActor (UUID, String) -> Void = { _, _ in }
}

extension EnvironmentValues {
    /// Chooses a dock section: the server's connection and the item's ID.
    var selectExplorerDockSection: @MainActor (UUID, String) -> Void {
        get { self[SelectExplorerDockSectionKey.self] }
        set { self[SelectExplorerDockSectionKey.self] = newValue }
    }
}

extension LayoutTokens {
    /// The section dock under a server's name (Design/05-components › Explorer tree).
    enum ExplorerDock {
        static let extraHeight: CGFloat = SpacingTokens.xs
        static let buttonHeight: CGFloat = 30
        static let buttonCornerRadius: CGFloat = SpacingTokens.xs
        /// How far the pinned blur fades out below the dock, so it has no hard edge.
        static let blurFadeHeight: CGFloat = SpacingTokens.sm
    }
}
