#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    /// Fires `onSchemaLoadNeeded` when the current completion token references a database
    /// whose schemas are not yet in the completion context. Called once per completion
    /// trigger so the caller can load schemas on demand without blocking the UI.
    func notifySchemaLoadIfNeeded(text: String, caretLocation: Int) {
        guard let context = completionContext,
              let structure = context.structure else { return }

        // Scan backward from caret to find a "xxx." pattern (cross-database prefix)
        let nsString = text as NSString
        guard caretLocation <= nsString.length else { return }

        // Find the token at the caret position
        let tokenRange = self.tokenRange(at: caretLocation, in: nsString)
        guard tokenRange.length > 0 else { return }

        let token = nsString.substring(with: tokenRange)
        let components = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)

        // Need at least a "database." prefix (2+ components)
        guard components.count >= 2, let dbName = components.first, !dbName.isEmpty else { return }

        // Only trigger a load when dbName matches a known database in the structure.
        // If it doesn't match any database, it's likely a schema-qualified reference
        // (e.g., "Sales.Customer") rather than a cross-database reference.
        guard let database = structure.databases
            .first(where: { $0.name.caseInsensitiveCompare(dbName) == .orderedSame }) else { return }

        // Already has schemas loaded — nothing to do.
        guard database.schemas.isEmpty else { return }

        onSchemaLoadNeeded?(dbName)
    }

    /// Legacy overload for callers that still use SQLAutoCompletionQuery.
    func notifySchemaLoadIfNeeded(for query: SQLAutoCompletionQuery) {
        guard let dbName = query.pathComponents.first,
              !dbName.isEmpty,
              let context = completionContext,
              let structure = context.structure else { return }

        guard structure.databases.contains(where: { $0.name.caseInsensitiveCompare(dbName) == .orderedSame }) else { return }

        let hasSchemas = structure.databases
            .first(where: { $0.name.caseInsensitiveCompare(dbName) == .orderedSame })?
            .schemas.isEmpty == false
        guard !hasSchemas else { return }

        onSchemaLoadNeeded?(dbName)
    }
}
#endif
