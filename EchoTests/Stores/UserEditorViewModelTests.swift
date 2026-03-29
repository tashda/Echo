import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("UserEditorViewModel")
struct UserEditorViewModelTests {

    // MARK: - Factory

    private func makeViewModel(existingUser: String? = nil) -> UserEditorViewModel {
        UserEditorViewModel(
            connectionSessionID: UUID(),
            databaseName: "TestDB",
            existingUserName: existingUser
        )
    }

    // MARK: - Initial State

    @Test func initialStateForNewUser() {
        let vm = makeViewModel()

        #expect(vm.isEditing == false)
        #expect(vm.userName == "")
        #expect(vm.userType == .mappedToLogin)
        #expect(vm.loginName == "")
        #expect(vm.defaultSchema == "dbo")
        #expect(vm.isSubmitting == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.databaseName == "TestDB")
    }

    @Test func initialStateForExistingUser() {
        let vm = makeViewModel(existingUser: "app_user")

        #expect(vm.isEditing == true)
        #expect(vm.userName == "app_user")
    }

    // MARK: - Form Validation

    @Test func isFormValidRequiresNonEmptyName() {
        let vm = makeViewModel()
        vm.userName = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidRequiresLoginNameForMappedToLogin() {
        let vm = makeViewModel()
        vm.userName = "testuser"
        vm.userType = .mappedToLogin
        vm.loginName = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidSucceedsForMappedToLoginWithLogin() {
        let vm = makeViewModel()
        vm.userName = "testuser"
        vm.userType = .mappedToLogin
        vm.loginName = "testlogin"
        #expect(vm.isFormValid == true)
    }

    @Test func isFormValidRequiresPasswordForWithPassword() {
        let vm = makeViewModel()
        vm.userName = "testuser"
        vm.userType = .withPassword
        vm.password = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidSucceedsForWithoutLogin() {
        let vm = makeViewModel()
        vm.userName = "testuser"
        vm.userType = .withoutLogin
        #expect(vm.isFormValid == true)
    }

    @Test func isFormValidRequiresCertificateForMappedToCertificate() {
        let vm = makeViewModel()
        vm.userName = "testuser"
        vm.userType = .mappedToCertificate
        vm.selectedCertificate = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidRequiresKeyForMappedToAsymmetricKey() {
        let vm = makeViewModel()
        vm.userName = "testuser"
        vm.userType = .mappedToAsymmetricKey
        vm.selectedAsymmetricKey = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidFalseWhenSubmitting() {
        let vm = makeViewModel()
        vm.userName = "testuser"
        vm.userType = .withoutLogin
        vm.isSubmitting = true
        #expect(vm.isFormValid == false)
    }

    // MARK: - Dirty Tracking

    @Test func hasChangesIsTrueForNewUserBeforeSnapshot() {
        let vm = makeViewModel()
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesIsFalseAfterSnapshot() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsSchemaChange() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.defaultSchema = "dbo"
        vm.takeSnapshot()

        vm.defaultSchema = "sales"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsUserTypeChange() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.userType = .mappedToLogin
        vm.takeSnapshot()

        vm.userType = .withoutLogin
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsLoginNameChange() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.loginName = "oldlogin"
        vm.takeSnapshot()

        vm.loginName = "newlogin"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsPasswordChange() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.takeSnapshot()

        vm.password = "newpassword"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsRoleMembershipChange() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.roleEntries = [
            UserEditorRoleMemberEntry(name: "db_datareader", isFixed: true, isMember: false, originallyMember: false)
        ]
        vm.takeSnapshot()

        vm.roleEntries[0] = UserEditorRoleMemberEntry(name: "db_datareader", isFixed: true, isMember: true, originallyMember: false)
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsSchemaOwnershipChange() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.schemaEntries = [
            SchemaOwnerEntry(name: "sales", currentOwner: nil, isOwned: false, originallyOwned: false)
        ]
        vm.takeSnapshot()

        vm.schemaEntries[0] = SchemaOwnerEntry(name: "sales", currentOwner: nil, isOwned: true, originallyOwned: false)
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsNewExtendedProperty() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.takeSnapshot()

        vm.extendedPropertyEntries.append(
            ExtendedPropertyEntry(id: UUID(), name: "Description", value: "Test", isNew: true, originalName: nil, originalValue: nil)
        )
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsDeletedExtendedProperty() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.extendedPropertyEntries = [
            ExtendedPropertyEntry(id: UUID(), name: "Description", value: "Test", isNew: false, originalName: "Description", originalValue: "Test")
        ]
        vm.takeSnapshot()

        vm.extendedPropertyEntries[0].isDeleted = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsSecurablePermissionChange() {
        let vm = makeViewModel(existingUser: "testuser")
        let securable = SecurableReference(typeName: "OBJECT_OR_COLUMN", schemaName: "dbo", objectName: "Users", objectKind: .table)
        vm.securableEntries = [
            SecurableEntry(id: UUID(), securable: securable, permissions: [
                PermissionGridRow(permission: "SELECT", isGranted: false, withGrantOption: false, isDenied: false, originalState: .none)
            ])
        ]
        vm.takeSnapshot()

        vm.securableEntries[0].permissions[0].isGranted = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesIsFalseWhenRevertedToOriginal() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.defaultSchema = "dbo"
        vm.takeSnapshot()

        vm.defaultSchema = "sales"
        #expect(vm.hasChanges == true)

        vm.defaultSchema = "dbo"
        #expect(vm.hasChanges == false)
    }

    @Test func takeSnapshotResetsHasChanges() {
        let vm = makeViewModel(existingUser: "testuser")
        vm.takeSnapshot()
        vm.defaultSchema = "new_schema"
        #expect(vm.hasChanges == true)

        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }
}
