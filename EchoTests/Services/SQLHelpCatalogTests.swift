import Testing
@testable import Echo
import EchoSense

struct SQLHelpCatalogTests {
    @Test
    func resolvesMySQLSpecificPhrase() {
        let topic = SQLHelpCatalog.topic(for: "show create table customers;", databaseType: .mysql)
        #expect(topic?.title == "SHOW CREATE TABLE")
    }

    @Test
    func resolvesSharedKeywordFromSelection() {
        let topic = SQLHelpCatalog.topic(for: "  select * from users  ", databaseType: .mysql)
        #expect(topic?.title == "SELECT")
    }

    @Test
    func providerBuildsInspectorContent() {
        let content = SQLHelpInspectorContentProvider().content(for: "EXPLAIN FORMAT = JSON", databaseType: .mysql)
        #expect(content?.title == "EXPLAIN")
        #expect(content?.syntax?.contains("FORMAT = JSON") == true)
    }

    @Test
    func unknownSelectionReturnsNil() {
        let topic = SQLHelpCatalog.topic(for: "customer_id", databaseType: .mysql)
        #expect(topic == nil)
    }
}
