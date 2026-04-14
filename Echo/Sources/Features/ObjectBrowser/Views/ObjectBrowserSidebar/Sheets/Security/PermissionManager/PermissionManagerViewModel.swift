import Foundation
import SQLServerKit
import Observation

@Observable
final class PermissionManagerViewModel {
    let connectionSessionID: UUID
    let databaseName: String
    let initialPrincipalName: String?

    // MARK: - Principal Selection

    var principals: [PrincipalChoice] = []
    var selectedPrincipalName: String = ""

    // MARK: - Securables State

    var securableEntries: [SecurableEntry] = []
    var selectedSecurableID: UUID?

    // MARK: - Effective Permissions

    var effectivePermissions: [EffectivePermissionRow] = []

    // MARK: - Loading State

    var isLoadingPrincipals = true
    var isLoadingSecurables = false
    var isLoadingEffective = false
    var hasLoadedSecurables = false
    var hasLoadedEffective = false

    // MARK: - Submit State

    var isSubmitting = false
    var errorMessage: String?
    var didComplete = false

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored private var snapshot: Snapshot?

    struct Snapshot {
        let permissionStates: [String: [String: PermissionState]]
    }

    func takeSnapshot() {
        var states: [String: [String: PermissionState]] = [:]
        for entry in securableEntries {
            var perms: [String: PermissionState] = [:]
            for perm in entry.permissions {
                perms[perm.permission] = PermissionState(
                    isGranted: perm.isGranted,
                    withGrantOption: perm.withGrantOption,
                    isDenied: perm.isDenied
                )
            }
            states[entry.id.uuidString] = perms
        }
        snapshot = Snapshot(permissionStates: states)
    }

    var hasChanges: Bool {
        guard let snapshot else { return false }
        for entry in securableEntries {
            let key = entry.id.uuidString
            let original = snapshot.permissionStates[key]
            for perm in entry.permissions {
                let orig = original?[perm.permission] ?? perm.originalState
                if perm.isGranted != orig.isGranted ||
                    perm.withGrantOption != orig.withGrantOption ||
                    perm.isDenied != orig.isDenied {
                    return true
                }
            }
            if original == nil && !entry.permissions.allSatisfy({ !$0.isGranted && !$0.isDenied }) {
                return true
            }
        }
        return false
    }

    // MARK: - Validation

    var isFormValid: Bool {
        !selectedPrincipalName.isEmpty && !isSubmitting
    }

    // MARK: - Init

    init(connectionSessionID: UUID, databaseName: String, principalName: String?) {
        self.connectionSessionID = connectionSessionID
        self.databaseName = databaseName
        self.initialPrincipalName = principalName
        if let principalName {
            self.selectedPrincipalName = principalName
        }
    }

    // MARK: - Pages

    var pages: [PermissionManagerPage] {
        PermissionManagerPage.allCases
    }

    // MARK: - Lazy Page Loading

    func ensurePageLoaded(_ page: PermissionManagerPage, session: ConnectionSession) async {
        switch page {
        case .securables:
            guard !hasLoadedSecurables else { return }
            await loadSecurables(session: session)
        case .effectivePermissions:
            guard !hasLoadedEffective else { return }
            await loadEffectivePermissions(session: session)
        }
    }

    // MARK: - Principal Change

    func onPrincipalChanged(session: ConnectionSession) async {
        hasLoadedSecurables = false
        hasLoadedEffective = false
        securableEntries = []
        effectivePermissions = []
        selectedSecurableID = nil
        snapshot = nil
        await loadSecurables(session: session)
    }
}

// MARK: - Effective Permission Row

struct EffectivePermissionRow: Identifiable, Hashable {
    var id: String { "\(securableClass).\(securableName).\(permission)" }
    let permission: String
    let securableClass: String
    let securableName: String
    let grantor: String
    let state: String
}
