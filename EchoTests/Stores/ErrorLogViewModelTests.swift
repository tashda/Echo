import Testing
import Foundation
@testable import Echo
import SQLServerKit

@MainActor
@Suite("ErrorLogViewModel")
struct ErrorLogViewModelTests {

    // MARK: - Factory

    private func makeViewModel() -> ErrorLogViewModel {
        let session = MockDatabaseSession()
        return ErrorLogViewModel(
            session: session,
            connectionSessionID: UUID()
        )
    }

    // MARK: - Initial State

    @Test func initialStateIsEmpty() {
        let vm = makeViewModel()

        #expect(vm.logEntries.isEmpty)
        #expect(vm.archives.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.searchText == "")
        #expect(vm.selectedArchive == 0)
        #expect(vm.selectedProduct == .sqlServer)
    }

    // MARK: - Filtered Entries

    @Test func filteredEntriesReturnsAllWhenSearchTextEmpty() {
        let vm = makeViewModel()
        vm.logEntries = [
            SQLServerErrorLogEntry(logDate: "2026-01-01", processInfo: "spid42", text: "Server started"),
            SQLServerErrorLogEntry(logDate: "2026-01-02", processInfo: "spid43", text: "Backup completed"),
        ]
        vm.searchText = ""

        #expect(vm.filteredEntries.count == 2)
    }

    @Test func filteredEntriesFiltersByTextContent() {
        let vm = makeViewModel()
        vm.logEntries = [
            SQLServerErrorLogEntry(logDate: "2026-01-01", processInfo: "spid42", text: "Server started"),
            SQLServerErrorLogEntry(logDate: "2026-01-02", processInfo: "spid43", text: "Backup completed"),
            SQLServerErrorLogEntry(logDate: "2026-01-03", processInfo: "spid44", text: "Error detected"),
        ]
        vm.searchText = "Backup"

        #expect(vm.filteredEntries.count == 1)
        #expect(vm.filteredEntries.first?.text == "Backup completed")
    }

    @Test func filteredEntriesFiltersByProcessInfo() {
        let vm = makeViewModel()
        vm.logEntries = [
            SQLServerErrorLogEntry(logDate: "2026-01-01", processInfo: "spid42", text: "Server started"),
            SQLServerErrorLogEntry(logDate: "2026-01-02", processInfo: "Logon", text: "Login succeeded"),
            SQLServerErrorLogEntry(logDate: "2026-01-03", processInfo: "spid44", text: "Error detected"),
        ]
        vm.searchText = "Logon"

        #expect(vm.filteredEntries.count == 1)
        #expect(vm.filteredEntries.first?.processInfo == "Logon")
    }

    @Test func filteredEntriesIsCaseInsensitive() {
        let vm = makeViewModel()
        vm.logEntries = [
            SQLServerErrorLogEntry(logDate: "2026-01-01", processInfo: "spid42", text: "Server STARTED"),
            SQLServerErrorLogEntry(logDate: "2026-01-02", processInfo: "spid43", text: "Backup completed"),
        ]
        vm.searchText = "server started"

        #expect(vm.filteredEntries.count == 1)
        #expect(vm.filteredEntries.first?.text == "Server STARTED")
    }

    @Test func filteredEntriesReturnsEmptyWhenNoMatch() {
        let vm = makeViewModel()
        vm.logEntries = [
            SQLServerErrorLogEntry(logDate: "2026-01-01", processInfo: "spid42", text: "Server started"),
            SQLServerErrorLogEntry(logDate: "2026-01-02", processInfo: "spid43", text: "Backup completed"),
        ]
        vm.searchText = "nonexistent"

        #expect(vm.filteredEntries.isEmpty)
    }

    @Test func filteredEntriesFiltersByLogDate() {
        let vm = makeViewModel()
        vm.logEntries = [
            SQLServerErrorLogEntry(logDate: "2026-01-01 10:00:00", processInfo: "spid42", text: "Server started"),
            SQLServerErrorLogEntry(logDate: "2026-03-15 14:30:00", processInfo: "spid43", text: "Backup completed"),
        ]
        vm.searchText = "03-15"

        #expect(vm.filteredEntries.count == 1)
        #expect(vm.filteredEntries.first?.text == "Backup completed")
    }

    // MARK: - LogProduct Enum

    @Test func logProductHasExpectedCases() {
        let allCases = ErrorLogViewModel.LogProduct.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.sqlServer))
        #expect(allCases.contains(.agent))
    }

    @Test func logProductRawValues() {
        #expect(ErrorLogViewModel.LogProduct.sqlServer.rawValue == "SQL Server")
        #expect(ErrorLogViewModel.LogProduct.agent.rawValue == "SQL Agent")
    }

    @Test func logProductNioMappingSqlServer() {
        let product = ErrorLogViewModel.LogProduct.sqlServer
        #expect(product.nioProduct == .sqlServer)
    }

    @Test func logProductNioMappingAgent() {
        let product = ErrorLogViewModel.LogProduct.agent
        #expect(product.nioProduct == .agent)
    }

    @Test func logProductIdentifiable() {
        let sqlServer = ErrorLogViewModel.LogProduct.sqlServer
        let agent = ErrorLogViewModel.LogProduct.agent
        #expect(sqlServer.id == "SQL Server")
        #expect(agent.id == "SQL Agent")
        #expect(sqlServer.id != agent.id)
    }
}
