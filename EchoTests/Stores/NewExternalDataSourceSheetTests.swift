import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewExternalDataSourceSheet")
struct NewExternalDataSourceSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewExternalDataSourceSheet.isCreateValid(name: "", location: "wasbs://container@account.blob.core.windows.net", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewExternalDataSourceSheet.isCreateValid(name: "   ", location: "wasbs://container@account.blob.core.windows.net", isCreating: false) == false)
    }

    @Test func cannotCreateWithEmptyLocation() {
        #expect(NewExternalDataSourceSheet.isCreateValid(name: "MyDataSource", location: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyLocation() {
        #expect(NewExternalDataSourceSheet.isCreateValid(name: "MyDataSource", location: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewExternalDataSourceSheet.isCreateValid(name: "MyDataSource", location: "wasbs://container@account.blob.core.windows.net", isCreating: true) == false)
    }

    @Test func canCreateWithValidInputs() {
        #expect(NewExternalDataSourceSheet.isCreateValid(name: "MyDataSource", location: "wasbs://container@account.blob.core.windows.net", isCreating: false) == true)
    }
}
