import Foundation
import SQLServerKit
import Observation

@Observable
final class RoleEditorViewModel {
    let connectionSessionID: UUID
    let databaseName: String
    let existingRoleName: String?

    var isEditing: Bool { existingRoleName != nil }

    // MARK: - General Page State

    var roleName = ""
    var owner = ""
    var availableOwners: [String] = []

    // MARK: - Membership State

    var memberEntries: [RoleMemberEntry] = []

    // MARK: - Securables State

    var securableEntries: [SecurableEntry] = []
    var selectedSecurableID: UUID?

    // MARK: - Loading State

    var isLoadingGeneral = true
    var isLoadingMembers = false
    var isLoadingSecurables = false
    var hasLoadedMembers = false
    var hasLoadedSecurables = false

    // MARK: - Submit State

    var isSubmitting = false
    var errorMessage: String?
    var didComplete = false

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored private var snapshot: Snapshot?

    struct Snapshot {
        let owner: String
        let memberships: [String: Bool]
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            owner: owner,
            memberships: Dictionary(
                memberEntries.map { ($0.name, $0.isMember) },
                uniquingKeysWith: { a, _ in a }
            )
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }

        if owner != snapshot.owner { return true }

        for entry in memberEntries {
            if entry.isMember != (snapshot.memberships[entry.name] ?? entry.originallyMember) {
                return true
            }
        }

        // Check securables
        for sec in securableEntries {
            for perm in sec.permissions {
                if perm.isGranted != perm.originalState.isGranted ||
                    perm.withGrantOption != perm.originalState.withGrantOption ||
                    perm.isDenied != perm.originalState.isDenied {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, databaseName: String, existingRoleName: String?) {
        self.connectionSessionID = connectionSessionID
        self.databaseName = databaseName
        self.existingRoleName = existingRoleName
        if let existingRoleName {
            self.roleName = existingRoleName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        return true
    }

    // MARK: - Lazy Page Loading

    func ensurePageLoaded(_ page: RoleEditorPage, session: ConnectionSession) async {
        switch page {
        case .general:
            break // Always loaded eagerly
        case .membership:
            guard !hasLoadedMembers else { return }
            await loadMembers(session: session)
        case .securables:
            guard !hasLoadedSecurables else { return }
            await loadSecurables(session: session)
        }
    }
}
