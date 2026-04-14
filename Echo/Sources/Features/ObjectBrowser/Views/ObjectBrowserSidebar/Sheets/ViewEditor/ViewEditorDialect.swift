import Foundation

/// Strategy protocol for dialect-specific view editor behavior.
/// Each database type (PostgreSQL, MSSQL, etc.) provides its own conformance.
protocol ViewEditorDialect: Sendable {

    /// Load an existing view's metadata from the database catalog.
    func loadMetadata(session: any DatabaseSession, schema: String, name: String, isMaterialized: Bool) async throws -> ViewEditorMetadata

    /// Generate DDL for creating or altering a view.
    func generateSQL(context: ViewEditorSQLContext) -> String

    /// Quote an identifier for this dialect (e.g. `"id"` for PG, `[id]` for MSSQL).
    func quoteIdentifier(_ identifier: String) -> String

    // MARK: - Form Configuration

    /// Whether the dialect supports materialized views.
    var supportsMaterializedViews: Bool { get }

    /// Whether the dialect supports changing view ownership.
    var supportsOwnership: Bool { get }

    /// Whether the dialect supports COMMENT ON / extended properties for views.
    var supportsComments: Bool { get }

    /// Whether the dialect supports CREATE OR REPLACE VIEW.
    var supportsCreateOrReplace: Bool { get }
}

/// Metadata loaded from the database for pre-populating the editor form.
struct ViewEditorMetadata: Sendable {
    var name: String
    var owner: String
    var definition: String
    var description: String
}

/// All form state needed to generate DDL.
struct ViewEditorSQLContext: Sendable {
    var schema: String
    var name: String
    var definition: String
    var owner: String
    var description: String
    var isMaterialized: Bool
    var isEditing: Bool
    var originalOwner: String?
}
