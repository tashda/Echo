import SwiftUI

/// Today's menus (ObjectBrowserSidebarView+ContextMenus, +ServerMenus, +DatabaseMenus,
/// +ObjectMenus, read 2026-10-01; SQL Server) and the proposals' commands, before the rules
/// arrange them.
enum LabCMMenus {
    typealias I = LabCMItem

    static let scriptAs = I.sub("Script as", "scroll", role: .script, [
        [I(title: "SELECT")], [I(title: "CREATE"), I(title: "ALTER")], [I(title: "INSERT"), I(title: "UPDATE"), I(title: "DELETE")],
        [I(title: "DROP"), I(title: "DROP and CREATE")],
    ])

    // MARK: Server

    static let serverToday: [[I]] = [
        [I(title: "Refresh All", symbol: "arrow.clockwise"), I(title: "New Query", symbol: "doc.text")],
        [I(title: "Activity Monitor", symbol: "gauge.with.dots.needle.33percent")],
        [I(title: "Maintenance"), I(title: "Database Mail"), I(title: "Central Management Servers"), I(title: "Extended Events"), I(title: "Availability Groups")],
        [I(title: "Hide Offline Databases", symbol: "eye.slash")],
        [I(title: "Manage Connection"), I(title: "Disconnect", symbol: "xmark.circle")],
        [I(title: "Properties", symbol: "info.circle")],
    ]

    static func serverProposal(toolsSubmenu: Bool) -> [I] {
        let tools: [I] = [I(title: "Maintenance", symbol: "wrench.and.screwdriver"), I(title: "Extended Events", symbol: "waveform.path.ecg"),
                          I(title: "Database Mail", symbol: "envelope"), I(title: "Availability Groups", symbol: "server.rack"),
                          I(title: "Central Management Servers", symbol: "server.rack")]
        var items: [I] = [I(title: "New Query", symbol: "plus.rectangle", role: .create), I(title: "Activity Monitor", symbol: "gauge.with.dots.needle.33percent")]
        if toolsSubmenu { items.append(I.sub("Open Tool", "wrench.and.screwdriver", [tools])) } else { items += tools.map { I(title: $0.title, symbol: $0.symbol, role: .tasks) } }
        items += [I(title: "Copy Name", symbol: "doc.on.doc", role: .copy),
                  I(title: "Refresh", symbol: "arrow.clockwise", role: .refresh), I(title: "Hide Offline Databases", symbol: "eye.slash", role: .toggle),
                  I(title: "Edit Connection", symbol: "slider.horizontal.3", role: .connection), I(title: "Disconnect", symbol: "xmark.circle", role: .connection),
                  I(title: "Properties", symbol: "info.circle", role: .info)]
        return items
    }

    // MARK: Database

    static let databaseTasksToday = I.sub("Tasks", "checklist", [
        [I(title: "Back Up"), I(title: "Restore")], [I(title: "Shrink Database")], [I(title: "Take Offline")], [I(title: "Detach Database")],
        [I(title: "Generate Scripts"), I(title: "Import Flat File"), I(title: "Migrate Data"), I(title: "Visual Query Builder")], [I(title: "Data-tier Application Tasks")],
    ])

    static let databaseToday: [[I]] = [
        [I(title: "Refresh Schema", symbol: "arrow.clockwise"), I(title: "New Query", symbol: "doc.text")],
        [I(title: "Maintenance")],
        [I.sub("Advanced Objects", nil, [[I(title: "Change Tracking"), I(title: "Change Data Capture"), I(title: "Full-Text Search"), I(title: "Replication")]]), databaseTasksToday],
        [I(title: "Drop Database", symbol: "trash")],
        [I(title: "Properties", symbol: "info.circle")],
    ]

    static func databaseProposal(backUpOnTop: Bool) -> [I] {
        var items: [I] = [I(title: "New Query", symbol: "plus.rectangle", role: .create), I(title: "Diagram", symbol: "rectangle.connected.to.line.below"),
                          I(title: "Query Builder", symbol: "square.stack.3d.up")]
        if backUpOnTop { items += [I(title: "Back Up", symbol: "externaldrive.badge.timemachine", role: .tasks), I(title: "Restore", symbol: "arrow.counterclockwise", role: .tasks)] }
        items += [
            I(title: "Copy Name", symbol: "doc.on.doc", role: .copy),
            I.sub("Tasks", "checklist", [
                backUpOnTop ? [] : [I(title: "Back Up"), I(title: "Restore")],
                [I(title: "Generate Scripts"), I(title: "Import Flat File"), I(title: "Migrate Data")],
                [I(title: "Shrink Database"), I(title: "Take Offline"), I(title: "Detach Database")],
                [I(title: "Data-tier Application")],
            ].filter { !$0.isEmpty }),
            I.sub("Open Tool", "wrench.and.screwdriver", [[I(title: "Maintenance"), I(title: "Security Overview"), I(title: "Advanced Objects")]]),
            I(title: "Refresh", symbol: "arrow.clockwise", role: .refresh),
            I(title: "Properties", symbol: "info.circle", role: .info),
            I(title: "Drop Database", symbol: "trash", role: .danger),
        ]
        return items
    }

    // MARK: Table and view

    static let tableToday: [[I]] = [
        [I(title: "New Query", symbol: "doc.text")],
        [I(title: "Data", symbol: "tablecells"), I(title: "Structure", symbol: "square.stack.3d.up"), I(title: "Diagram", symbol: "rectangle.connected.to.line.below")],
        [scriptAs],
        [I.sub("Tasks", "checklist", [[I(title: "Generate Scripts"), I(title: "Import Data"), I(title: "Enable System Versioning")]])],
        [I(title: "Drop Table", symbol: "trash")],
        [I(title: "Properties", symbol: "info.circle")],
    ]

