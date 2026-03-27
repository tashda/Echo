import Foundation
import PostgresKit
import Observation

@Observable
final class PgRoleEditorViewModel {
    let connectionSessionID: UUID
    let existingRoleName: String?

    var isEditing: Bool { existingRoleName != nil }

    // MARK: - General State

    var roleName = ""
    var password = ""
    var passwordConfirm = ""
    var connectionLimit = "-1"
    var description = ""

    // MARK: - Expiration State

    var hasExpiration = false
    var validUntil: Date = Date()

    // MARK: - Privilege State

    var canLogin = true
    var isSuperuser = false
    var canCreateDB = false
    var canCreateRole = false
    var inherit = true
    var isReplication = false
    var bypassRLS = false

    // MARK: - Membership State

    var memberOf: [PgRoleMembershipDraft] = []
    var members: [PgRoleMembershipDraft] = []
    var availableRoles: [String] = []

    // MARK: - Parameters State

    var roleParameters: [PgRoleParameterDraft] = []
    var settingDefinitions: [PostgresSettingDefinition] = []

    // MARK: - Loading State

    var isLoading = true
    var isSubmitting = false
    var errorMessage: String?
    var didComplete = false

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored private var snapshot: Snapshot?

    struct Snapshot {
        let canLogin: Bool
        let isSuperuser: Bool
        let canCreateDB: Bool
        let canCreateRole: Bool
        let inherit: Bool
        let isReplication: Bool
        let bypassRLS: Bool
        let connectionLimit: String
        let hasExpiration: Bool
        let validUntil: Date
        let description: String
        let memberOfNames: [String]
        let memberNames: [String]
        let parameterCount: Int
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            canLogin: canLogin,
            isSuperuser: isSuperuser,
            canCreateDB: canCreateDB,
            canCreateRole: canCreateRole,
            inherit: inherit,
            isReplication: isReplication,
            bypassRLS: bypassRLS,
            connectionLimit: connectionLimit,
            hasExpiration: hasExpiration,
            validUntil: validUntil,
            description: description,
            memberOfNames: memberOf.map(\.roleName).sorted(),
            memberNames: members.map(\.roleName).sorted(),
            parameterCount: roleParameters.count
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }

        if !password.isEmpty { return true }
        if canLogin != snapshot.canLogin { return true }
        if isSuperuser != snapshot.isSuperuser { return true }
        if canCreateDB != snapshot.canCreateDB { return true }
        if canCreateRole != snapshot.canCreateRole { return true }
        if inherit != snapshot.inherit { return true }
        if isReplication != snapshot.isReplication { return true }
        if bypassRLS != snapshot.bypassRLS { return true }
        if connectionLimit != snapshot.connectionLimit { return true }
        if hasExpiration != snapshot.hasExpiration { return true }
        if hasExpiration && validUntil != snapshot.validUntil { return true }
        if description != snapshot.description { return true }
        if memberOf.map(\.roleName).sorted() != snapshot.memberOfNames { return true }
        if members.map(\.roleName).sorted() != snapshot.memberNames { return true }
        if roleParameters.count != snapshot.parameterCount { return true }
        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, existingRoleName: String?) {
        self.connectionSessionID = connectionSessionID
        self.existingRoleName = existingRoleName
        if let existingRoleName {
            self.roleName = existingRoleName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }
        if !isEditing && !password.isEmpty && password != passwordConfirm {
            return false
        }
        return true
    }

    // MARK: - Pages

    var pages: [PgRoleEditorPage] {
        if isEditing {
            return PgRoleEditorPage.allCases
        } else {
            return [.general, .privileges, .membership]
        }
    }
}
