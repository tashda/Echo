import XCTest
import PostgresKit
@testable import Echo

/// Integration tests for ALTER operations on advanced PostgreSQL object types:
/// domains, composite types, collations, event triggers, FTS configurations, and rules.
final class PGAdvancedObjectAlterTests: PostgresDockerTestCase {

    // MARK: - Domain ALTER Operations

    func testDomainAlterOperations() async throws {
        let name = uniqueName(prefix: "dom")
        let newName = uniqueName(prefix: "dom_renamed")
        cleanupSQL(
            "DROP DOMAIN IF EXISTS public.\"\(newName)\" CASCADE",
            "DROP DOMAIN IF EXISTS public.\"\(name)\" CASCADE"
        )

        // Create domain
        try await postgresClient.admin.createDomain(
            name: name, dataType: "text", schema: "public"
        )

        // Verify it exists
        let domainsBefore = try await postgresClient.introspection.listDomains(schema: "public")
        XCTAssertTrue(
            domainsBefore.contains { $0.name == name },
            "Expected domain '\(name)' to exist after creation"
        )

        // Rename
        try await postgresClient.admin.alterDomainRename(
            name: name, newName: newName, schema: "public"
        )

        // Verify rename
        let domainsAfterRename = try await postgresClient.introspection.listDomains(schema: "public")
        XCTAssertTrue(
            domainsAfterRename.contains { $0.name == newName },
            "Expected domain '\(newName)' to exist after rename"
        )
        XCTAssertFalse(
            domainsAfterRename.contains { $0.name == name },
            "Old domain name '\(name)' should not exist after rename"
        )

        // Change owner
        try await postgresClient.admin.alterDomainOwner(
            name: newName, newOwner: "postgres", schema: "public"
        )

        // Set default
        try await postgresClient.admin.alterDomainSetDefault(
            name: newName, defaultValue: "'hello'", schema: "public"
        )

        // Add constraint
        let constraintName = uniqueName(prefix: "chk")
        try await postgresClient.admin.alterDomainAddConstraint(
            name: newName,
            constraintName: constraintName,
            checkExpression: "VALUE <> ''",
            schema: "public"
        )

        // Verify constraint via introspection
        let domainsWithConstraint = try await postgresClient.introspection.listDomains(schema: "public")
        let domain = domainsWithConstraint.first { $0.name == newName }
        XCTAssertNotNil(domain, "Domain '\(newName)' should still exist")
        XCTAssertTrue(
            domain?.constraints.contains { $0.name == constraintName } ?? false,
            "Expected constraint '\(constraintName)' on domain"
        )

        // Drop constraint
        try await postgresClient.admin.alterDomainDropConstraint(
            name: newName, constraintName: constraintName, schema: "public"
        )

        // Set NOT NULL then drop it
        try await postgresClient.admin.alterDomainSetNotNull(name: newName, schema: "public")
        let domainNotNull = try await postgresClient.introspection.listDomains(schema: "public")
            .first { $0.name == newName }
        XCTAssertTrue(domainNotNull?.isNotNull ?? false, "Domain should be NOT NULL")

        try await postgresClient.admin.alterDomainDropNotNull(name: newName, schema: "public")
        let domainNullable = try await postgresClient.introspection.listDomains(schema: "public")
            .first { $0.name == newName }
        XCTAssertFalse(domainNullable?.isNotNull ?? true, "Domain should be nullable after DROP NOT NULL")
    }

    // MARK: - Composite Type ALTER Operations

