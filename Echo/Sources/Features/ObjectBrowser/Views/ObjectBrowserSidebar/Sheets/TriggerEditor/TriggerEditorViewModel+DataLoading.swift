import Foundation

extension TriggerEditorViewModel {

    func load(session: ConnectionSession) async {
        guard isEditing else {
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let metadata = try await dialect.loadMetadata(
                session: session.session,
                schema: schemaName,
                table: tableName,
                name: triggerName
            )
            functionName = metadata.functionName
            timing = metadata.timing
            forEach = metadata.forEach
            onInsert = metadata.onInsert
            onUpdate = metadata.onUpdate
            onDelete = metadata.onDelete
            onTruncate = metadata.onTruncate
            whenCondition = metadata.whenCondition
            isEnabled = metadata.isEnabled
            description = metadata.description
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load trigger: \(error.localizedDescription)"
            takeSnapshot()
        }
    }
}
