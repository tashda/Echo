import Foundation
import Testing
@testable import Echo

@Suite("Pasting a connection string")
struct ConnectionStringParserTests {
    @Test func postgresURLFillsEverything() throws {
        let result = try #require(ConnectionStringParser.parse("postgres://echo_app:s%40cret@db.example.com:6543/sales"))
        #expect(result == .init(databaseType: .postgresql, host: "db.example.com", port: 6543, database: "sales", username: "echo_app", password: "s@cret"))
    }

    @Test func postgresqlSchemeWithoutPortOrUser() throws {
        let result = try #require(ConnectionStringParser.parse("postgresql://localhost/postgres"))
        #expect(result.databaseType == .postgresql)
        #expect(result.host == "localhost")
        #expect(result.port == nil)
        #expect(result.database == "postgres")
        #expect(result.username == nil)
    }

    @Test func jdbcMySQLURL() throws {
        let result = try #require(ConnectionStringParser.parse("jdbc:mysql://shop_ro@db.internal:3306/shop?useSSL=true"))
        #expect(result.databaseType == .mysql)
        #expect(result.host == "db.internal")
        #expect(result.port == 3306)
        #expect(result.database == "shop")
        #expect(result.username == "shop_ro")
    }

    @Test func sqlServerJDBCStyleURL() throws {
        let result = try #require(ConnectionStringParser.parse("sqlserver://192.0.2.34:14332;databaseName=AdventureWorks2022;user=sa;password=pw"))
        #expect(result == .init(databaseType: .microsoftSQL, host: "192.0.2.34", port: 14332, database: "AdventureWorks2022", username: "sa", password: "pw"))
    }

    @Test func adoNetConnectionString() throws {
        let result = try #require(ConnectionStringParser.parse("Server=tcp:prod-sql-01.contoso.com,1433;Initial Catalog=Sales;User ID=echo_app;Password=pw;Encrypt=True;"))
        #expect(result == .init(databaseType: .microsoftSQL, host: "prod-sql-01.contoso.com", port: 1433, database: "Sales", username: "echo_app", password: "pw"))
    }

    @Test func dataSourceWithoutPort() throws {
        let result = try #require(ConnectionStringParser.parse("Data Source=localhost;Database=master;Uid=sa;Pwd=pw"))
        #expect(result.host == "localhost")
        #expect(result.port == nil)
        #expect(result.database == "master")
        #expect(result.username == "sa")
    }

    @Test func sqliteFileURL() throws {
        let result = try #require(ConnectionStringParser.parse("sqlite:///Users/k/Data/app%20data.sqlite"))
        #expect(result.databaseType == .sqlite)
        #expect(result.host == "/Users/k/Data/app data.sqlite")
    }

    @Test(arguments: ["localhost", "db.example.com", "192.168.1.10", "", "ftp://example.com", "just some text"])
    func plainHostsAndOtherTextAreLeftAlone(text: String) {
        #expect(ConnectionStringParser.parse(text) == nil)
    }
}
