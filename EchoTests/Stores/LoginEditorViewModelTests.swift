import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("LoginEditorViewModel")
struct LoginEditorViewModelTests {

    // MARK: - Factory

    private func makeViewModel(existingLogin: String? = nil) -> LoginEditorViewModel {
        LoginEditorViewModel(
            connectionSessionID: UUID(),
            existingLoginName: existingLogin
        )
    }

    // MARK: - Initial State

    @Test func initialStateForNewLogin() {
        let vm = makeViewModel()

        #expect(vm.isEditing == false)
        #expect(vm.loginName == "")
        #expect(vm.password == "")
        #expect(vm.defaultDatabase == "master")
        #expect(vm.enforcePasswordPolicy == true)
        #expect(vm.enforcePasswordExpiration == false)
        #expect(vm.loginEnabled == true)
        #expect(vm.authType == .sql)
        #expect(vm.isSubmitting == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.didComplete == false)
    }

    @Test func initialStateForExistingLogin() {
        let vm = makeViewModel(existingLogin: "sa")

        #expect(vm.isEditing == true)
        #expect(vm.loginName == "sa")
    }

    // MARK: - Form Validation

    @Test func isFormValidRequiresNonEmptyName() {
        let vm = makeViewModel()
        vm.loginName = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidRequiresPasswordForNewSqlLogin() {
        let vm = makeViewModel()
        vm.loginName = "newlogin"
        vm.authType = .sql
        vm.password = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidRequiresMatchingPasswords() {
        let vm = makeViewModel()
        vm.loginName = "newlogin"
        vm.authType = .sql
        vm.password = "pass1"
        vm.confirmPassword = "pass2"
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidSucceedsWithMatchingPasswords() {
        let vm = makeViewModel()
        vm.loginName = "newlogin"
        vm.authType = .sql
        vm.password = "pass1"
        vm.confirmPassword = "pass1"
        #expect(vm.isFormValid == true)
    }

    @Test func isFormValidDoesNotRequirePasswordForEditMode() {
        let vm = makeViewModel(existingLogin: "existing")
        vm.password = ""
        #expect(vm.isFormValid == true)
    }

    @Test func isFormValidFalseWhenSubmitting() {
        let vm = makeViewModel(existingLogin: "existing")
        vm.isSubmitting = true
        #expect(vm.isFormValid == false)
    }

    // MARK: - Pages

    @Test func pagesForNewLoginExcludesUserMappingAndSecurables() {
        let vm = makeViewModel()
        let pages = vm.pages
        #expect(pages.contains(.general))
        #expect(pages.contains(.serverRoles))
        #expect(!pages.contains(.userMapping))
        #expect(!pages.contains(.securables))
    }

    @Test func pagesForExistingLoginIncludesAll() {
        let vm = makeViewModel(existingLogin: "sa")
        let pages = vm.pages
        #expect(pages.contains(.general))
        #expect(pages.contains(.serverRoles))
        #expect(pages.contains(.userMapping))
        #expect(pages.contains(.securables))
    }

    // MARK: - Dirty Tracking

    @Test func hasChangesIsTrueForNewLoginBeforeSnapshot() {
        let vm = makeViewModel()
        // No snapshot yet, new login → hasChanges should be true (so Save is enabled for new logins)
        // Actually for new logins without snapshot: !isEditing = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesIsFalseForExistingLoginAfterSnapshot() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsPasswordChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.takeSnapshot()

        vm.password = "newpassword"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsLoginEnabledChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.loginEnabled = true
        vm.takeSnapshot()

        vm.loginEnabled = false
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsDefaultDatabaseChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.defaultDatabase = "master"
        vm.takeSnapshot()

        vm.defaultDatabase = "tempdb"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsDefaultLanguageChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.defaultLanguage = ""
        vm.takeSnapshot()

        vm.defaultLanguage = "French"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsPasswordPolicyChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.enforcePasswordPolicy = true
        vm.takeSnapshot()

        vm.enforcePasswordPolicy = false
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsPasswordExpirationChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.enforcePasswordExpiration = false
        vm.takeSnapshot()

        vm.enforcePasswordExpiration = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsRoleMembershipChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.roleEntries = [
            LoginEditorRoleEntry(name: "sysadmin", isFixed: true, isMember: false, originallyMember: false),
            LoginEditorRoleEntry(name: "public", isFixed: true, isMember: true, originallyMember: true),
        ]
        vm.takeSnapshot()

        // Toggle sysadmin membership
        vm.roleEntries[0] = LoginEditorRoleEntry(name: "sysadmin", isFixed: true, isMember: true, originallyMember: false)
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsPermissionChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.serverPermissions = [
            LoginEditorPermissionEntry(
                permission: "VIEW SERVER STATE",
                isGranted: false, withGrantOption: false, isDenied: false,
                originalState: .none
            )
        ]
        vm.takeSnapshot()

        vm.serverPermissions[0].isGranted = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesIsFalseWhenRevertedToOriginal() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.defaultDatabase = "master"
        vm.takeSnapshot()

        vm.defaultDatabase = "tempdb"
        #expect(vm.hasChanges == true)

        vm.defaultDatabase = "master"
        #expect(vm.hasChanges == false)
    }

    @Test func takeSnapshotResetsHasChanges() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.defaultDatabase = "master"
        vm.takeSnapshot()

        vm.defaultDatabase = "tempdb"
        #expect(vm.hasChanges == true)

        // Taking a new snapshot captures current state as baseline
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    // MARK: - User Mapping (Local Toggle)

    @Test func toggleMappingOnSetsIsMapped() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.mappingEntries = [
            LoginEditorMappingEntry(databaseName: "mydb", isMapped: false, originallyMapped: false, userName: nil, defaultSchema: nil)
        ]
        vm.takeSnapshot()

        vm.toggleMapping(database: "mydb", isMapped: true)
        #expect(vm.mappingEntries[0].isMapped == true)
        #expect(vm.mappingEntries[0].userName == "testlogin")
        #expect(vm.mappingEntries[0].defaultSchema == "dbo")
        #expect(vm.hasChanges == true)
    }

    @Test func toggleMappingOffSetsIsMappedFalse() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.mappingEntries = [
            LoginEditorMappingEntry(databaseName: "mydb", isMapped: true, originallyMapped: true, userName: "testlogin", defaultSchema: "dbo")
        ]
        vm.takeSnapshot()

        vm.toggleMapping(database: "mydb", isMapped: false)
        #expect(vm.mappingEntries[0].isMapped == false)
        #expect(vm.hasChanges == true)
    }

    @Test func toggleMappingRevertHasNoChanges() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.mappingEntries = [
            LoginEditorMappingEntry(databaseName: "mydb", isMapped: false, originallyMapped: false, userName: nil, defaultSchema: nil)
        ]
        vm.takeSnapshot()

        vm.toggleMapping(database: "mydb", isMapped: true)
        #expect(vm.hasChanges == true)

        vm.toggleMapping(database: "mydb", isMapped: false)
        #expect(vm.hasChanges == false)
    }

