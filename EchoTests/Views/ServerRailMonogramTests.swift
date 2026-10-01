import Testing
@testable import Echo

@Suite("Server Rail Monogram")
struct ServerRailMonogramTests {
    @Test func multiWordNamesUseTheFirstTwoInitials() {
        #expect(ServerRailMonogram.make(from: "postgres_services") == "PS")
        #expect(ServerRailMonogram.make(from: "prod-eu-pg01") == "PE")
        #expect(ServerRailMonogram.make(from: "Analytics Warehouse") == "AW")
    }

    @Test func numberedSingleWordsUseTheirTrailingDigits() {
        #expect(ServerRailMonogram.make(from: "postgres18") == "18")
        #expect(ServerRailMonogram.make(from: "sql2022") == "22")
    }

    @Test func singleTrailingDigitFallsBackToLetters() {
        #expect(ServerRailMonogram.make(from: "mysql8") == "MY")
    }

    @Test func numericHostsUseTheirLastComponent() {
        #expect(ServerRailMonogram.make(from: "192.168.1.20") == "20")
        #expect(ServerRailMonogram.make(from: "10.0.0.5") == "5")
    }

    @Test func plainWordsUseTheirFirstTwoLetters() {
        #expect(ServerRailMonogram.make(from: "localhost") == "LO")
    }

    @Test func emptyNamesShowAPlaceholder() {
        #expect(ServerRailMonogram.make(from: "") == "?")
        #expect(ServerRailMonogram.make(from: "  --  ") == "?")
    }
}
