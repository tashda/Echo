import Foundation
import PostgresKit

extension SubscriptionEditorViewModel {

    // MARK: - Load

    func load(session: ConnectionSession) async {
        guard isEditing else {
            takeSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let pg = session.session as? PostgresSession else {
            errorMessage = "Subscription editing requires a PostgreSQL connection."
            takeSnapshot()
            return
        }

        do {
            try await loadExistingSubscription(pg: pg)
            takeSnapshot()
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
            takeSnapshot()
        }
    }

    // MARK: - Existing Subscription

    private func loadExistingSubscription(pg: PostgresSession) async throws {
        let subscriptions = try await pg.client.metadata.listSubscriptions()
        guard let sub = subscriptions.first(where: { $0.name == subscriptionName }) else { return }

        connectionString = sub.connectionInfo
        publicationNames = sub.publications.joined(separator: ", ")
        enabled = sub.enabled
        slotName = sub.slotName ?? ""
    }
}
