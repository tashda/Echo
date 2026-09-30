import SwiftUI

/// One row of sample tree content.
struct LabSCNode: Identifiable, Hashable {
    let id: String
    let title: String
    var prefix: String? = nil
    let symbol: String
    let color: Color
    var children: [LabSCNode] = []
    /// A folder whose items arrive from the server when it is first opened.
    var loadsOnOpen = false

    var isFolder: Bool { !children.isEmpty }
    var count: Int? { isFolder ? children.count : nil }
}

/// One dock section: its icon, the rows it shows, and its right-click menu.
struct LabSCSection: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let nodes: [LabSCNode]
    /// The section's own menu, as right-clicking its folder gave before the dock.
    let menu: [LabSCMenuItem]
    var initiallyExpanded: Set<String> = []
    /// Sections loaded when the server connects show at once; others load on first open.
    var loadsOnOpen = true
}

struct LabSCMenuItem: Identifiable, Hashable {
    let title: String
    let symbol: String
    var isDivider = false
    var id: String { title }

    static let divider = LabSCMenuItem(title: "—", symbol: "", isDivider: true)
}

enum LabSCEngine: String, CaseIterable, Identifiable {
    case sqlServer = "SQL Server"
    case postgres = "PostgreSQL"
    var id: String { rawValue }
}

struct LabSCServer: Identifiable, Hashable {
    let id: String
    let name: String
    let engine: LabSCEngine
    /// What the server reports, e.g. "Microsoft SQL Server 16.0.4250.1".
    let rawVersion: String
    let sections: [LabSCSection]

    /// Product and release, the way people say it: "SQL Server 2022", "PostgreSQL 18.3".
    var productLabel: String {
        switch engine {
        case .postgres:
            return rawVersion
        case .sqlServer:
            let build = rawVersion.split(separator: " ").last.map(String.init) ?? ""
            let major = build.split(separator: ".").first.map(String.init) ?? ""
            let years = ["17": "2025", "16": "2022", "15": "2019", "14": "2017", "13": "2016"]
            return years[major].map { "SQL Server \($0)" } ?? "SQL Server \(build)"
        }
    }

    func section(_ id: String) -> LabSCSection? { sections.first { $0.id == id } }
}

/// Which sections a server's dock shows, in order. The rest are one click away under More.
enum LabSCDefaults {
    static func dock(for engine: LabSCEngine) -> [String] {
        switch engine {
        case .sqlServer: ["databases", "security", "agent", "management"]
        case .postgres: ["databases", "security", "activity", "management", "tablespaces"]
        }
    }
}

extension LabSCServer {
    static let samples: [LabSCServer] = [mssql, postgres]
}

enum LabSCSampleNodes {
    static func leaves(_ parent: String, _ names: [String], symbol: String, color: Color) -> [LabSCNode] {
        names.map { name in
            let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
            return LabSCNode(id: "\(parent).\(name)", title: parts.last ?? name, prefix: parts.count == 2 ? parts[0] : nil, symbol: symbol, color: color)
        }
    }

    static func folder(_ id: String, _ title: String, symbol: String, color: Color, loadsOnOpen: Bool = false, _ children: [LabSCNode]) -> LabSCNode {
        LabSCNode(id: id, title: title, symbol: symbol, color: color, children: children, loadsOnOpen: loadsOnOpen)
    }

    static func tool(_ id: String, _ title: String, symbol: String, color: Color = ColorTokens.Text.secondary) -> LabSCNode {
        LabSCNode(id: id, title: title, symbol: symbol, color: color)
    }

    /// A database with its object folders; the first folder loads on open.
    static func database(_ server: String, _ name: String, tables: [String], views: [String] = [], functions: [String] = []) -> LabSCNode {
        let id = "\(server).db.\(name)"
        let explorer = ColorTokens.Explorer.self
        var folders = [folder("\(id).tables", "Tables", symbol: "tablecells", color: explorer.tables, loadsOnOpen: true,
                              leaves("\(id).tables", tables, symbol: "tablecells", color: explorer.tables))]
        if !views.isEmpty {
            folders.append(folder("\(id).views", "Views", symbol: "eye", color: explorer.views, leaves("\(id).views", views, symbol: "eye", color: explorer.views)))
        }
        if !functions.isEmpty {
            folders.append(folder("\(id).functions", "Functions", symbol: "function", color: explorer.functions,
                                  leaves("\(id).functions", functions, symbol: "function", color: explorer.functions)))
        }
        return folder(id, name, symbol: "cylinder", color: explorer.databaseInstance, folders)
    }
}
