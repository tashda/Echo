import Foundation

extension SequenceEditorViewModel {

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
                name: sequenceName
            )
            startWith = metadata.startWith
            incrementBy = metadata.incrementBy
            minValue = metadata.minValue
            maxValue = metadata.maxValue
            cache = metadata.cache
            cycle = metadata.cycle
            owner = metadata.owner
            ownedBy = metadata.ownedBy
            lastValue = metadata.lastValue
            description = metadata.description
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load sequence: \(error.localizedDescription)"
            takeSnapshot()
        }
    }
}
