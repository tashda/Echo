import Testing
@testable import Echo

@Suite("Server product label")
struct ServerProductLabelTests {
    @Test(arguments: [
        ("Microsoft SQL Server 16.0.4250.1", "SQL Server 2022"),
        ("Microsoft SQL Server 15.0.2000.5", "SQL Server 2019"),
        ("SQL Server 17.0.100.1", "SQL Server 2025"),
        ("Microsoft SQL Server 99.0.1.1", "SQL Server 99.0.1.1"),
    ])
    func sqlServerShowsItsReleaseYear(raw: String, label: String) {
        #expect(ServerProductLabel.label(rawVersion: raw, databaseType: .microsoftSQL) == label)
    }

    @Test func postgresShowsWhatItReports() {
        #expect(ServerProductLabel.label(rawVersion: "PostgreSQL 18.3", databaseType: .postgresql) == "PostgreSQL 18.3")
    }

    @Test func anUnknownVersionShowsTheProduct() {
        #expect(ServerProductLabel.label(rawVersion: nil, databaseType: .microsoftSQL) == "SQL Server")
        #expect(ServerProductLabel.label(rawVersion: " ", databaseType: .postgresql) == "PostgreSQL")
    }

    @Test func aNamedSQLServerVersionKeepsItsName() {
        #expect(ServerProductLabel.label(rawVersion: "Microsoft SQL Server", databaseType: .microsoftSQL) == "SQL Server")
    }
}
