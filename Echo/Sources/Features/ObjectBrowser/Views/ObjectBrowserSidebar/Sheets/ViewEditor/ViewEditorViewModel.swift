import Foundation
import Observation

@Observable
final class ViewEditorViewModel {
    let connectionSessionID: UUID
    let schemaName: String
    let existingViewName: String?
    let isMaterialized: Bool

    var isEditing: Bool { existingViewName != nil }

    // MARK: - Form State

    var viewName = ""
    var owner = ""
    var definition = ""
    var description = ""

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
        let viewName: String
        let owner: String
        let definition: String
        let description: String
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            viewName: viewName,
            owner: owner,
            definition: definition,
            description: description
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }
        if viewName != snapshot.viewName { return true }
        if owner != snapshot.owner { return true }
        if definition != snapshot.definition { return true }
        if description != snapshot.description { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, schemaName: String, existingViewName: String?, isMaterialized: Bool) {
        self.connectionSessionID = connectionSessionID
        self.schemaName = schemaName
        self.existingViewName = existingViewName
        self.isMaterialized = isMaterialized
        if let existingViewName {
            self.viewName = existingViewName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = viewName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        guard !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }

    // MARK: - Pages

    var pages: [ViewEditorPage] {
        ViewEditorPage.allCases
    }
}
