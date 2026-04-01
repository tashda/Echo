import Foundation

extension TypeEditorViewModel {

    func generateSQL() -> String {
        let context = TypeEditorSQLContext(
            schema: schemaName,
            name: typeName,
            owner: owner,
            description: description,
            category: typeCategory,
            isEditing: isEditing,
            attributes: attributes,
            enumValues: enumValues,
            subtype: subtype,
            subtypeOpClass: subtypeOpClass,
            collation: collation,
            baseDataType: baseDataType,
            defaultValue: defaultValue,
            isNotNull: isNotNull,
            domainConstraints: domainConstraints
        )
        return dialect.generateSQL(context: context)
    }

    func apply(session: ConnectionSession) async {
        isSubmitting = true
        errorMessage = nil
        let handle = activityEngine?.begin(
            isEditing ? "Alter \(typeCategory.title.lowercased()) \(typeName)" : "Create \(typeCategory.title.lowercased()) \(typeName)",
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
