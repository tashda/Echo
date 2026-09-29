import Foundation

/// Formatting and validating a query tab's SQL, shared by the toolbar and the Query menu.
extension WorkspaceTab {
    var formatterDialect: SQLFormatter.Dialect {
        switch connection.databaseType {
        case .microsoftSQL: .microsoftSQL
        case .mysql: .mysql
        case .sqlite: .sqlite
        default: .postgres
        }
    }

    /// Formats the script in place. A failure leaves the SQL unchanged.
    func formatSQL() async {
        guard let query, canRunQuery else { return }
        let original = query.sql
        guard let formatted = try? await SQLFormatter.shared.format(sql: original, dialect: formatterDialect) else { return }
        // Skip if the user typed while the formatter ran.
        if query.sql == original { query.sql = formatted }
    }

    func validateSQL() {
        guard canRunQuery else { return }
        query?.validationRequestGeneration += 1
    }
}
