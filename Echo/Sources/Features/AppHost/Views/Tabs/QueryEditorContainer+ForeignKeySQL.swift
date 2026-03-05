import SwiftUI
#if os(macOS)
import AppKit
#endif

extension QueryEditorContainer {
#if os(macOS)
    func makeForeignKeyLookupQuery(for selection: QueryResultsTableView.ForeignKeySelection, includeLimit: Bool) -> String? {
        let databaseType = tab.connection.databaseType
        guard let literal = makeForeignKeyLiteral(for: selection, databaseType: databaseType) else { return nil }
        let reference = selection.reference
        let tableIdentifier = qualifiedTable(schema: reference.referencedSchema, table: reference.referencedTable, databaseType: databaseType)
        let columnIdentifier = quoteIdentifier(reference.referencedColumn, databaseType: databaseType)

        switch databaseType {
        case .microsoftSQL:
            if includeLimit {
                return "SELECT TOP 1 * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            } else {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            }
        default:
            if includeLimit {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal) LIMIT 1;"
            } else {
                return "SELECT * FROM \(tableIdentifier) WHERE \(columnIdentifier) = \(literal);"
            }
        }
    }

    func qualifiedTable(schema: String, table: String, databaseType: DatabaseType) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        let tablePart = quoteIdentifier(table, databaseType: databaseType)
        guard !trimmedSchema.isEmpty else { return tablePart }
        return "\(quoteIdentifier(trimmedSchema, databaseType: databaseType)).\(tablePart)"
    }

    func quoteIdentifier(_ identifier: String, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .postgresql, .sqlite:
            let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        case .mysql:
            let escaped = identifier.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .microsoftSQL:
            let escaped = identifier.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        }
    }

    func makeForeignKeyLiteral(for selection: QueryResultsTableView.ForeignKeySelection, databaseType: DatabaseType) -> String? {
        let rawValue = selection.value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch selection.valueKind {
        case .numeric:
            return rawValue.isEmpty ? nil : rawValue
        case .boolean:
            let normalized = rawValue.lowercased()
            let truthy: Set<String> = ["true", "t", "1", "yes", "y"]
            let isTrue = truthy.contains(normalized)
            switch databaseType {
            case .mysql, .microsoftSQL:
                return isTrue ? "1" : "0"
            case .postgresql, .sqlite:
                return isTrue ? "TRUE" : "FALSE"
            }
        default:
            let escaped = rawValue.replacingOccurrences(of: "'", with: "''")
            return "'\(escaped)'"
        }
    }
#endif
}
