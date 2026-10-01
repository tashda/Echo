import AppKit

/// Round 43.5 (PC0): on a connection that asks, an UPDATE or DELETE without WHERE waits for a yes.
extension WorkspaceTabContainerView {
    /// True when the run may go ahead.
    @MainActor
    func confirmsRun(of sql: String, on connection: SavedConnection) -> Bool {
        guard environmentState.confirmsUnguardedWrites(for: connection) else { return true }
        let flagged = UnguardedWriteDetector.unguardedStatements(in: sql)
        guard let first = flagged.first else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = flagged.count == 1
            ? "Run a statement with no WHERE on \(connection.connectionName)?"
            : "Run \(flagged.count) statements with no WHERE on \(connection.connectionName)?"
        alert.informativeText = "“\(first.prefix(80))” changes every row it reaches."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Run")
        return alert.runModal() == .alertSecondButtonReturn
    }
}
