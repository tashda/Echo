import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("NewExternalFileFormatSheet")
struct NewExternalFileFormatSheetTests {

    // MARK: - Validation

    @Test func cannotCreateWithEmptyName() {
        #expect(NewExternalFileFormatSheet.isCreateValid(name: "", isCreating: false) == false)
    }

    @Test func cannotCreateWithWhitespaceOnlyName() {
        #expect(NewExternalFileFormatSheet.isCreateValid(name: "   ", isCreating: false) == false)
    }

    @Test func cannotCreateWhileAlreadyCreating() {
        #expect(NewExternalFileFormatSheet.isCreateValid(name: "CsvFormat", isCreating: true) == false)
    }

    @Test func canCreateWithValidName() {
        #expect(NewExternalFileFormatSheet.isCreateValid(name: "CsvFormat", isCreating: false) == true)
    }

    @Test func canCreateTrimsWhitespace() {
        #expect(NewExternalFileFormatSheet.isCreateValid(name: "  CsvFormat  ", isCreating: false) == true)
    }
}
