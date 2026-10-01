import SwiftUI
import EchoSense

/// How a suggestion reads in the EchoSense popup (Design/05-components › EchoSense).
extension SQLAutoCompletionSuggestion {
    /// The one or two characters in the kind badge.
    var badgeText: String {
        switch kind {
        case .column: "C"
        case .table: "T"
        case .view: "V"
        case .materializedView: "M"
        case .function: "ƒ"
        case .keyword: "K"
        case .snippet: "S"
        case .parameter: "@"
        case .join: "J"
        case .database: "D"
        case .schema: "Sc"
        }
    }

    var badgeColor: Color {
        switch kind {
        case .column: ColorTokens.Explorer.views
        case .table: ColorTokens.Explorer.tables
        case .view, .materializedView: ColorTokens.Explorer.views
        case .function: ColorTokens.Explorer.functions
        case .keyword, .parameter: ColorTokens.Text.secondary
        case .snippet, .join: ColorTokens.Explorer.procedures
        case .database: ColorTokens.Explorer.databaseInstance
        case .schema: ColorTokens.Explorer.security
        }
    }

    /// A qualified column title ("soh.CustomerID") splits into its qualifier and name, so the
    /// row shows the name and the qualifier as a chip.
    var nameAndQualifier: (name: String, qualifier: String?) {
        guard kind == .column, let dot = title.lastIndex(of: "."), dot != title.startIndex else { return (title, nil) }
        return (String(title[title.index(after: dot)...]), String(title[..<dot]))
    }

    /// The right-hand text: a column's type, an object's schema, or nothing.
    var trailingText: String? {
        switch kind {
        case .column: dataType
        case .table, .view, .materializedView, .function: origin?.schema ?? subtitle
        case .snippet: "snippet"
        case .join: "join"
        default: nil
        }
    }

    /// The footer's second line: where it comes from and what is known about it.
    var footerDetail: String? {
        var parts: [String] = []
        switch kind {
        case .column:
            if let schema = origin?.schema, let object = origin?.object { parts.append("\(schema).\(object)") }
            else if let object = origin?.object { parts.append(object) }
            if let facts = columnFacts {
                parts.append(facts.isNullable ? "null" : "not null")
                if facts.isPrimaryKey { parts.append("primary key") }
                if let target = facts.foreignKeyTarget { parts.append("references \(target)") }
            }
        case .table, .view, .materializedView, .function:
            if let path = displayObjectPath { parts.append(path) }
            if let database = origin?.database { parts.append(database) }
            if let columns = tableColumns, !columns.isEmpty { parts.append("\(columns.count) columns") }
        default:
            if let detail = detail ?? subtitle { parts.append(detail) }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
