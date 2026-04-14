import Foundation
import Observation

@Observable
final class PublicationEditorViewModel {
    let connectionSessionID: UUID
    let existingPublicationName: String?

    var isEditing: Bool { existingPublicationName != nil }

    // MARK: - Form State

    var publicationName = ""
    var allTables = false
    var publishInsert = true
    var publishUpdate = true
    var publishDelete = true
    var publishTruncate = true
    var selectedTables: Set<String> = []
    var availableTables: [String] = []

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
        let publicationName: String
        let allTables: Bool
        let publishInsert: Bool
        let publishUpdate: Bool
        let publishDelete: Bool
        let publishTruncate: Bool
        let selectedTables: Set<String>
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            publicationName: publicationName,
            allTables: allTables,
            publishInsert: publishInsert,
            publishUpdate: publishUpdate,
            publishDelete: publishDelete,
            publishTruncate: publishTruncate,
            selectedTables: selectedTables
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }
        if publicationName != snapshot.publicationName { return true }
        if allTables != snapshot.allTables { return true }
        if publishInsert != snapshot.publishInsert { return true }
        if publishUpdate != snapshot.publishUpdate { return true }
        if publishDelete != snapshot.publishDelete { return true }
        if publishTruncate != snapshot.publishTruncate { return true }
        if selectedTables != snapshot.selectedTables { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, existingPublicationName: String?) {
        self.connectionSessionID = connectionSessionID
        self.existingPublicationName = existingPublicationName
        if let existingPublicationName {
            self.publicationName = existingPublicationName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = publicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !allTables && selectedTables.isEmpty { return false }
        return true
    }

    // MARK: - Pages

    var pages: [PublicationEditorPage] {
        PublicationEditorPage.allCases
    }
}
