import Foundation

extension TypeEditorViewModel {

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
                name: typeName,
                category: typeCategory
            )
            owner = metadata.owner
            description = metadata.description
            attributes = metadata.attributes
            enumValues = metadata.enumValues
            subtype = metadata.subtype
            subtypeOpClass = metadata.subtypeOpClass
            collation = metadata.collation
            baseDataType = metadata.baseDataType
            defaultValue = metadata.defaultValue
            isNotNull = metadata.isNotNull
            domainConstraints = metadata.domainConstraints
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load type: \(error.localizedDescription)"
            takeSnapshot()
        }
    }
}
