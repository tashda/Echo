import Foundation
import Observation

@Observable
final class TriggerEditorViewModel {
    let connectionSessionID: UUID
    let schemaName: String
    let tableName: String
    let existingTriggerName: String?

    var isEditing: Bool { existingTriggerName != nil }

    // MARK: - Form State

    var triggerName = ""
    var functionName = ""
    var timing: TriggerTiming = .after
    var forEach: TriggerForEach = .row
    var onInsert = true
    var onUpdate = false
    var onDelete = false
    var onTruncate = false
    var whenCondition = ""
    var isEnabled = true
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
        let triggerName: String
        let functionName: String
        let timing: TriggerTiming
        let forEach: TriggerForEach
        let onInsert: Bool
        let onUpdate: Bool
        let onDelete: Bool
        let onTruncate: Bool
        let whenCondition: String
        let isEnabled: Bool
        let description: String
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            triggerName: triggerName,
            functionName: functionName,
            timing: timing,
            forEach: forEach,
            onInsert: onInsert,
            onUpdate: onUpdate,
            onDelete: onDelete,
            onTruncate: onTruncate,
            whenCondition: whenCondition,
            isEnabled: isEnabled,
            description: description
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }
        if triggerName != snapshot.triggerName { return true }
        if functionName != snapshot.functionName { return true }
        if timing != snapshot.timing { return true }
        if forEach != snapshot.forEach { return true }
        if onInsert != snapshot.onInsert { return true }
        if onUpdate != snapshot.onUpdate { return true }
        if onDelete != snapshot.onDelete { return true }
        if onTruncate != snapshot.onTruncate { return true }
        if whenCondition != snapshot.whenCondition { return true }
        if isEnabled != snapshot.isEnabled { return true }
        if description != snapshot.description { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, schemaName: String, tableName: String, existingTriggerName: String?) {
        self.connectionSessionID = connectionSessionID
        self.schemaName = schemaName
        self.tableName = tableName
        self.existingTriggerName = existingTriggerName
        if let existingTriggerName {
            self.triggerName = existingTriggerName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = triggerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        guard !functionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard onInsert || onUpdate || onDelete || onTruncate else { return false }
        return true
    }

    // MARK: - Pages

    var pages: [TriggerEditorPage] {
        TriggerEditorPage.allCases
    }
}
