import Foundation

extension TriggerEditorViewModel {

    func generateSQL() -> String {
        let context = TriggerEditorSQLContext(
            schema: schemaName,
            table: tableName,
            name: triggerName,
            functionName: functionName,
            timing: timing,
            forEach: forEach,
            onInsert: onInsert,
            onUpdate: onUpdate,
            onDelete: onDelete,
            onTruncate: onTruncate,
            whenCondition: whenCondition,
            isEnabled: isEnabled,
            description: description,
            isEditing: isEditing
        )
        return dialect.generateSQL(context: context)
    }

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter trigger \(triggerName)" : "Create trigger \(triggerName)",
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
