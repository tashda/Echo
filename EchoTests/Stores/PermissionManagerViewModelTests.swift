import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("PermissionManagerViewModel")
struct PermissionManagerViewModelTests {

    // MARK: - Factory

    private func makeViewModel(principalName: String? = nil) -> PermissionManagerViewModel {
        PermissionManagerViewModel(
            connectionSessionID: UUID(),
            databaseName: "TestDB",
            principalName: principalName
        )
    }

    // MARK: - Initial State

    @Test func initialStateWithNoPrincipal() {
        let vm = makeViewModel()

        #expect(vm.selectedPrincipalName == "")
        #expect(vm.databaseName == "TestDB")
        #expect(vm.initialPrincipalName == nil)
        #expect(vm.principals.isEmpty)
        #expect(vm.securableEntries.isEmpty)
        #expect(vm.effectivePermissions.isEmpty)
        #expect(vm.isLoadingPrincipals == true)
        #expect(vm.isLoadingSecurables == false)
        #expect(vm.isSubmitting == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.didComplete == false)
    }

    @Test func initialStateWithPrincipal() {
        let vm = makeViewModel(principalName: "dbo")

        #expect(vm.selectedPrincipalName == "dbo")
        #expect(vm.initialPrincipalName == "dbo")
    }

    // MARK: - Form Validation

    @Test func isFormValidRequiresSelectedPrincipal() {
        let vm = makeViewModel()
        #expect(vm.isFormValid == false)
    }

    @Test func isFormValidSucceedsWithPrincipal() {
        let vm = makeViewModel(principalName: "testuser")
        #expect(vm.isFormValid == true)
    }

    @Test func isFormValidFalseWhenSubmitting() {
        let vm = makeViewModel(principalName: "testuser")
        vm.isSubmitting = true
        #expect(vm.isFormValid == false)
    }

    // MARK: - Pages

    @Test func pagesIncludesBothPages() {
        let vm = makeViewModel()
        let pages = vm.pages

        #expect(pages.count == 2)
        #expect(pages.contains(.securables))
        #expect(pages.contains(.effectivePermissions))
    }

    // MARK: - Dirty Tracking

    @Test func hasChangesInitiallyFalse() {
        let vm = makeViewModel()
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    @Test func hasChangesDetectsPermissionChange() {
        let vm = makeViewModel()

        let entry = SecurableEntry(
            id: UUID(),
            securable: SecurableReference(
                typeName: "Table",
                schemaName: "dbo",
                objectName: "TestTable",
                objectKind: .table
            ),
            permissions: [
                PermissionGridRow(
                    permission: "SELECT",
                    isGranted: false,
                    withGrantOption: false,
                    isDenied: false,
                    originalState: .none
                )
            ]
        )
        vm.securableEntries = [entry]
        vm.takeSnapshot()

        #expect(vm.hasChanges == false)

        // Grant the permission
        vm.securableEntries[0].permissions[0].isGranted = true
        #expect(vm.hasChanges == true)
    }

    @Test func hasChangesDetectsDenyChange() {
        let vm = makeViewModel()

        let entry = SecurableEntry(
            id: UUID(),
            securable: SecurableReference(
                typeName: "Table",
                schemaName: "dbo",
                objectName: "TestTable",
                objectKind: .table
            ),
            permissions: [
                PermissionGridRow(
                    permission: "INSERT",
                    isGranted: false,
                    withGrantOption: false,
                    isDenied: false,
                    originalState: .none
                )
            ]
        )
        vm.securableEntries = [entry]
        vm.takeSnapshot()

        vm.securableEntries[0].permissions[0].isDenied = true
        #expect(vm.hasChanges == true)
    }

    @Test func snapshotResetsHasChanges() {
        let vm = makeViewModel()

        let entry = SecurableEntry(
            id: UUID(),
            securable: SecurableReference(
                typeName: "Schema",
                schemaName: nil,
                objectName: "dbo",
                objectKind: nil
            ),
            permissions: [
                PermissionGridRow(
                    permission: "ALTER",
                    isGranted: true,
                    withGrantOption: false,
                    isDenied: false,
                    originalState: PermissionState(isGranted: true, withGrantOption: false, isDenied: false)
                )
            ]
        )
        vm.securableEntries = [entry]
        vm.takeSnapshot()

        #expect(vm.hasChanges == false)

        vm.securableEntries[0].permissions[0].isGranted = false
        #expect(vm.hasChanges == true)

        // Take new snapshot after "saving"
        vm.takeSnapshot()
        #expect(vm.hasChanges == false)
    }

    // MARK: - Applicable Permissions

    @Test func applicablePermissionsForObject() {
        let vm = makeViewModel()
        let perms = vm.applicablePermissions(for: "OBJECT_OR_COLUMN")

        #expect(perms.contains("SELECT"))
        #expect(perms.contains("INSERT"))
        #expect(perms.contains("UPDATE"))
        #expect(perms.contains("DELETE"))
        #expect(perms.contains("EXECUTE"))
        #expect(perms.contains("ALTER"))
        #expect(perms.contains("CONTROL"))
    }

    @Test func applicablePermissionsForSchema() {
        let vm = makeViewModel()
        let perms = vm.applicablePermissions(for: "SCHEMA")

        #expect(perms.contains("ALTER"))
        #expect(perms.contains("CONTROL"))
        #expect(perms.contains("CREATE TABLE"))
        #expect(!perms.contains("SELECT"))
    }

    @Test func applicablePermissionsForDatabase() {
        let vm = makeViewModel()
        let perms = vm.applicablePermissions(for: "DATABASE")

        #expect(perms.contains("ALTER"))
        #expect(perms.contains("BACKUP DATABASE"))
        #expect(perms.contains("CONNECT"))
        #expect(perms.contains("VIEW DATABASE STATE"))
    }
}

// MARK: - PermissionManagerPage

@Suite("PermissionManagerPage")
struct PermissionManagerPageTests {

