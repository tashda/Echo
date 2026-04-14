import Testing
@testable import Echo

@Suite("MySQLServerConfigurationLocator")
struct MySQLServerConfigurationLocatorTests {
    @Test
    func localhostIncludesStandardAndDerivedCandidates() {
        let candidates = MySQLServerConfigurationLocator.candidates(
            host: "localhost",
            baseDirectory: "/usr/local/mysql",
            dataDirectory: "/usr/local/mysql/data"
        )

        #expect(candidates.contains { $0.path == "/etc/my.cnf" })
        #expect(candidates.contains { $0.path == "/opt/homebrew/etc/my.cnf" })
        #expect(candidates.contains { $0.path == "/usr/local/mysql/my.cnf" })
        #expect(candidates.contains { $0.path == "/usr/local/mysql/support-files/my-default.cnf" })
        #expect(candidates.contains { $0.path == "/usr/local/mysql/my.cnf" })
    }

    @Test
    func remoteHostSkipsGenericLocalCandidates() {
        let candidates = MySQLServerConfigurationLocator.candidates(
            host: "db.internal.example",
            baseDirectory: "/opt/mysql",
            dataDirectory: "/opt/mysql/data"
        )

        #expect(!candidates.contains { $0.path == "/etc/my.cnf" })
        #expect(!candidates.contains { $0.path == "/opt/homebrew/etc/my.cnf" })
        #expect(candidates.contains { $0.path == "/opt/mysql/my.cnf" })
    }

    @Test
    func duplicatePathsAreCollapsed() {
        let candidates = MySQLServerConfigurationLocator.candidates(
            host: "localhost",
            baseDirectory: "/usr/local",
            dataDirectory: "/usr/local/data"
        )

        let matching = candidates.filter { $0.path == "/usr/local/my.cnf" }
        #expect(matching.count == 1)
    }
}
