import Foundation
import SQLServerKit
import Observation

@Observable
@MainActor
final class LoginEditorViewModel {
    let connectionSessionID: UUID
    let existingLoginName: String?

    var isEditing: Bool { existingLoginName != nil }

    var serverName: String?

    // MARK: - General Page State

    var loginName = ""
    var authType: LoginAuthType = .sql
    var password = ""
    var confirmPassword = ""
    var defaultDatabase = "master"
    var defaultLanguage = ""
    var enforcePasswordPolicy = true
    var enforcePasswordExpiration = false
    var loginEnabled = true
    var isLocked = false

    var availableDatabases: [String] = ["master"]

    // MARK: - Server Roles State

    var roleEntries: [LoginEditorRoleEntry] = []

    // MARK: - User Mapping State

    var mappingEntries: [LoginEditorMappingEntry] = []
    var selectedMappingDatabase: String?
    var databaseRolesPerDB: [String: [LoginEditorDBRoleEntry]] = [:]

    var databaseRoleMemberships: [LoginEditorDBRoleEntry] {
        get {
            guard let db = selectedMappingDatabase else { return [] }
            return databaseRolesPerDB[db] ?? []
        }
        set {
            guard let db = selectedMappingDatabase else { return }
            databaseRolesPerDB[db] = newValue
        }
    }

    // MARK: - Securables State

    var serverPermissions: [LoginEditorPermissionEntry] = []
    var permissionConnectToEngine: ConnectSQLPermissionState = .unspecified

    // MARK: - Loading State

    var isLoadingGeneral = true
    var isLoadingRoles = false
    var isLoadingMappings = false
    var isLoadingDBRoles = false
    var isLoadingSecurables = false
    var hasLoadedRoles = false
    var hasLoadedMappings = false
    var hasLoadedSecurables = false

    // MARK: - Submit State

    var isSubmitting = false
    var errorMessage: String?
    var didComplete = false

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored internal var snapshot: Snapshot?

    struct Snapshot {
        let loginEnabled: Bool
        let defaultDatabase: String
        let defaultLanguage: String
        let enforcePasswordPolicy: Bool
        let enforcePasswordExpiration: Bool
        let roleMemberships: [String: Bool] // role name → isMember
        let permissionStates: [String: PermissionState]
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            loginEnabled: loginEnabled,
            defaultDatabase: defaultDatabase,
            defaultLanguage: defaultLanguage,
            enforcePasswordPolicy: enforcePasswordPolicy,
            enforcePasswordExpiration: enforcePasswordExpiration,
            roleMemberships: Dictionary(roleEntries.map { ($0.name, $0.isMember) }, uniquingKeysWith: { a, _ in a }),
            permissionStates: Dictionary(serverPermissions.map {
                ($0.permission, PermissionState(isGranted: $0.isGranted, withGrantOption: $0.withGrantOption, isDenied: $0.isDenied))
            }, uniquingKeysWith: { a, _ in a })
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing } // New login always has "changes" until snapshot

        if !password.isEmpty { return true }
        if loginEnabled != snapshot.loginEnabled { return true }
        if defaultDatabase != snapshot.defaultDatabase { return true }
        if defaultLanguage != snapshot.defaultLanguage { return true }
        if enforcePasswordPolicy != snapshot.enforcePasswordPolicy { return true }
        if enforcePasswordExpiration != snapshot.enforcePasswordExpiration { return true }

        // Check role membership changes
        for entry in roleEntries {
            if entry.isMember != (snapshot.roleMemberships[entry.name] ?? entry.originallyMember) {
                return true
            }
        }

        // Check permission changes
        for perm in serverPermissions {
            if let original = snapshot.permissionStates[perm.permission] {
                if perm.isGranted != original.isGranted ||
                    perm.withGrantOption != original.withGrantOption ||
                    perm.isDenied != original.isDenied {
                    return true
                }
            }
        }

        // Check mapping changes
        for entry in mappingEntries {
            if entry.isMapped != entry.originallyMapped { return true }
        }

        // Check database role changes
        for (_, roles) in databaseRolesPerDB {
            for role in roles {
                if role.isMember != role.originallyMember { return true }
            }
        }

        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, existingLoginName: String?) {
        self.connectionSessionID = connectionSessionID
        self.existingLoginName = existingLoginName
        if let existingLoginName {
            self.loginName = existingLoginName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = loginName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && authType == .sql {
            guard !password.isEmpty, password == confirmPassword else { return false }
        }
        return true
    }

    // MARK: - Pages

    var pages: [LoginEditorPage] {
        if isEditing {
            return [.general, .serverRoles, .userMapping, .securables]
        } else {
            return [.general, .serverRoles]
        }
    }

    // MARK: - Lazy Page Loading

    func ensurePageLoaded(_ page: LoginEditorPage, session: ConnectionSession) async {
        switch page {
        case .general:
            break // Loaded eagerly
        case .serverRoles:
            guard !hasLoadedRoles else { return }
            await loadRoles(session: session)
        case .userMapping:
            guard !hasLoadedMappings else { return }
            await loadMappings(session: session)
        case .securables:
            guard !hasLoadedSecurables else { return }
            await loadSecurables(session: session)
        }
    }
}
