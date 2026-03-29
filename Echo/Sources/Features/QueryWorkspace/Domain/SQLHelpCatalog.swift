import Foundation
import EchoSense

struct SQLHelpTopic: Sendable, Equatable {
    struct Section: Sendable, Equatable, Identifiable {
        let id: String
        let title: String
        let value: String
    }

    let lookupKeys: [String]
    let title: String
    let category: String
    let summary: String
    let syntax: String?
    let example: String?
    let notes: [String]
    let relatedTopics: [String]
    let sections: [Section]
}

enum SQLHelpCatalog {
    static func topic(for rawSelection: String, databaseType: EchoSenseDatabaseType) -> SQLHelpTopic? {
        let normalized = normalize(rawSelection)
        guard !normalized.isEmpty else { return nil }

        for candidate in candidates(from: normalized) {
            if let dialectTopic = dialectTopics(for: databaseType)[candidate] {
                return dialectTopic
            }
            if let sharedTopic = sharedTopics[candidate] {
                return sharedTopic
            }
        }
        return nil
    }

    private static let sharedTopics: [String: SQLHelpTopic] = Dictionary(
        uniqueKeysWithValues: [
            makeTopic(
                keys: ["SELECT"],
                title: "SELECT",
                category: "Query",
                summary: "Retrieves rows from one or more tables, views, or derived result sets.",
                syntax: "SELECT <columns>\nFROM <source>\n[WHERE <predicate>]\n[GROUP BY <columns>]\n[ORDER BY <columns>]\n[LIMIT <count>]",
                example: "SELECT customer_id, first_name, last_name\nFROM customers\nWHERE active = 1\nORDER BY last_name\nLIMIT 50;",
                notes: [
                    "Use WHERE to reduce the row set before sorting or grouping.",
                    "Use explicit column lists instead of SELECT * in production queries."
                ],
                related: ["WHERE", "JOIN", "GROUP BY", "ORDER BY", "LIMIT"]
            ),
            makeTopic(
                keys: ["INSERT"],
                title: "INSERT",
                category: "Data Change",
                summary: "Adds new rows to a table or inserts the results of another query.",
                syntax: "INSERT INTO <table> (<columns>)\nVALUES (<values>)\n[, (<values>)]",
                example: "INSERT INTO customers (first_name, last_name, active)\nVALUES ('Ana', 'Ng', 1);",
                notes: [
                    "Specify columns explicitly so schema changes do not break the statement.",
                    "Multi-row VALUES inserts are usually faster than one row per statement."
                ],
                related: ["UPDATE", "DELETE", "CREATE TABLE"]
            ),
            makeTopic(
                keys: ["UPDATE"],
                title: "UPDATE",
                category: "Data Change",
                summary: "Modifies existing rows in a table.",
                syntax: "UPDATE <table>\nSET <column> = <value>\n[WHERE <predicate>]",
                example: "UPDATE customers\nSET active = 0\nWHERE last_login_at < NOW() - INTERVAL 1 YEAR;",
                notes: [
                    "Always review the WHERE clause before executing bulk updates.",
                    "Run the predicate as a SELECT first when changing many rows."
                ],
                related: ["WHERE", "INSERT", "DELETE"]
            ),
            makeTopic(
                keys: ["DELETE"],
                title: "DELETE",
                category: "Data Change",
                summary: "Removes rows from a table.",
                syntax: "DELETE FROM <table>\n[WHERE <predicate>]",
                example: "DELETE FROM sessions\nWHERE expires_at < NOW();",
                notes: [
                    "A DELETE without WHERE removes every row in the table.",
                    "Use TRUNCATE when you need a full-table reset and the engine supports it."
                ],
                related: ["WHERE", "TRUNCATE", "INSERT"]
            ),
            makeTopic(
                keys: ["JOIN"],
                title: "JOIN",
                category: "Query",
                summary: "Combines rows from two result sets using a join condition.",
                syntax: "SELECT ...\nFROM <left>\n[INNER|LEFT|RIGHT] JOIN <right>\n    ON <join predicate>",
                example: "SELECT o.id, c.name\nFROM orders AS o\nJOIN customers AS c ON c.id = o.customer_id;",
                notes: [
                    "Prefer explicit JOIN syntax over comma-separated table lists.",
                    "Index join columns when joining large tables."
                ],
                related: ["SELECT", "WHERE", "GROUP BY"]
            ),
            makeTopic(
                keys: ["WHERE"],
                title: "WHERE",
                category: "Query",
                summary: "Filters rows before grouping, aggregation, or ordering.",
                syntax: "SELECT ...\nFROM <source>\nWHERE <predicate>",
                example: "SELECT *\nFROM invoices\nWHERE paid_at IS NULL AND due_date < CURRENT_DATE;",
                notes: [
                    "WHERE runs before GROUP BY; use HAVING to filter aggregated groups.",
                    "Sargable predicates usually produce better index usage."
                ],
                related: ["SELECT", "GROUP BY", "ORDER BY"]
            ),
            makeTopic(
                keys: ["GROUP BY"],
                title: "GROUP BY",
                category: "Aggregation",
                summary: "Groups rows so aggregate functions can be calculated per group.",
                syntax: "SELECT <group columns>, <aggregates>\nFROM <source>\nGROUP BY <group columns>",
                example: "SELECT country_code, COUNT(*) AS customer_count\nFROM customers\nGROUP BY country_code;",
                notes: [
                    "Every non-aggregated column in the SELECT list should appear in GROUP BY.",
                    "Use HAVING to filter grouped results."
                ],
                related: ["SELECT", "HAVING", "ORDER BY"]
            ),
            makeTopic(
                keys: ["ORDER BY"],
                title: "ORDER BY",
                category: "Sorting",
                summary: "Sorts the final result set by one or more expressions.",
                syntax: "SELECT ...\nFROM <source>\nORDER BY <expression> [ASC|DESC]",
                example: "SELECT id, created_at\nFROM events\nORDER BY created_at DESC, id DESC;",
                notes: [
                    "Sorting happens after filtering and grouping.",
                    "Add a deterministic secondary key for stable pagination."
                ],
                related: ["SELECT", "LIMIT", "GROUP BY"]
            ),
            makeTopic(
                keys: ["LIMIT"],
                title: "LIMIT",
                category: "Pagination",
                summary: "Restricts how many rows are returned.",
                syntax: "SELECT ...\nFROM <source>\nLIMIT <count> [OFFSET <count>]",
                example: "SELECT *\nFROM events\nORDER BY created_at DESC\nLIMIT 100 OFFSET 200;",
                notes: [
                    "Use ORDER BY with LIMIT for repeatable paging.",
                    "For large offsets, keyset pagination is usually faster."
                ],
                related: ["SELECT", "ORDER BY"]
            ),
            makeTopic(
                keys: ["CREATE TABLE"],
                title: "CREATE TABLE",
                category: "Schema",
                summary: "Creates a new table and defines its columns, keys, and options.",
                syntax: "CREATE TABLE <name> (\n    <column> <type> [constraints],\n    [PRIMARY KEY (...)]\n)",
                example: "CREATE TABLE customers (\n    customer_id bigint PRIMARY KEY,\n    email varchar(255) NOT NULL,\n    created_at timestamp NOT NULL\n);",
                notes: [
                    "Define primary keys and nullability up front to avoid later migration churn.",
                    "Keep engine-specific options out of shared scripts unless required."
                ],
                related: ["ALTER TABLE", "CREATE INDEX", "CREATE VIEW"]
            ),
            makeTopic(
                keys: ["ALTER TABLE"],
                title: "ALTER TABLE",
                category: "Schema",
                summary: "Changes an existing table definition by adding, modifying, or dropping objects.",
                syntax: "ALTER TABLE <name>\n<alteration clause>",
                example: "ALTER TABLE customers\nADD COLUMN marketing_opt_in tinyint(1) NOT NULL DEFAULT 0;",
                notes: [
                    "Large ALTER TABLE operations can lock or rebuild the table depending on engine and version.",
                    "Review generated DDL before applying it to production."
                ],
                related: ["CREATE TABLE", "CREATE INDEX", "EXPLAIN"]
            ),
            makeTopic(
                keys: ["CREATE INDEX"],
                title: "CREATE INDEX",
                category: "Schema",
                summary: "Creates a secondary access path to speed up lookups and sorting.",
                syntax: "CREATE [UNIQUE] INDEX <name>\nON <table> (<columns>)",
                example: "CREATE INDEX idx_orders_customer_created_at\nON orders (customer_id, created_at);",
                notes: [
                    "Choose column order based on the most selective predicates first.",
                    "Each index improves reads but adds write overhead."
                ],
                related: ["ALTER TABLE", "EXPLAIN", "ORDER BY"]
            ),
            makeTopic(
                keys: ["CREATE VIEW"],
                title: "CREATE VIEW",
                category: "Schema",
                summary: "Defines a named query that can be reused like a table.",
                syntax: "CREATE VIEW <name> AS\nSELECT ...",
                example: "CREATE VIEW active_customers AS\nSELECT customer_id, email\nFROM customers\nWHERE active = 1;",
                notes: [
                    "Keep view definitions explicit so downstream dependencies remain stable.",
                    "Permissions for querying a view depend on engine rules and ownership."
                ],
                related: ["SELECT", "CREATE TABLE"]
            ),
            makeTopic(
                keys: ["START TRANSACTION", "BEGIN"],
                title: "START TRANSACTION",
                category: "Transactions",
                summary: "Begins an explicit transaction so multiple statements can be committed or rolled back together.",
                syntax: "START TRANSACTION;",
                example: "START TRANSACTION;\nUPDATE inventory SET quantity = quantity - 1 WHERE sku = 'A-100';\nCOMMIT;",
                notes: [
                    "Long transactions hold locks longer and increase rollback cost.",
                    "Turn off auto-commit when you want explicit transaction boundaries."
                ],
                related: ["COMMIT", "ROLLBACK"]
            ),
            makeTopic(
                keys: ["COMMIT"],
                title: "COMMIT",
                category: "Transactions",
                summary: "Makes the current transaction's changes durable.",
                syntax: "COMMIT;",
                example: "COMMIT;",
                notes: [
                    "After COMMIT, the previous transaction cannot be rolled back.",
                    "Keep transaction scope as small as practical."
                ],
                related: ["START TRANSACTION", "ROLLBACK"]
            ),
            makeTopic(
                keys: ["ROLLBACK"],
                title: "ROLLBACK",
                category: "Transactions",
                summary: "Cancels the current transaction and undoes its uncommitted changes.",
                syntax: "ROLLBACK;",
                example: "ROLLBACK;",
                notes: [
                    "ROLLBACK only affects the active transaction.",
                    "Use savepoints when you need partial rollback within a longer transaction."
                ],
                related: ["START TRANSACTION", "COMMIT"]
            )
        ].flatMap { topic in
            topic.lookupKeys.map { ($0, topic) }
        }
    )

