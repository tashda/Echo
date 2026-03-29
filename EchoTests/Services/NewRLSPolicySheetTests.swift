import Testing
import Foundation
@testable import Echo

@Suite("NewRLSPolicySheet.PredicateEntry")
struct NewRLSPolicyPredicateEntryTests {

    // MARK: - Validation

    @Test func validEntryWithAllFields() {
        var entry = NewRLSPolicySheet.PredicateEntry()
        entry.functionName = "fn_security"
        entry.targetTable = "Employees"

        #expect(entry.isValid == true)
    }

    @Test func invalidEntryWithEmptyFunction() {
        var entry = NewRLSPolicySheet.PredicateEntry()
        entry.functionName = ""
        entry.targetTable = "Employees"

        #expect(entry.isValid == false)
    }

    @Test func invalidEntryWithEmptyTable() {
        var entry = NewRLSPolicySheet.PredicateEntry()
        entry.functionName = "fn_security"
        entry.targetTable = ""

        #expect(entry.isValid == false)
    }

    @Test func invalidEntryWithWhitespaceOnly() {
        var entry = NewRLSPolicySheet.PredicateEntry()
        entry.functionName = "   "
        entry.targetTable = "   "

        #expect(entry.isValid == false)
    }

    // MARK: - Defaults

    @Test func defaultPredicateType() {
        let entry = NewRLSPolicySheet.PredicateEntry()

        #expect(entry.predicateType == .filter)
        #expect(entry.functionSchema == "dbo")
        #expect(entry.targetSchema == "dbo")
        #expect(entry.functionName == "")
        #expect(entry.targetTable == "")
    }

    // MARK: - Identifiable

    @Test func eachEntryHasUniqueID() {
        let a = NewRLSPolicySheet.PredicateEntry()
        let b = NewRLSPolicySheet.PredicateEntry()

        #expect(a.id != b.id)
    }
}