    static func tableProposal(names: LabCMTableNames) -> [I] {
        let open = names == .verbs ? "Open Data" : "Data"
        let structure = names == .verbs ? "Edit Structure" : "Structure"
        return [
            I(title: open, symbol: "tablecells"), I(title: structure, symbol: "square.stack.3d.up"), I(title: "Diagram", symbol: "rectangle.connected.to.line.below"),
            I(title: "New Query", symbol: "plus.rectangle", role: .create),
            I(title: "Copy Name", symbol: "doc.on.doc", role: .copy), scriptAs,
            I.sub("Tasks", "checklist", role: .tasks, [[I(title: "Import Data"), I(title: "Export Data")], [I(title: "Generate Scripts"), I(title: "Enable System Versioning")],
                                                     [I(title: "Truncate Table")]]),
            I(title: "Refresh", symbol: "arrow.clockwise", role: .refresh),
            I(title: "Properties", symbol: "info.circle", role: .info),
            I(title: "Drop Table", symbol: "trash", role: .danger),
        ]
    }

    static let viewToday: [[I]] = [
        [I(title: "New Query", symbol: "doc.text")],
        [I(title: "Data", symbol: "tablecells"), I(title: "Definition", symbol: "doc.text")],
        [scriptAs], [I.sub("Tasks", "checklist", [[I(title: "Generate Scripts")]])],
        [I(title: "Drop View", symbol: "trash")],
    ]

    // MARK: Columns, routines and others

    static let columnProposal: [I] = [
        I(title: "Open Data Sorted by This Column", symbol: "arrow.up.arrow.down"),
        I(title: "Insert in Query", symbol: "text.insert", role: .create),
        I(title: "Copy Name", symbol: "doc.on.doc", role: .copy), I(title: "Copy Qualified Name", symbol: "doc.on.doc", role: .copy),
        I(title: "Rename", symbol: "pencil", role: .tasks),
        I(title: "Properties", symbol: "info.circle", role: .info),
        I(title: "Drop Column", symbol: "trash", role: .danger),
    ]

    static let procedureToday: [[I]] = [
        [I(title: "New Query", symbol: "doc.text")],
        [I(title: "Definition"), I(title: "Execute"), I(title: "Modify")],
        [scriptAs], [I.sub("Tasks", "checklist", [[I(title: "Generate Scripts")]])],
        [I(title: "Drop Procedure", symbol: "trash")],
    ]

    static let procedureProposal: [I] = [
        I(title: "Execute", symbol: "play"), I(title: "Modify", symbol: "pencil"), I(title: "Definition", symbol: "doc.text"),
        I(title: "Copy Name", symbol: "doc.on.doc", role: .copy), scriptAs,
        I(title: "Properties", symbol: "info.circle", role: .info),
        I(title: "Drop Procedure", symbol: "trash", role: .danger),
    ]

    static let loginToday: [[I]] = [
        [I.sub("Script as", "scroll", [[I(title: "CREATE")], [I(title: "DROP")]])],
        [I(title: "Disable Login")], [I(title: "Drop Login", symbol: "trash")], [I(title: "Properties", symbol: "info.circle")],
    ]

    static let loginProposal: [I] = [
        I(title: "Disable Login", symbol: "person.crop.circle.badge.xmark"), I(title: "Change Password", symbol: "key"),
        I(title: "Copy Name", symbol: "doc.on.doc", role: .copy), I.sub("Script as", "scroll", role: .script, [[I(title: "CREATE")], [I(title: "DROP")]]),
        I(title: "Properties", symbol: "info.circle", role: .info),
        I(title: "Drop Login", symbol: "trash", role: .danger),
    ]

    // MARK: Folders

    static let tablesFolderToday: [[I]] = [[I(title: "Refresh", symbol: "arrow.clockwise")], [I(title: "New Table"), I(title: "New Table (SQL)", symbol: "scroll")]]
    static let tablesFolderProposal: [I] = [
        I(title: "New Table", symbol: "plus.rectangle", role: .create), I(title: "New Table in SQL", symbol: "scroll", role: .create),
        I(title: "Filter Tables", symbol: "line.3.horizontal.decrease", role: .tasks),
        I(title: "Refresh", symbol: "arrow.clockwise", role: .refresh),
    ]
    static let securityFolderToday: [[I]] = [[I(title: "Refresh", symbol: "arrow.clockwise"), I(title: "New Login", symbol: "person.badge.plus")], [I(title: "Open Security Management", symbol: "lock.shield")]]
    static let securityFolderProposal: [I] = [
        I(title: "Security Overview", symbol: "lock.shield"), I(title: "New Login", symbol: "person.badge.plus", role: .create),
        I(title: "Refresh", symbol: "arrow.clockwise", role: .refresh),
    ]
    static let jobsFolderToday: [[I]] = [[I(title: "Refresh", symbol: "arrow.clockwise")], [I(title: "Open in Tab"), I(title: "Open in New Window")]]
    static let jobsFolderProposal: [I] = [
        I(title: "Agent Jobs Overview", symbol: "list.bullet.rectangle"), I(title: "New Job", symbol: "plus.rectangle", role: .create),
        I(title: "Open in New Window", symbol: "macwindow", role: .tasks),
        I(title: "Refresh", symbol: "arrow.clockwise", role: .refresh),
    ]
}

/// Words for a table's open commands (round 42.4).
enum LabCMTableNames: String, CaseIterable {
    case nouns = "TN0 · Data, Structure, Diagram (today)"
    case verbs = "TN1 · Open Data, Edit Structure, Diagram"
}
