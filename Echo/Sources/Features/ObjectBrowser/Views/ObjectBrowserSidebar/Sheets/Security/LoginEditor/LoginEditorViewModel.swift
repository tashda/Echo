import Foundation
import SQLServerKit
import Observation

@Observable
final class LoginEditorViewModel {
    let connectionSessionID: UUID
    let existingLoginName: String?

    var isEditing: Bool { existingLoginName != nil }

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

    var availableDatabases: [String] = ["master"]

    // MARK: - Server Roles State

    var roleEntries: [LoginEditorRoleEntry] = []

    // MARK: - User Mapping State

    var mappingEntries: [LoginEditorMappingEntry] = []
    var selectedMappingDatabase: String?
    var databaseRoleMemberships: [LoginEditorDBRoleEntry] = []

    // MARK: - Securables State

    var serverPermissions: [LoginEditorPermissionEntry] = []

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
            return [.general, .serverRoles, .userMapping, .securables, .status]
        } else {
            return [.general, .serverRoles, .status]
        }
    }

    // MARK: - Lazy Page Loading

    func ensurePageLoaded(_ page: LoginEditorPage, session: ConnectionSession) async {
        switch page {
        case .general, .status:
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
