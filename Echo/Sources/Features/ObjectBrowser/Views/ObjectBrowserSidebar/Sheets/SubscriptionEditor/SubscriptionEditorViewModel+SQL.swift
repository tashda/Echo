import Foundation
import PostgresKit

extension SubscriptionEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let quotedName = quoteIdentifier(subscriptionName)

        if isEditing {
            return generateAlterSQL(quotedName: quotedName)
        }

        return generateCreateSQL(quotedName: quotedName)
    }

    private func generateCreateSQL(quotedName: String) -> String {
        let pubList = parsedPublicationNames.map { quoteIdentifier($0) }.joined(separator: ", ")
        let escapedConnStr = connectionString.replacingOccurrences(of: "'", with: "''")

        var parts: [String] = [
            "CREATE SUBSCRIPTION \(quotedName)",
            "CONNECTION '\(escapedConnStr)'",
            "PUBLICATION \(pubList)"
        ]

        var withClauses: [String] = []
        if !enabled { withClauses.append("enabled = false") }
        if !copyData { withClauses.append("copy_data = false") }
        let trimmedSlot = slotName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSlot.isEmpty { withClauses.append("slot_name = '\(trimmedSlot)'") }
        if synchronousCommit != .off { withClauses.append("synchronous_commit = '\(synchronousCommit.rawValue)'") }

        if !withClauses.isEmpty {
            parts.append("WITH (\(withClauses.joined(separator: ", ")))")
        }

        return parts.joined(separator: "\n") + ";"
    }

    private func generateAlterSQL(quotedName: String) -> String {
        var statements: [String] = []

        // Recreate via DROP + CREATE for simplicity
        statements.append("DROP SUBSCRIPTION IF EXISTS \(quotedName);")
        statements.append(generateCreateSQL(quotedName: quotedName))

        return statements.joined(separator: "\n\n")
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Subscription editing requires a PostgreSQL connection."
            return
        }

        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter subscription \(subscriptionName)" : "Create subscription \(subscriptionName)",
            connectionSessionID: connectionSessionID
        )

        do {
            if isEditing {
                try await pg.client.replication.dropSubscription(name: subscriptionName, ifExists: true)
            }

            let trimmedSlot = slotName.trimmingCharacters(in: .whitespacesAndNewlines)

            try await pg.client.replication.createSubscription(
                name: subscriptionName,
                connectionString: connectionString,
                publications: parsedPublicationNames,
                enabled: enabled,
                copyData: copyData,
                slotName: trimmedSlot.isEmpty ? nil : trimmedSlot,
                synchronousCommit: synchronousCommit == .off ? nil : synchronousCommit.rawValue
            )

            handle?.succeed()
            takeSnapshot()
        } catch {
            let message = "Failed to apply: \(error.localizedDescription)"
            errorMessage = message
            handle?.fail(message)
        }

        isSubmitting = false
    }

    func saveAndClose(session: ConnectionSession) async {
        await apply(session: session)
        if errorMessage == nil {
            didComplete = true
        }
    }

    // MARK: - Identifier Quoting

    private func quoteIdentifier(_ identifier: String) -> String {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
