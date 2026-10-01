import SwiftUI

/// One row of sample tree content.
struct LabSDNode: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    var prefix: String? = nil
    let symbol: String
    let color: Color
    var children: [LabSDNode] = []
    /// Something the server lists (a database, a login), as opposed to a folder or tool.
    var isItem = false

    var isFolder: Bool { !children.isEmpty }
}

struct LabSDMenuItem: Identifiable, Hashable, Sendable {
    let title: String
    let symbol: String
    var isDivider = false
    var id: String { title }
    static let divider = LabSDMenuItem(title: "—", symbol: "", isDivider: true)
    static let refresh = LabSDMenuItem(title: "Refresh", symbol: "arrow.clockwise")
}

/// One dock section: its icon, its rows and its own right-click menu.
struct LabSDSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let nodes: [LabSDNode]
    var menu: [LabSDMenuItem] = [.refresh]
    /// Loads its items the first time it opens, like Security in Echo.
    var loadsOnOpen = false
}

struct LabSDServer: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// The product and release under the name ("SQL Server 2022").
    let product: String
    let build: String
    let sections: [LabSDSection]

    func section(_ id: String) -> LabSDSection? { sections.first { $0.id == id } }
}

/// Node builders for the samples.
enum LabSDNodes {
    static func items(_ parent: String, _ names: [String], symbol: String, color: Color) -> [LabSDNode] {
        names.map { name in
            let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
            return LabSDNode(id: "\(parent).\(name)", title: parts.last ?? name, prefix: parts.count == 2 ? parts[0] : nil,
                             symbol: symbol, color: color, isItem: true)
        }
    }

    static func folder(_ id: String, _ title: String, symbol: String, color: Color, _ children: [LabSDNode]) -> LabSDNode {
        LabSDNode(id: id, title: title, symbol: symbol, color: color, children: children)
    }

    static func tool(_ id: String, _ title: String, symbol: String, color: Color = ColorTokens.Text.secondary) -> LabSDNode {
        LabSDNode(id: id, title: title, symbol: symbol, color: color)
    }

    /// A database with a Tables folder, and Views when given.
    static func database(_ server: String, _ name: String, tables: [String], views: [String] = []) -> LabSDNode {
        let id = "\(server).db.\(name)"
        let explorer = ColorTokens.Explorer.self
        var folders = [folder("\(id).tables", "Tables", symbol: "tablecells", color: explorer.tables,
                              items("\(id).tables", tables, symbol: "tablecells", color: explorer.tables))]
        if !views.isEmpty {
            folders.append(folder("\(id).views", "Views", symbol: "eye", color: explorer.views, items("\(id).views", views, symbol: "eye", color: explorer.views)))
        }
        var database = folder(id, name, symbol: "cylinder", color: explorer.databaseInstance, folders)
        database.isItem = true
        return database
    }
}
