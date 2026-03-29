import Foundation
import SQLServerKit
import Observation

@Observable
final class UserEditorViewModel {
    let connectionSessionID: UUID
    let databaseName: String
    let existingUserName: String?

    var isEditing: Bool { existingUserName != nil }

    // MARK: - General Page State

    var userName = ""
    var userType: DatabaseUserTypeChoice = .mappedToLogin
    var loginName = ""
    var password = ""
    var confirmPassword = ""
    var defaultSchema = "dbo"
    var defaultLanguage = ""
    var allowEncryptedValueModifications = false

    // Picker data
    var availableLogins: [String] = []
    var availableCertificates: [CertificateInfo] = []
    var availableAsymmetricKeys: [AsymmetricKeyInfo] = []
    var availableLanguages: [LanguageInfo] = []
    var selectedCertificate = ""
    var selectedAsymmetricKey = ""
    var isDatabaseContained = false

    // MARK: - Owned Schemas State

    var schemaEntries: [SchemaOwnerEntry] = []

    // MARK: - Membership State

    var roleEntries: [UserEditorRoleMemberEntry] = []

    // MARK: - Securables State

    var securableEntries: [SecurableEntry] = []
    var selectedSecurableID: UUID?

    // MARK: - Extended Properties State

    var extendedPropertyEntries: [ExtendedPropertyEntry] = []
    var selectedPropertyID: UUID?

    // MARK: - Loading State

    var isLoadingGeneral = true
    var isLoadingSchemas = false
    var isLoadingRoles = false
    var isLoadingSecurables = false
    var isLoadingExtendedProperties = false
    var hasLoadedSchemas = false
    var hasLoadedRoles = false
    var hasLoadedSecurables = false
    var hasLoadedExtendedProperties = false

    // MARK: - Submit State

    var isSubmitting = false
    var errorMessage: String?
    var didComplete = false

    // MARK: - ActivityEngine

    @ObservationIgnored var activityEngine: ActivityEngine?

    // MARK: - Dirty Tracking

    @ObservationIgnored private var snapshot: Snapshot?

    struct Snapshot {
        let defaultSchema: String
        let userType: DatabaseUserTypeChoice
        let loginName: String
        let selectedCertificate: String
        let selectedAsymmetricKey: String
        let defaultLanguage: String
        let roleMemberships: [String: Bool]
        let schemaOwnership: [String: Bool]
    }

    func takeSnapshot() {
        snapshot = Snapshot(
            defaultSchema: defaultSchema,
            userType: userType,
            loginName: loginName,
            selectedCertificate: selectedCertificate,
            selectedAsymmetricKey: selectedAsymmetricKey,
            defaultLanguage: defaultLanguage,
            roleMemberships: Dictionary(roleEntries.map { ($0.name, $0.isMember) }, uniquingKeysWith: { a, _ in a }),
            schemaOwnership: Dictionary(schemaEntries.map { ($0.name, $0.isOwned) }, uniquingKeysWith: { a, _ in a })
        )
    }

    var hasChanges: Bool {
        guard let snapshot else { return !isEditing }

        if !password.isEmpty { return true }
        if defaultSchema != snapshot.defaultSchema { return true }
        if userType != snapshot.userType { return true }
        if loginName != snapshot.loginName { return true }
        if selectedCertificate != snapshot.selectedCertificate { return true }
        if selectedAsymmetricKey != snapshot.selectedAsymmetricKey { return true }
        if defaultLanguage != snapshot.defaultLanguage { return true }

        for entry in roleEntries {
            if entry.isMember != (snapshot.roleMemberships[entry.name] ?? entry.originallyMember) {
                return true
            }
        }

        for entry in schemaEntries {
            if entry.isOwned != (snapshot.schemaOwnership[entry.name] ?? entry.originallyOwned) {
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

        // Check extended properties
        for prop in extendedPropertyEntries {
            if prop.isNew || prop.isDeleted { return true }
            if prop.name != prop.originalName || prop.value != prop.originalValue { return true }
        }

        return false
    }

    // MARK: - Init

    init(connectionSessionID: UUID, databaseName: String, existingUserName: String?) {
        self.connectionSessionID = connectionSessionID
        self.databaseName = databaseName
        self.existingUserName = existingUserName
        if let existingUserName {
            self.userName = existingUserName
        }
    }

    // MARK: - Validation

    var isFormValid: Bool {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmitting else { return false }

        switch userType {
        case .mappedToLogin:
            return !loginName.isEmpty
        case .withPassword:
            if !isEditing {
                return !password.isEmpty && password == confirmPassword
            }
            return true
        case .withoutLogin:
            return true
        case .windowsUser:
            return !loginName.isEmpty
        case .mappedToCertificate:
            return !selectedCertificate.isEmpty
        case .mappedToAsymmetricKey:
            return !selectedAsymmetricKey.isEmpty
        }
    }

    // MARK: - Lazy Page Loading

    func ensurePageLoaded(_ page: UserEditorPage, session: ConnectionSession) async {
        switch page {
        case .general:
            break // Always loaded eagerly
        case .ownedSchemas:
            guard !hasLoadedSchemas else { return }
            await loadSchemas(session: session)
        case .membership:
            guard !hasLoadedRoles else { return }
            await loadRoles(session: session)
        case .securables:
            guard !hasLoadedSecurables else { return }
            await loadSecurables(session: session)
        case .extendedProperties:
            guard !hasLoadedExtendedProperties else { return }
            await loadExtendedProperties(session: session)
        }
    }
}
