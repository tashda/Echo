import SwiftUI

/// Shared scripting utilities for security section views.
/// Eliminates duplication of quoteIdentifier and common script templates.
///
/// Note: `openScriptTab` is not here because static methods in Shared/ don't inherit
/// MainActor isolation. Call `environmentState.openQueryTab(for:presetQuery:)` directly
/// in your views instead.
struct ScriptingActions {

    /// Quote a PostgreSQL identifier (double-quote escaping).
    static func pgQuote(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// Build a schema-qualified PostgreSQL identifier.
    static func pgQualifiedName(schema: String, name: String) -> String {
        "\(pgQuote(schema)).\(pgQuote(name))"
    }

    /// Quote a SQL Server identifier (bracket escaping).
    static func mssqlQuote(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "]", with: "]]")
        return "[\(escaped)]"
    }

    /// Generate a CREATE script for any object type.
    static func scriptCreate(objectType: String, qualifiedName: String) -> String {
        "CREATE \(objectType) \(qualifiedName);"
    }

    /// Generate a DROP IF EXISTS script for any object type.
    static func scriptDrop(objectType: String, qualifiedName: String) -> String {
        "DROP \(objectType) IF EXISTS \(qualifiedName);"
    }
}