    private static func dialectTopics(for databaseType: EchoSenseDatabaseType) -> [String: SQLHelpTopic] {
        switch databaseType {
        case .mysql:
            return mysqlTopics
        case .microsoftSQL:
            return sqlServerTopics
        case .postgresql:
            return postgresTopics
        case .sqlite:
            return sqliteTopics
        }
    }

    private static let mysqlTopics: [String: SQLHelpTopic] = Dictionary(
        uniqueKeysWithValues: [
            makeTopic(
                keys: ["EXPLAIN"],
                title: "EXPLAIN",
                category: "Performance",
                summary: "Shows how MySQL plans to access tables, indexes, and joins for a statement.",
                syntax: "EXPLAIN [FORMAT = JSON] <statement>",
                example: "EXPLAIN FORMAT = JSON\nSELECT * FROM orders WHERE customer_id = 42;",
                notes: [
                    "Use FORMAT = JSON for richer plan details and structured analysis.",
                    "Combine with EXPLAIN ANALYZE when you need actual timing and row counts."
                ],
                related: ["SELECT", "CREATE INDEX", "ALTER TABLE"],
                sections: [
                    .init(id: "mysql-explain-tip", title: "MySQL Tip", value: "Watch the access type, chosen key, examined rows, and attached conditions when reviewing a plan.")
                ]
            ),
            makeTopic(
                keys: ["SHOW CREATE TABLE"],
                title: "SHOW CREATE TABLE",
                category: "Metadata",
                summary: "Returns the full CREATE TABLE statement MySQL would use for an existing table.",
                syntax: "SHOW CREATE TABLE <table>",
                example: "SHOW CREATE TABLE customers;",
                notes: [
                    "Useful for verifying engine, charset, collation, and generated columns.",
                    "Echo's MySQL object inspectors and table editor can use the same metadata for DDL workflows."
                ],
                related: ["CREATE TABLE", "ALTER TABLE"]
            ),
            makeTopic(
                keys: ["CREATE PROCEDURE"],
                title: "CREATE PROCEDURE",
                category: "Programmable Objects",
                summary: "Creates a stored procedure in the current schema.",
                syntax: "CREATE PROCEDURE <name> ([parameters])\nBEGIN\n    <statements>;\nEND",
                example: "CREATE PROCEDURE archive_inactive_accounts()\nBEGIN\n    UPDATE users SET archived = 1 WHERE active = 0;\nEND;",
                notes: [
                    "Procedures can return result sets and perform transactional work.",
                    "Use delimiters carefully when executing multi-line routines in script mode."
                ],
                related: ["CREATE FUNCTION", "CREATE TRIGGER"]
            ),
            makeTopic(
                keys: ["CREATE FUNCTION"],
                title: "CREATE FUNCTION",
                category: "Programmable Objects",
                summary: "Creates a stored function that returns a value.",
                syntax: "CREATE FUNCTION <name> ([parameters])\nRETURNS <type>\nBEGIN\n    RETURN <expression>;\nEND",
                example: "CREATE FUNCTION full_name(first_name varchar(100), last_name varchar(100))\nRETURNS varchar(201)\nBEGIN\n    RETURN CONCAT(first_name, ' ', last_name);\nEND;",
                notes: [
                    "Declare function characteristics like DETERMINISTIC where appropriate.",
                    "Stored functions are often used inside SELECT and WHERE expressions."
                ],
                related: ["CREATE PROCEDURE", "SELECT"]
            ),
            makeTopic(
                keys: ["CREATE TRIGGER"],
                title: "CREATE TRIGGER",
                category: "Programmable Objects",
                summary: "Creates a trigger that runs before or after INSERT, UPDATE, or DELETE events.",
                syntax: "CREATE TRIGGER <name>\n{BEFORE|AFTER} {INSERT|UPDATE|DELETE}\nON <table>\nFOR EACH ROW\nBEGIN\n    <statements>;\nEND",
                example: "CREATE TRIGGER customers_bu\nBEFORE UPDATE ON customers\nFOR EACH ROW\nBEGIN\n    SET NEW.updated_at = NOW();\nEND;",
                notes: [
                    "Triggers execute per row in MySQL.",
                    "Prefer clear, deterministic trigger logic and avoid hidden side effects."
                ],
                related: ["CREATE PROCEDURE", "ALTER TABLE"]
            )
        ].flatMap { topic in
            topic.lookupKeys.map { ($0, topic) }
        }
    )

    private static let postgresTopics: [String: SQLHelpTopic] = [:]
    private static let sqlServerTopics: [String: SQLHelpTopic] = [:]
    private static let sqliteTopics: [String: SQLHelpTopic] = [:]

    private static func makeTopic(
        keys: [String],
        title: String,
        category: String,
        summary: String,
        syntax: String? = nil,
        example: String? = nil,
        notes: [String] = [],
        related: [String] = [],
        sections: [SQLHelpTopic.Section] = []
    ) -> SQLHelpTopic {
        SQLHelpTopic(
            lookupKeys: keys,
            title: title,
            category: category,
            summary: summary,
            syntax: syntax,
            example: example,
            notes: notes,
            relatedTopics: related,
            sections: sections
        )
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "`", with: " ")
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ";", with: " ")
            .uppercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func candidates(from normalized: String) -> [String] {
        let words = normalized.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        var results: [String] = [normalized]
        if words.count >= 3 {
            results.append(words.prefix(3).joined(separator: " "))
        }
        if words.count >= 2 {
            results.append(words.prefix(2).joined(separator: " "))
        }
        results.append(words[0])
        return Array(NSOrderedSet(array: results)) as? [String] ?? results
    }
}
