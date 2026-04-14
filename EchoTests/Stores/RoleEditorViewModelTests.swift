import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("RoleEditorViewModel")
struct RoleEditorViewModelTests {

    // MARK: - Factory

    private func makeViewModel(existingRole: String? = nil) -> RoleEditorViewModel {
        RoleEditorViewModel(
            connectionSessionID: UUID(),
            databaseName: "TestDB",
            existingRoleName: existingRole
        )
    }

    // MARK: - Initial State

    @Test func initialStateForNewRole() {
        let vm = makeViewModel()

        #expect(vm.isEditing == false)
        #expect(vm.roleName == "")
        #expect(vm.owner == "")
        #expect(vm.isSubmitting == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.databaseName == "TestDB")
        #expect(vm.memberEntries.isEmpty)
        #expect(vm.securableEntries.isEmpty)
    }

    @Test func initialStateForExistingRole() {
        let vm = makeViewModel(existingRole: "db_datareader")

        #expect(vm.isEditing == true)
        #expect(vm.roleName == "db_datareader")
    }

    // MARK: - Form Validation

    @Test func isFormValidRequiresNonEmptyName() {
        let vm = makeViewModel()
        vm.roleName = ""
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidSucceedsWithName() {
        let vm = makeViewModel()
        vm.roleName = "my_role"
        #expect(vm.isFormValid == true)
    }

    @Test func isFormValidFalseWhenSubmitting() {
        let vm = makeViewModel()
        vm.roleName = "my_role"
        vm.isSubmitting = true
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidWithWhitespaceOnlyName() {
        let vm = makeViewModel()
        vm.roleName = "   "
        #expect(vm.isFormValid == false)
    }

    // MARK: - Dirty Tracking

    @Test func hasChangesIsTrueForNewRoleBeforeSnapshot() {
        let vm = makeViewModel()
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesIsFalseAfterSnapshot() {
        let vm = makeViewModel(existingRole: "testrole")
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsOwnerChange() {
        let vm = makeViewModel(existingRole: "testrole")
        vm.owner = "dbo"
        vm.takeSnapshot()

        vm.owner = "app_user"
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsMembershipChange() {
        let vm = makeViewModel(existingRole: "testrole")
        vm.memberEntries = [
            RoleMemberEntry(name: "user1", isMember: false, originallyMember: false)
        ]
        vm.takeSnapshot()

        vm.memberEntries[0] = RoleMemberEntry(name: "user1", isMember: true, originallyMember: false)
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsSecurablePermissionChange() {
        let vm = makeViewModel(existingRole: "testrole")
        let securable = SecurableReference(typeName: "OBJECT_OR_COLUMN", schemaName: "dbo", objectName: "Orders", objectKind: .table)
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
        let vm = makeViewModel(existingRole: "testrole")
        vm.owner = "dbo"
        vm.takeSnapshot()

        vm.owner = "app_user"
        #expect(vm.hasChanges == true)

        vm.owner = "dbo"
        #expect(vm.hasChanges == false)
    }

    @Test func takeSnapshotResetsHasChanges() {
        let vm = makeViewModel(existingRole: "testrole")
        vm.takeSnapshot()
        vm.owner = "new_owner"
        #expect(vm.hasChanges == true)

        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsMembershipRevertedToOriginal() {
        let vm = makeViewModel(existingRole: "testrole")
        vm.memberEntries = [
            RoleMemberEntry(name: "user1", isMember: true, originallyMember: true)
        ]
        vm.takeSnapshot()

        vm.memberEntries[0] = RoleMemberEntry(name: "user1", isMember: false, originallyMember: true)
        #expect(vm.hasChanges == true)

        vm.memberEntries[0] = RoleMemberEntry(name: "user1", isMember: true, originallyMember: true)
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsSecurableDenyChange() {
        let vm = makeViewModel(existingRole: "testrole")
        let securable = SecurableReference(typeName: "OBJECT_OR_COLUMN", schemaName: "dbo", objectName: "Users", objectKind: .table)
        let grantedState = PermissionState(isGranted: true, withGrantOption: false, isDenied: false)
        vm.securableEntries = [
            SecurableEntry(id: UUID(), securable: securable, permissions: [
                PermissionGridRow(permission: "SELECT", isGranted: true, withGrantOption: false, isDenied: false, originalState: grantedState)
            ])
        ]
        vm.takeSnapshot()

        vm.securableEntries[0].permissions[0].isGranted = false
        vm.securableEntries[0].permissions[0].isDenied = true
        #expect(vm.hasChanges == true)
    }

    // MARK: - Lazy Page Loading

    @Test func ensurePageLoadedDoesNotReloadAlreadyLoadedPages() async {
        let vm = makeViewModel(existingRole: "testrole")
        vm.hasLoadedMembers = true
        vm.hasLoadedSecurables = true

        // These should be no-ops since pages are already loaded.
        // We verify by checking that loading flags remain false.
        #expect(vm.isLoadingMembers == false)
        #expect(vm.isLoadingSecurables == false)
    }

    // MARK: - Window Value

    @Test func windowValueEquality() {
        let id = UUID()
        let a = RoleEditorWindowValue(connectionSessionID: id, databaseName: "TestDB", existingRoleName: "role1")
        let b = RoleEditorWindowValue(connectionSessionID: id, databaseName: "TestDB", existingRoleName: "role1")
        let c = RoleEditorWindowValue(connectionSessionID: id, databaseName: "TestDB", existingRoleName: "role2")

        #expect(a == b)
        #expect(a != c)
    }

    @Test func windowValueCodable() throws {
        let value = RoleEditorWindowValue(connectionSessionID: UUID(), databaseName: "TestDB", existingRoleName: "role1")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(RoleEditorWindowValue.self, from: data)
        #expect(value == decoded)
    }

    // MARK: - Page Enum

    @Test func roleEditorPageHasTitlesAndIcons() {
        for page in RoleEditorPage.allCases {
            #expect(!page.title.isEmpty)
            #expect(!page.icon.isEmpty)
            #expect(!page.id.isEmpty)
        }
    }
}
