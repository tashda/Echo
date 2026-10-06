#if os(macOS)
import AppKit
import EchoSense

/// Cross-database completion tracing, off unless `ECHO_CROSSDB_DEBUG` is set. It used to write a line to
/// /tmp/echo_crossdb_debug.log (open, seek, write, close) on the main thread for every completion
/// and every new completion context, in every build.
let crossDBDebugEnabled = ProcessInfo.processInfo.environment["ECHO_CROSSDB_DEBUG"] != nil

func crossDBDebug(_ message: @autoclosure () -> String) {
    guard crossDBDebugEnabled else { return }
    let line = "[\(Date())] \(message())\n"
    if let data = line.data(using: .utf8) {
        let url = URL(fileURLWithPath: "/tmp/echo_crossdb_debug.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? data.write(to: url)
        }
    }
}

extension SQLTextView {
    /// Fires `onSchemaLoadNeeded` when the current completion token references a database
    /// whose schemas are not yet in the completion context. Called once per completion
    /// trigger so the caller can load schemas on demand without blocking the UI.
    func notifySchemaLoadIfNeeded(text: String, caretLocation: Int) {
        crossDBDebug("[CROSSDB] called at caret=\(caretLocation)")
        guard let context = completionContext,
              let structure = context.structure else {
            crossDBDebug("[CROSSDB] no context or structure")
            return
        }

        // Scan backward from caret to find a "xxx." pattern (cross-database prefix)
        let nsString = text as NSString
        guard caretLocation <= nsString.length else { return }

        // Find the token at the caret position
        let tokenRange = self.tokenRange(at: caretLocation, in: nsString)
        guard tokenRange.length > 0 else {
            crossDBDebug("[CROSSDB] tokenRange empty at caret \(caretLocation)")
            return
        }

        let token = nsString.substring(with: tokenRange)
        let components = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        crossDBDebug("[CROSSDB] token='\(token)', components=\(components)")

        // Need at least a "database." prefix (2+ components)
        guard components.count >= 2, let dbName = components.first, !dbName.isEmpty else { return }

        // Only trigger a load when dbName matches a known database in the structure.
        // If it doesn't match any database, it's likely a schema-qualified reference
        // (e.g., "Sales.Customer") rather than a cross-database reference.
        guard let database = structure.databases
            .first(where: { $0.name.caseInsensitiveCompare(dbName) == .orderedSame }) else {
            crossDBDebug("[CROSSDB] '\(dbName)' not found in \(structure.databases.count) databases")
            return
        }

        // Already has schemas loaded — nothing to do.
        guard database.schemas.isEmpty else {
            crossDBDebug("[CROSSDB] '\(dbName)' already has \(database.schemas.count) schemas")
            return
        }

        crossDBDebug("[CROSSDB] triggering schema load for '\(dbName)'")
        onSchemaLoadNeeded?(dbName)
    }

    /// Re-triggers completions when the completion context updates with new schemas.
    /// Called from the `completionContext` didSet after schema loading completes.
    func retriggerCompletionsIfNeeded(oldContext: SQLEditorCompletionContext?) {
        guard let newContext = completionContext,
              let newStructure = newContext.structure else {
            crossDBDebug("[CROSSDB-RETRIGGER] no new context/structure")
            return
        }

        // Re-trigger only if the autocomplete popover is showing (the user sees stale results) or the
        // caret is after a dot (waiting for post-dot suggestions). Checked first: counting every
        // object of every database costs milliseconds, and a context arrives for each schema loaded.
        let isPresenting = completionController?.isPresenting == true
        let isAfterDot = !isPresenting && caretIsAfterDot()
        guard isPresenting || isAfterDot else { return }

        let oldTableCount = oldContext?.structure?.databases.reduce(0) { sum, db in
            sum + db.schemas.reduce(0) { $0 + $1.objects.count }
        } ?? 0
        let newTableCount = newStructure.databases.reduce(0) { sum, db in
            sum + db.schemas.reduce(0) { $0 + $1.objects.count }
        }
        crossDBDebug("[CROSSDB-RETRIGGER] oldTables=\(oldTableCount), newTables=\(newTableCount), isPresenting=\(isPresenting)")

        // Only re-trigger if tables/schemas were actually added (structure grew)
        guard newTableCount > oldTableCount else { return }
        refreshCompletions(immediate: true)
    }

    private func caretIsAfterDot() -> Bool {
        let caretLocation = selectedRange().location
        guard caretLocation != NSNotFound, caretLocation > 0 else { return false }
        let nsString = string as NSString
        guard caretLocation <= nsString.length else { return false }
        return nsString.character(at: caretLocation - 1) == UInt16(UnicodeScalar(".").value)
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
