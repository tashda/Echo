import Foundation
import Observation

@Observable
final class SequenceEditorViewModel {
    let connectionSessionID: UUID
    let schemaName: String
    let existingSequenceName: String?

    var isEditing: Bool { existingSequenceName != nil }

    // MARK: - Form State

    var sequenceName = ""
    var startWith = "1"
    var incrementBy = "1"
    var minValue = ""
    var maxValue = ""
    var cache = "1"
    var cycle = false
    var owner = ""
    var ownedBy = ""
    var lastValue = ""
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
        let sequenceName: String
        let startWith: String
        let incrementBy: String
        let minValue: String
        let maxValue: String
        let cache: String
        let cycle: Bool
        let owner: String
        let ownedBy: String
        let description: String
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            sequenceName: sequenceName,
            startWith: startWith,
            incrementBy: incrementBy,
            minValue: minValue,
            maxValue: maxValue,
            cache: cache,
            cycle: cycle,
            owner: owner,
            ownedBy: ownedBy,
            description: description
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }
        if sequenceName != snapshot.sequenceName { return true }
        if startWith != snapshot.startWith { return true }
        if incrementBy != snapshot.incrementBy { return true }
        if minValue != snapshot.minValue { return true }
        if maxValue != snapshot.maxValue { return true }
        if cache != snapshot.cache { return true }
        if cycle != snapshot.cycle { return true }
        if owner != snapshot.owner { return true }
        if ownedBy != snapshot.ownedBy { return true }
        if description != snapshot.description { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, schemaName: String, existingSequenceName: String?) {
        self.connectionSessionID = connectionSessionID
        self.schemaName = schemaName
        self.existingSequenceName = existingSequenceName
        if let existingSequenceName {
            self.sequenceName = existingSequenceName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = sequenceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        return true
    }

    // MARK: - Pages

    var pages: [SequenceEditorPage] {
        SequenceEditorPage.allCases
    }
}