    @Test func toggleDatabaseRoleLocallySetsIsMember() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.selectedMappingDatabase = "mydb"
        vm.databaseRolesPerDB["mydb"] = [
            LoginEditorDBRoleEntry(roleName: "db_datareader", isMember: false, originallyMember: false)
        ]
        vm.takeSnapshot()

        vm.toggleDatabaseRoleLocally(database: "mydb", roleName: "db_datareader", isMember: true)
        #expect(vm.databaseRolesPerDB["mydb"]?[0].isMember == true)
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsMappingChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.mappingEntries = [
            LoginEditorMappingEntry(databaseName: "db1", isMapped: true, originallyMapped: true, userName: "u1", defaultSchema: "dbo"),
            LoginEditorMappingEntry(databaseName: "db2", isMapped: false, originallyMapped: false, userName: nil, defaultSchema: nil),
        ]
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)

        vm.toggleMapping(database: "db2", isMapped: true)
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsDatabaseRoleChange() {
        let vm = makeViewModel(existingLogin: "testlogin")
        vm.databaseRolesPerDB["mydb"] = [
            LoginEditorDBRoleEntry(roleName: "db_owner", isMember: true, originallyMember: true),
            LoginEditorDBRoleEntry(roleName: "db_datareader", isMember: false, originallyMember: false),
        ]
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)

        vm.toggleDatabaseRoleLocally(database: "mydb", roleName: "db_datareader", isMember: true)
        #expect(vm.hasChanges == true)
    }
}