    func testCompositeTypeAlterOperations() async throws {
        let name = uniqueName(prefix: "comp")
        let newName = uniqueName(prefix: "comp_renamed")
        cleanupSQL(
            "DROP TYPE IF EXISTS public.\"\(newName)\" CASCADE",
            "DROP TYPE IF EXISTS public.\"\(name)\" CASCADE"
        )

        // Create composite type
        try await postgresClient.admin.createCompositeType(
            name: name,
            attributes: [("x", "integer"), ("y", "text")],
            schema: "public"
        )

        // Verify it exists
        let typesBefore = try await postgresClient.introspection.listCompositeTypes(schema: "public")
        let created = typesBefore.first { $0.name == name }
        XCTAssertNotNil(created, "Expected composite type '\(name)' to exist after creation")
        XCTAssertEqual(created?.attributes.count, 2, "Expected 2 attributes")

        // Add attribute
        try await postgresClient.admin.alterCompositeTypeAddAttribute(
            name: name, attributeName: "z", dataType: "boolean", schema: "public"
        )

        let typesAfterAdd = try await postgresClient.introspection.listCompositeTypes(schema: "public")
        let withNewAttr = typesAfterAdd.first { $0.name == name }
        XCTAssertEqual(withNewAttr?.attributes.count, 3, "Expected 3 attributes after adding 'z'")
        XCTAssertTrue(
            withNewAttr?.attributes.contains { $0.name == "z" } ?? false,
            "Expected attribute 'z' to exist"
        )

        // Drop attribute
        try await postgresClient.admin.alterCompositeTypeDropAttribute(
            name: name, attributeName: "z", schema: "public"
        )

        let typesAfterDrop = try await postgresClient.introspection.listCompositeTypes(schema: "public")
        let withoutAttr = typesAfterDrop.first { $0.name == name }
        XCTAssertEqual(withoutAttr?.attributes.count, 2, "Expected 2 attributes after dropping 'z'")

        // Rename type
        try await postgresClient.admin.alterTypeRename(
            name: name, newName: newName, schema: "public"
        )

        let typesAfterRename = try await postgresClient.introspection.listCompositeTypes(schema: "public")
        XCTAssertTrue(
            typesAfterRename.contains { $0.name == newName },
            "Expected type '\(newName)' after rename"
        )
        XCTAssertFalse(
            typesAfterRename.contains { $0.name == name },
            "Old type name '\(name)' should not exist after rename"
        )

        // Change owner
        try await postgresClient.admin.alterTypeOwner(
            name: newName, newOwner: "postgres", schema: "public"
        )
    }

    // MARK: - Collation ALTER Operations

    func testCollationAlterOperations() async throws {
        let name = uniqueName(prefix: "coll")
        let newName = uniqueName(prefix: "coll_renamed")
        cleanupSQL(
            "DROP COLLATION IF EXISTS public.\"\(newName)\"",
            "DROP COLLATION IF EXISTS public.\"\(name)\""
        )

        // Create collation (copy from an existing one using locale)
        try await postgresClient.admin.createCollation(
            name: name,
            locale: "en_US.utf8",
            provider: "libc",
            schema: "public"
        )

        // Verify it exists
        let collsBefore = try await postgresClient.introspection.listCollations(schema: "public")
        XCTAssertTrue(
            collsBefore.contains { $0.name == name },
            "Expected collation '\(name)' to exist after creation"
        )

        // Rename
        try await postgresClient.admin.alterCollationRename(
            name: name, newName: newName, schema: "public"
        )

        let collsAfterRename = try await postgresClient.introspection.listCollations(schema: "public")
        XCTAssertTrue(
            collsAfterRename.contains { $0.name == newName },
            "Expected collation '\(newName)' after rename"
        )
        XCTAssertFalse(
            collsAfterRename.contains { $0.name == name },
            "Old collation name '\(name)' should not exist after rename"
        )

        // Change owner
        try await postgresClient.admin.alterCollationOwner(
            name: newName, newOwner: "postgres", schema: "public"
        )
    }

    // MARK: - Event Trigger ALTER Operations

    func testEventTriggerAlterOperations() async throws {
        let funcName = uniqueName(prefix: "evtfn")
        let trigName = uniqueName(prefix: "evttrig")
        let newTrigName = uniqueName(prefix: "evttrig_renamed")
        cleanupSQL(
            "DROP EVENT TRIGGER IF EXISTS \"\(newTrigName)\"",
            "DROP EVENT TRIGGER IF EXISTS \"\(trigName)\"",
            "DROP FUNCTION IF EXISTS public.\"\(funcName)\"()"
        )

        // Create the required event trigger function
        try await execute("""
            CREATE FUNCTION public."\(funcName)"() RETURNS event_trigger
            LANGUAGE plpgsql AS $$
            BEGIN
                RAISE NOTICE 'event trigger fired';
            END;
            $$
        """)

        // Create event trigger
        try await postgresClient.admin.createEventTrigger(
            name: trigName,
            event: "ddl_command_end",
            function: "public.\"\(funcName)\""
        )

        // Verify it exists
        let trigsBefore = try await postgresClient.introspection.listEventTriggers()
        XCTAssertTrue(
            trigsBefore.contains { $0.name == trigName },
            "Expected event trigger '\(trigName)' to exist after creation"
        )

        // Disable
        try await postgresClient.admin.alterEventTriggerEnable(name: trigName, enable: false)
        let trigsDisabled = try await postgresClient.introspection.listEventTriggers()
        let disabled = trigsDisabled.first { $0.name == trigName }
        XCTAssertEqual(
            disabled?.enabled, "D",
            "Expected event trigger to be disabled (enabled='D')"
        )

        // Re-enable
        try await postgresClient.admin.alterEventTriggerEnable(name: trigName, enable: true)
        let trigsEnabled = try await postgresClient.introspection.listEventTriggers()
        let enabled = trigsEnabled.first { $0.name == trigName }
        XCTAssertEqual(
            enabled?.enabled, "O",
            "Expected event trigger to be enabled (enabled='O')"
        )

        // Rename
        try await postgresClient.admin.alterEventTriggerRename(
            name: trigName, newName: newTrigName
        )

        let trigsAfterRename = try await postgresClient.introspection.listEventTriggers()
        XCTAssertTrue(
            trigsAfterRename.contains { $0.name == newTrigName },
            "Expected event trigger '\(newTrigName)' after rename"
        )
        XCTAssertFalse(
            trigsAfterRename.contains { $0.name == trigName },
            "Old event trigger name '\(trigName)' should not exist after rename"
        )

        // Change owner
        try await postgresClient.admin.alterEventTriggerOwner(
            name: newTrigName, newOwner: "postgres"
        )
    }

