import EchoSenseScenarios
import Foundation

/// The blocks a rule can be built from, by family, as the builder offers them. Each says whether it
/// means anything in the current query (a "before the dot" block needs a dot).
enum RefereeBlockCatalog {
    struct Entry: Identifiable, Sendable {
        let id: String
        let label: String
        let block: PopupBlock
        let isAvailable: @Sendable (ScenarioContext) -> Bool
    }

    struct Family: Identifiable, Sendable {
        let id: String
        let title: String
        /// The kind its pill shows.
        let kind: String
        let entries: [Entry]
    }

    private static let relations = PopupBlock.objectKinds
    @Sendable private static func always(_ context: ScenarioContext) -> Bool { true }
    @Sendable private static func hasQuery(_ context: ScenarioContext) -> Bool { !context.tables.isEmpty }
    private static func dot(_ kinds: ScenarioContext.Dot.Kind...) -> @Sendable (ScenarioContext) -> Bool { { context in context.dot.map { kinds.contains($0.kind) } ?? false } }

    static let families: [Family] = [
        Family(id: "objects", title: "Tables and views", kind: "table", entries: [
            Entry(id: "t-default", label: "Tables in the default schema", block: PopupBlock(.objects, .defaultSchema, kinds: ["table"]), isAvailable: always),
            Entry(id: "r-default", label: "Tables, views and materialized views in the default schema", block: PopupBlock(.objects, .defaultSchema, kinds: relations), isAvailable: always),
            Entry(id: "v-default", label: "Views and materialized views in the default schema", block: PopupBlock(.objects, .defaultSchema, kinds: ["view", "materializedView"]), isAvailable: always),
            Entry(id: "r-free", label: "Tables and views not yet in the query", block: PopupBlock(.objects, .defaultSchema, kinds: relations, notInQuery: true), isAvailable: hasQuery),
            Entry(id: "r-others", label: "Tables and views in other schemas", block: PopupBlock(.objects, .otherSchemas, kinds: relations), isAvailable: always),
            Entry(id: "r-dotschema", label: "Tables and views in the schema before the dot", block: PopupBlock(.objects, .schemaBeforeDot, kinds: relations), isAvailable: dot(.schema)),
            Entry(id: "r-dotdb", label: "Tables and views in the database before the dot", block: PopupBlock(.objects, .databaseBeforeDot, kinds: ["table", "view"]), isAvailable: dot(.database)),
            Entry(id: "t-fk", label: "Tables linked by a foreign key to the query's tables", block: PopupBlock(.objects, .linkedByForeignKey, kinds: ["table"]), isAvailable: hasQuery),
            Entry(id: "r-inquery", label: "Tables already in the query", block: PopupBlock(.objects, .inQuery, kinds: relations), isAvailable: hasQuery),
            Entry(id: "r-derived", label: "CTEs and subqueries in this query", block: PopupBlock(.objects, .derived), isAvailable: { !$0.derived.isEmpty })]),
        Family(id: "columns", title: "Columns", kind: "column", entries: [
            Entry(id: "c-dot", label: "Columns of the table before the dot", block: PopupBlock(.columns, .beforeDot), isAvailable: dot(.alias, .table, .derived)),
            Entry(id: "k-dot", label: "Key columns of the table before the dot", block: PopupBlock(.columns, .beforeDot, keysOnly: true), isAvailable: dot(.alias, .table)),
            Entry(id: "c-query", label: "Columns of the tables in the query", block: PopupBlock(.columns, .query), isAvailable: hasQuery),
            Entry(id: "k-query", label: "Key columns of the tables in the query", block: PopupBlock(.columns, .query, keysOnly: true), isAvailable: hasQuery),
            Entry(id: "c-changed", label: "Columns of the table being changed", block: PopupBlock(.columns, .changedTable), isAvailable: { $0.changedTable != nil }),
            Entry(id: "c-select", label: "Columns already in the SELECT list", block: PopupBlock(.columns, .selectList), isAvailable: { !$0.selectList.isEmpty })]),
        Family(id: "functions", title: "Functions", kind: "function", entries: [
            Entry(id: "f-agg", label: "Aggregate functions", block: PopupBlock(.functions, .aggregate), isAvailable: always),
            Entry(id: "f-builtin", label: "Built-in functions", block: PopupBlock(.functions, .builtIn), isAvailable: always),
            Entry(id: "f-db", label: "Functions and procedures in the database", block: PopupBlock(.functions, .database), isAvailable: always),
            Entry(id: "f-other", label: "Functions from other databases", block: PopupBlock(.functions, .otherDialects), isAvailable: always)]),
        Family(id: "keywords", title: "Keywords", kind: "keyword", entries: [
            Entry(id: "kw-fit", label: "Keywords that fit here", block: PopupBlock(.keywords, .fitting), isAvailable: always),
            Entry(id: "kw-sort", label: "Sort keywords (ASC, DESC, …)", block: PopupBlock(.keywords, .sort), isAvailable: always),
            Entry(id: "kw-op", label: "Operator keywords (IN, IS NULL, …)", block: PopupBlock(.keywords, .operators), isAvailable: always)]),
        Family(id: "schemas", title: "Schemas and databases", kind: "schema", entries: [
            Entry(id: "s-db", label: "Schemas in the database", block: PopupBlock(.schemas, .thisDatabase), isAvailable: always),
            Entry(id: "s-dotdb", label: "Schemas in the database before the dot", block: PopupBlock(.schemas, .databaseBeforeDot), isAvailable: dot(.database)),
            Entry(id: "db", label: "Database names", block: PopupBlock(.databases), isAvailable: always)]),
        Family(id: "other", title: "Snippets and parameters", kind: "snippet", entries: [
            Entry(id: "snip", label: "Snippets", block: PopupBlock(.snippets), isAvailable: always),
            Entry(id: "param", label: "Parameters", block: PopupBlock(.parameters), isAvailable: always)])
    ]
}
