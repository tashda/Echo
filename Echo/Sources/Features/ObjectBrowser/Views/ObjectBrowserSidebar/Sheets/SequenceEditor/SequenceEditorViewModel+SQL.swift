import Foundation

extension SequenceEditorViewModel {

    func generateSQL() -> String {
        let context = SequenceEditorSQLContext(
            schema: schemaName,
            name: sequenceName,
            startWith: startWith,
            incrementBy: incrementBy,
            minValue: minValue,
            maxValue: maxValue,
            cache: cache,
            cycle: cycle,
            owner: owner,
            description: description,
            isEditing: isEditing
        )
        return dialect.generateSQL(context: context)
    }

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter sequence \(sequenceName)" : "Create sequence \(sequenceName)",
            connectionSessionID: connectionSessionID
        )

        do {
            let sql = generateSQL()
            _ = try await session.session.simpleQuery(sql)
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
}
