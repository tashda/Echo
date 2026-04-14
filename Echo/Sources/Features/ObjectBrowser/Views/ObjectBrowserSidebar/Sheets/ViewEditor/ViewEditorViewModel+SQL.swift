import Foundation

extension ViewEditorViewModel {

    // MARK: - SQL Generation

    func generateSQL() -> String {
        let context = ViewEditorSQLContext(
            schema: schemaName,
            name: viewName,
            definition: definition,
            owner: owner,
            description: description,
            isMaterialized: isMaterialized,
            isEditing: isEditing,
            originalOwner: snapshot?.owner
        )
        return dialect.generateSQL(context: context)
    }

    // MARK: - Apply

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let objectType = isMaterialized ? "materialized view" : "view"
        let handle = activityEngine?.begin(
            isEditing ? "Alter \(objectType) \(viewName)" : "Create \(objectType) \(viewName)",
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
