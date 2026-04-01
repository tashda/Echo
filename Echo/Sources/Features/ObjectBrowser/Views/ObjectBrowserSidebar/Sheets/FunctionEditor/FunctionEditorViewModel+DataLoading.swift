import Foundation

extension FunctionEditorViewModel {

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
                name: functionName
            )
            language = metadata.language
            returnType = metadata.returnType
            body = metadata.body
            volatility = metadata.volatility
            parallelSafety = metadata.parallelSafety
            securityType = metadata.securityType
            isStrict = metadata.isStrict
            cost = metadata.cost
            estimatedRows = metadata.estimatedRows
            description = metadata.description
            parameters = metadata.parameters
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load function: \(error.localizedDescription)"
            takeSnapshot()
        }
    }
}
