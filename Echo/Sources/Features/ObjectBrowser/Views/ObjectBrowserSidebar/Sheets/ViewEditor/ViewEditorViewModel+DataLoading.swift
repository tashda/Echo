import Foundation

extension ViewEditorViewModel {

    // MARK: - Load Existing View

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
                name: viewName,
                isMaterialized: isMaterialized
            )
            owner = metadata.owner
            definition = metadata.definition
            description = metadata.description
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load view: \(error.localizedDescription)"
            takeSnapshot()
        }
    }
}