    @Test func allCases() {
        let pages = PermissionManagerPage.allCases
        #expect(pages.count == 2)
    }

    @Test func titles() {
        #expect(PermissionManagerPage.securables.title == "Securables")
        #expect(PermissionManagerPage.effectivePermissions.title == "Effective Permissions")
    }

    @Test func icons() {
        #expect(PermissionManagerPage.securables.icon == "lock.shield")
        #expect(PermissionManagerPage.effectivePermissions.icon == "checklist")
    }
}

// MARK: - PermissionManagerWindowValue

@Suite("PermissionManagerWindowValue")
struct PermissionManagerWindowValueTests {

    @Test func codableRoundTrip() throws {
        let sessionID = UUID()
        let value = PermissionManagerWindowValue(
            connectionSessionID: sessionID,
            databaseName: "AdventureWorks",
            principalName: "dbo"
        )
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(PermissionManagerWindowValue.self, from: data)

        #expect(decoded.connectionSessionID == sessionID)
        #expect(decoded.databaseName == "AdventureWorks")
        #expect(decoded.principalName == "dbo")
    }

    @Test func hashableEquality() {
        let id = UUID()
        let a = PermissionManagerWindowValue(connectionSessionID: id, databaseName: "DB1", principalName: "user1")
        let b = PermissionManagerWindowValue(connectionSessionID: id, databaseName: "DB1", principalName: "user1")
        let c = PermissionManagerWindowValue(connectionSessionID: id, databaseName: "DB1", principalName: "user2")

        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - PrincipalChoice

@Suite("PrincipalChoice")
struct PrincipalChoiceTests {

    @Test func displayTypeForSQLUser() {
        let choice = PrincipalChoice(name: "testuser", type: "S", isFixed: false)
        #expect(choice.displayType == "SQL User")
    }

    @Test func displayTypeForRole() {
        let choice = PrincipalChoice(name: "db_owner", type: "R", isFixed: true)
        #expect(choice.displayType == "Database Role")
        #expect(choice.isFixed == true)
    }

    @Test func displayTypeForAppRole() {
        let choice = PrincipalChoice(name: "app1", type: "A", isFixed: false)
        #expect(choice.displayType == "Application Role")
    }

    @Test func identifiable() {
        let choice = PrincipalChoice(name: "testuser", type: "S", isFixed: false)
        #expect(choice.id == "S:testuser")
    }
}

// MARK: - EffectivePermissionRow

@Suite("EffectivePermissionRow")
struct EffectivePermissionRowTests {

    @Test func identifiable() {
        let row = EffectivePermissionRow(
            permission: "SELECT",
            securableClass: "Object",
            securableName: "dbo.Users",
            grantor: "dbo",
            state: "GRANT"
        )
        #expect(row.id == "Object.dbo.Users.SELECT")
    }

    @Test func hashableEquality() {
        let a = EffectivePermissionRow(
            permission: "INSERT",
            securableClass: "Object",
            securableName: "dbo.Orders",
            grantor: "dbo",
            state: "DENY"
        )
        let b = EffectivePermissionRow(
            permission: "INSERT",
            securableClass: "Object",
            securableName: "dbo.Orders",
            grantor: "dbo",
            state: "DENY"
        )
        #expect(a == b)
    }
}
