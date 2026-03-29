import SwiftUI
import PostgresKit

extension ObjectBrowserSidebarViewModel {

    // MARK: - Replication State Keys

    private func replicationKey(connectionID: UUID, database: String) -> String {
        "\(connectionID)-\(database)"
    }

    // MARK: - Publications

    func replicationPublicationsExpandedBinding(for connectionID: UUID, database: String) -> Binding<Bool> {
        let key = replicationKey(connectionID: connectionID, database: database)
        return Binding(
            get: { self.replicationPubExpanded[key] ?? false },
            set: { self.replicationPubExpanded[key] = $0 }
        )
    }

    func replicationPublications(connectionID: UUID, database: String) -> [PostgresPublicationInfo] {
        replicationPubData[replicationKey(connectionID: connectionID, database: database)] ?? []
    }

    func replicationPublicationCount(connectionID: UUID, database: String) -> Int? {
        let key = replicationKey(connectionID: connectionID, database: database)
        guard let data = replicationPubData[key] else { return nil }
        return data.count
    }

    func setReplicationPublications(_ pubs: [PostgresPublicationInfo], connectionID: UUID, database: String) {
        replicationPubData[replicationKey(connectionID: connectionID, database: database)] = pubs
    }

    // MARK: - Subscriptions

    func replicationSubscriptionsExpandedBinding(for connectionID: UUID, database: String) -> Binding<Bool> {
        let key = replicationKey(connectionID: connectionID, database: database)
        return Binding(
            get: { self.replicationSubExpanded[key] ?? false },
            set: { self.replicationSubExpanded[key] = $0 }
        )
    }

    func replicationSubscriptions(connectionID: UUID, database: String) -> [PostgresSubscriptionInfo] {
        replicationSubData[replicationKey(connectionID: connectionID, database: database)] ?? []
    }

    func replicationSubscriptionCount(connectionID: UUID, database: String) -> Int? {
        let key = replicationKey(connectionID: connectionID, database: database)
        guard let data = replicationSubData[key] else { return nil }
        return data.count
    }

    func setReplicationSubscriptions(_ subs: [PostgresSubscriptionInfo], connectionID: UUID, database: String) {
        replicationSubData[replicationKey(connectionID: connectionID, database: database)] = subs
    }
}
