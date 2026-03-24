import Testing
@testable import Echo

@Suite("DatabaseSecurityViewModel")
struct DatabaseSecurityViewModelTests {

    @Test("Section enum has all expected cases")
    func sectionEnumCases() {
        let allCases = DatabaseSecurityViewModel.Section.allCases
        #expect(allCases.count == 8)
        #expect(allCases.contains(.users))
        #expect(allCases.contains(.roles))
        #expect(allCases.contains(.appRoles))
        #expect(allCases.contains(.schemas))
        #expect(allCases.contains(.masking))
        #expect(allCases.contains(.securityPolicies))
        #expect(allCases.contains(.auditSpecifications))
        #expect(allCases.contains(.alwaysEncrypted))
    }

    @Test("Section raw values match display text")
    func sectionRawValues() {
        #expect(DatabaseSecurityViewModel.Section.users.rawValue == "Users")
        #expect(DatabaseSecurityViewModel.Section.roles.rawValue == "Roles")
        #expect(DatabaseSecurityViewModel.Section.appRoles.rawValue == "App Roles")
        #expect(DatabaseSecurityViewModel.Section.schemas.rawValue == "Schemas")
        #expect(DatabaseSecurityViewModel.Section.masking.rawValue == "Masking")
        #expect(DatabaseSecurityViewModel.Section.securityPolicies.rawValue == "RLS")
        #expect(DatabaseSecurityViewModel.Section.auditSpecifications.rawValue == "Audit Specs")
        #expect(DatabaseSecurityViewModel.Section.alwaysEncrypted.rawValue == "Encryption")
    }

    @Test("Initial state has empty collections")
    @MainActor
    func initialState() {
        let vm = DatabaseSecurityViewModel(
            session: MockDatabaseSession(),
            connectionID: .init(),
            connectionSessionID: .init(),
            initialDatabase: nil
        )
        #expect(vm.users.isEmpty)
        #expect(vm.roles.isEmpty)
        #expect(vm.appRoles.isEmpty)
        #expect(vm.schemas.isEmpty)
        #expect(vm.maskedColumns.isEmpty)
        #expect(vm.securityPolicies.isEmpty)
        #expect(vm.dbAuditSpecs.isEmpty)
        #expect(vm.columnMasterKeys.isEmpty)
        #expect(vm.columnEncryptionKeys.isEmpty)
        #expect(!vm.isInitialized)
    }

    @Test("Default selected section is users")
    @MainActor
    func defaultSection() {
        let vm = DatabaseSecurityViewModel(
            session: MockDatabaseSession(),
            connectionID: .init(),
            connectionSessionID: .init(),
            initialDatabase: "master"
        )
        #expect(vm.selectedSection == .users)
        #expect(vm.selectedDatabase == "master")
    }

    @Test("Section switching updates selectedSection")
    @MainActor
    func sectionSwitching() {
        let vm = DatabaseSecurityViewModel(
            session: MockDatabaseSession(),
            connectionID: .init(),
            connectionSessionID: .init(),
            initialDatabase: nil
        )
        vm.selectedSection = .masking
        #expect(vm.selectedSection == .masking)
        vm.selectedSection = .alwaysEncrypted
        #expect(vm.selectedSection == .alwaysEncrypted)
    }
}
