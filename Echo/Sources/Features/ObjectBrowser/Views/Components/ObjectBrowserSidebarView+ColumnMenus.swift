import AppKit
import SwiftUI

/// The menu of a column row (round 42.2).
extension ObjectBrowserSidebarView {
    func columnMenu(for column: ColumnInfo, owner: ExplorerColumnOwner) -> NSMenu {
        let menu = NSMenu()
        let session = owner.session
        let databaseType = session.connection.databaseType
        let qualifiedTable = qualifiedName(for: owner.object, databaseType: databaseType)
        let quotedColumn = ColumnNameQuoting.quoted(column.name, databaseType: databaseType)

        menu.addActionItem("Open Data Sorted by This Column", systemImage: "arrow.up.arrow.down") {
            let sql = "SELECT * FROM \(qualifiedTable) ORDER BY \(quotedColumn);"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: owner.databaseName)
        }

        menu.addDivider()
        menu.addCopyName(column.name)
        menu.addActionItem("Copy Qualified Name", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(qualifiedTable).\(quotedColumn)", forType: .string)
        }

        menu.addDivider()
        menu.addActionItem("Drop Column", systemImage: "trash") {
            let sql = "ALTER TABLE \(qualifiedTable) DROP COLUMN \(quotedColumn);"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: owner.databaseName)
        }

        menu.addDivider()
        menu.addActionItem("Properties", systemImage: "info.circle") {
            environmentState.openStructureTab(for: session, object: owner.object, focus: .columns, databaseName: owner.databaseName)
        }
        return menu
    }
}

nonisolated enum ColumnNameQuoting {
    static func quoted(_ name: String, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .microsoftSQL: "[\(name.replacingOccurrences(of: "]", with: "]]"))]"
        case .postgresql, .sqlite: "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
        case .mysql: "`\(name.replacingOccurrences(of: "`", with: "``"))`"
        }
    }
}
