import SwiftUI
import EchoSense

extension DatabaseObjectRow {
    internal func objectTypeKeyword() -> String {
        switch object.type {
        case .table:
            return "TABLE"
        case .view:
            return "VIEW"
        case .materializedView:
            return "MATERIALIZED VIEW"
        case .function:
            return "FUNCTION"
        case .procedure:
            return "PROCEDURE"
        case .trigger:
            return "TRIGGER"
        }
    }

    internal func objectTypeDisplayName() -> String {
        switch object.type {
        case .table:
            return "Table"
        case .view:
            return "View"
        case .materializedView:
            return "Materialized View"
        case .function:
            return "Function"
        case .procedure:
            return "Procedure"
        case .trigger:
            return "Trigger"
        }
    }

    internal func qualifiedName(schema: String, name: String) -> String {
        let trimmedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSchema.isEmpty || connection.databaseType == .sqlite {
            return quoteIdentifier(name)
        }
        return "\(quoteIdentifier(trimmedSchema)).\(quoteIdentifier(name))"
    }

    internal func quoteIdentifier(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        switch connection.databaseType {
        case .mysql:
            let escaped = trimmed.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .microsoftSQL:
            let escaped = trimmed.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        default:
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
    }

    internal func triggerTargetName() -> String {
        guard let triggerTable = object.triggerTable, !triggerTable.isEmpty else {
            return qualifiedName(schema: object.schema, name: "<table_name>")
        }
        if triggerTable.contains(".") {
            let parts = triggerTable.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                return qualifiedName(schema: String(parts[0]), name: String(parts[1]))
            }
        }
        return qualifiedName(schema: object.schema, name: triggerTable)
    }
}
