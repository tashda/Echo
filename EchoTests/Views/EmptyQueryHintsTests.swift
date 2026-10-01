import Foundation
import Testing
import EchoSense
@testable import Echo

@Suite("Empty query tab hints (QE6)")
struct EmptyQueryHintsTests {
    @Test(arguments: EchoSenseDatabaseType.allCases)
    func everyDatabaseTypeHasSnippetsToOffer(type: EchoSenseDatabaseType) throws {
        let dialect = try #require(SQLDialect(rawValue: type.rawValue))
        #expect(!SQLSnippetCatalog.snippets(for: dialect).isEmpty)
    }
}
