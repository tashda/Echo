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

        menu.addActionItem("Insert in Query", systemImage: "text.insert") {
            insertInQuery(quotedColumn, session: session, databaseName: owner.databaseName)
        }

        menu.addDivider()
        menu.addCopyName(column.name)
        menu.addActionItem("Copy Qualified Name", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(qualifiedTable).\(quotedColumn)", forType: .string)
        }

        menu.addDivider()
        menu.addActionItem("Rename", systemImage: "pencil") {
            let objectID = ExplorerSidebarIdentity.object(
                connectionID: session.connection.id, databaseName: owner.databaseName, objectID: owner.object.id)
            viewModel.renamingColumnNodeID = "\(objectID)#col#\(column.name)"
        }
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

extension ObjectBrowserSidebarView {
    /// After an in-place rename: the statement the rename will run, in a query tab to read and run.
    func showRename(of column: ColumnInfo, in owner: ExplorerColumnOwner, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != column.name else { return }
        let sql = ColumnRenameStatement.sql(
            table: qualifiedName(for: owner.object, databaseType: owner.session.connection.databaseType),
            oldName: column.name, newName: name, databaseType: owner.session.connection.databaseType)
        environmentState.openQueryTab(for: owner.session, presetQuery: sql, database: owner.databaseName)
    }

    /// Puts text at the caret of the query tab on screen; with none open, opens one with the text.
    func insertInQuery(_ text: String, session: ConnectionSession, databaseName: String) {
        if let editor = SQLTextView.visibleEditor(in: NSApp.keyWindow ?? NSApp.mainWindow) {
            editor.insertExternally(text)
        } else {
            environmentState.openQueryTab(for: session, presetQuery: text, database: databaseName)
        }
    }
}

/// The ALTER a column rename runs, per dialect.
nonisolated enum ColumnRenameStatement {
    static func sql(table: String, oldName: String, newName: String, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .microsoftSQL:
            let path = "\(table).[\(oldName.replacingOccurrences(of: "]", with: "]]"))]".replacingOccurrences(of: "'", with: "''")
            return "EXEC sp_rename N'\(path)', N'\(newName.replacingOccurrences(of: "'", with: "''"))', N'COLUMN';"
        case .postgresql, .mysql, .sqlite:
            return "ALTER TABLE \(table) RENAME COLUMN \(ColumnNameQuoting.quoted(oldName, databaseType: databaseType)) TO \(ColumnNameQuoting.quoted(newName, databaseType: databaseType));"
        }
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