    // MARK: - FTS Configuration ALTER Operations

    func testFTSConfigAlterOperations() async throws {
        let name = uniqueName(prefix: "fts")
        let newName = uniqueName(prefix: "fts_renamed")
        cleanupSQL(
            "DROP TEXT SEARCH CONFIGURATION IF EXISTS public.\"\(newName)\"",
            "DROP TEXT SEARCH CONFIGURATION IF EXISTS public.\"\(name)\""
        )

        // Create FTS config by copying the built-in 'simple' config
        try await postgresClient.admin.createTextSearchConfiguration(
            name: name, copy: "simple", schema: "public"
        )

        // Verify it exists
        let ftsBefore = try await postgresClient.introspection.listTextSearchConfigurations(schema: "public")
        XCTAssertTrue(
            ftsBefore.contains { $0.name == name },
            "Expected FTS config '\(name)' to exist after creation"
        )

        // Rename
        try await postgresClient.admin.alterTextSearchConfigurationRename(
            name: name, newName: newName, schema: "public"
        )

        let ftsAfterRename = try await postgresClient.introspection.listTextSearchConfigurations(schema: "public")
        XCTAssertTrue(
            ftsAfterRename.contains { $0.name == newName },
            "Expected FTS config '\(newName)' after rename"
        )
        XCTAssertFalse(
            ftsAfterRename.contains { $0.name == name },
            "Old FTS config name '\(name)' should not exist after rename"
        )

        // Change owner
        try await postgresClient.admin.alterTextSearchConfigurationOwner(
            name: newName, newOwner: "postgres", schema: "public"
        )
    }

    // MARK: - Rule ALTER Operations

    func testRuleAlterOperations() async throws {
        let tableName = uniqueName(prefix: "rule_tbl")
        let ruleName = uniqueName(prefix: "rule")
        let newRuleName = uniqueName(prefix: "rule_renamed")
        cleanupSQL(
            "DROP TABLE IF EXISTS public.\"\(tableName)\" CASCADE"
        )

        // Create table for the rule
        try await execute(
            "CREATE TABLE public.\"\(tableName)\" (id serial PRIMARY KEY, name text)"
        )

        // Create a no-op rule on INSERT
        try await postgresClient.admin.createRule(
            name: ruleName,
            table: tableName,
            event: "INSERT",
            doInstead: true,
            commands: "NOTHING",
            schema: "public"
        )

        // Verify it exists
        let rulesBefore = try await postgresClient.introspection.listRules(
            schema: "public", table: tableName
        )
        XCTAssertTrue(
            rulesBefore.contains { $0.name == ruleName },
            "Expected rule '\(ruleName)' to exist after creation"
        )

        // Rename rule
        try await postgresClient.admin.alterRuleRename(
            ruleName: ruleName,
            tableName: tableName,
            newName: newRuleName,
            schema: "public"
        )

        let rulesAfterRename = try await postgresClient.introspection.listRules(
            schema: "public", table: tableName
        )
        XCTAssertTrue(
            rulesAfterRename.contains { $0.name == newRuleName },
            "Expected rule '\(newRuleName)' after rename"
        )
        XCTAssertFalse(
            rulesAfterRename.contains { $0.name == ruleName },
            "Old rule name '\(ruleName)' should not exist after rename"
        )
    }
}
