import Foundation
import Observation

@Observable
final class SubscriptionEditorViewModel {
    let connectionSessionID: UUID
    let existingSubscriptionName: String?

    var isEditing: Bool { existingSubscriptionName != nil }

    // MARK: - Form State

    var subscriptionName = ""
    var connectionString = ""
    var publicationNames = ""
    var enabled = true
    var copyData = true
    var slotName = ""
    var synchronousCommit: SubscriptionSynchronousCommit = .off

    // MARK: - Loading State

    var isLoading = false
    var isSubmitting = false
    var didComplete = false
    var errorMessage: String?

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored private var snapshot: Snapshot?

    struct Snapshot {
        let subscriptionName: String
        let connectionString: String
        let publicationNames: String
        let enabled: Bool
        let copyData: Bool
        let slotName: String
        let synchronousCommit: SubscriptionSynchronousCommit
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            subscriptionName: subscriptionName,
            connectionString: connectionString,
            publicationNames: publicationNames,
            enabled: enabled,
            copyData: copyData,
            slotName: slotName,
            synchronousCommit: synchronousCommit
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }
        if subscriptionName != snapshot.subscriptionName { return true }
        if connectionString != snapshot.connectionString { return true }
        if publicationNames != snapshot.publicationNames { return true }
        if enabled != snapshot.enabled { return true }
        if copyData != snapshot.copyData { return true }
        if slotName != snapshot.slotName { return true }
        if synchronousCommit != snapshot.synchronousCommit { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, existingSubscriptionName: String?) {
        self.connectionSessionID = connectionSessionID
        self.existingSubscriptionName = existingSubscriptionName
        if let existingSubscriptionName {
            self.subscriptionName = existingSubscriptionName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = subscriptionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let connStr = connectionString.trimmingCharacters(in: .whitespacesAndNewlines)
        let pubs = publicationNames.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !connStr.isEmpty, !pubs.isEmpty, !isSubmitting else { return false }
        return true
    }

    // MARK: - Pages

    var pages: [SubscriptionEditorPage] {
        SubscriptionEditorPage.allCases
    }

    // MARK: - Parsed Publications

    var parsedPublicationNames: [String] {
        publicationNames
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
