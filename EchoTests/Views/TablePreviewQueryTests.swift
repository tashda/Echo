import EchoSense
import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Table preview query")
struct TablePreviewQueryTests {
    @Test(arguments: [
        (DatabaseType.microsoftSQL, "SELECT TOP 1000 * FROM [dbo].[Order]]s];"),
        (DatabaseType.postgresql, "SELECT * FROM \"dbo\".\"Order]s\" LIMIT 1000;"),
        (DatabaseType.mysql, "SELECT * FROM `dbo`.`Order]s` LIMIT 1000;"),
        (DatabaseType.sqlite, "SELECT * FROM \"Order]s\" LIMIT 1000;"),
    ])
    func quotesTheTableForEachDatabase(type: DatabaseType, expected: String) {
        #expect(TablePreviewQuery.sql(schema: "dbo", table: "Order]s", databaseType: type) == expected)
    }

    @Test func escapesQuotesInsideNames() {
        #expect(TablePreviewQuery.qualifiedName(schema: "a\"b", table: "c", databaseType: DatabaseType.postgresql) == "\"a\"\"b\".\"c\"")
        #expect(TablePreviewQuery.qualifiedName(schema: "a`b", table: "c", databaseType: DatabaseType.mysql) == "`a``b`.`c`")
    }

    @Test func promptMentionsTablesOnlyWhenThereAreSome() {
        #expect(EmptyQueryHints.prompt(hasTables: true).contains("recent table"))
        #expect(!EmptyQueryHints.prompt(hasTables: false).contains("table"))
    }
}
