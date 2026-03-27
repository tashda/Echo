import Testing
import Foundation
@testable import Echo

// MARK: - PostgreSQLDialectGenerator

@Suite("PostgreSQLDialectGenerator")
struct PostgreSQLDialectGeneratorTests {
    let gen = PostgreSQLDialectGenerator(schema: "public")

    private var table: String {
        gen.qualifiedTable(schema: "public", table: "users")
    }

    // MARK: quoteIdentifier

    @Test func quoteIdentifierRegularName() {
        #expect(gen.quoteIdentifier("name") == "\"name\"")
    }

    @Test func quoteIdentifierReservedWord() {
        #expect(gen.quoteIdentifier("select") == "\"select\"")
    }

    @Test func quoteIdentifierWithDoubleQuotes() {
        #expect(gen.quoteIdentifier("my\"col") == "\"my\"\"col\"")
    }

    @Test func quoteIdentifierEmptyString() {
        #expect(gen.quoteIdentifier("") == "\"\"")
    }

    // MARK: qualifiedTable

    @Test func qualifiedTableSchemaAndTable() {
        let result = gen.qualifiedTable(schema: "public", table: "orders")
        #expect(result == "\"public\".\"orders\"")
    }

    @Test func qualifiedTableSpecialChars() {
        let result = gen.qualifiedTable(schema: "my\"schema", table: "my\"table")
        #expect(result == "\"my\"\"schema\".\"my\"\"table\"")
    }

    // MARK: Transaction statements

    @Test func beginTransaction() {
        #expect(gen.beginTransaction() == "BEGIN;")
    }

    @Test func commitTransaction() {
        #expect(gen.commitTransaction() == "COMMIT;")
    }

    @Test func rollbackTransaction() {
        #expect(gen.rollbackTransaction() == "ROLLBACK;")
    }

    // MARK: dropColumn

    @Test func dropColumn() {
        let result = gen.dropColumn(table: table, column: "email")
        #expect(result == "ALTER TABLE \"public\".\"users\" DROP COLUMN \"email\" CASCADE;")
    }

    @Test func dropColumnSpecialName() {
        let result = gen.dropColumn(table: table, column: "my\"col")
        #expect(result == "ALTER TABLE \"public\".\"users\" DROP COLUMN \"my\"\"col\" CASCADE;")
    }

    // MARK: renameColumn

    @Test func renameColumn() {
        let result = gen.renameColumn(table: table, from: "old_name", to: "new_name")
        #expect(result == "ALTER TABLE \"public\".\"users\" RENAME COLUMN \"old_name\" TO \"new_name\";")
    }

    // MARK: addColumn

    @Test func addColumnNullable() {
        let result = gen.addColumn(table: table, name: "email", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil)
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD COLUMN \"email\" text;")
    }

    @Test func addColumnNotNull() {
        let result = gen.addColumn(table: table, name: "email", dataType: "text", isNullable: false, defaultValue: nil, generatedExpression: nil)
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD COLUMN \"email\" text NOT NULL;")
    }

    @Test func addColumnWithDefault() {
        let result = gen.addColumn(table: table, name: "status", dataType: "integer", isNullable: true, defaultValue: "0", generatedExpression: nil)
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD COLUMN \"status\" integer DEFAULT 0;")
    }

    @Test func addColumnNotNullWithDefault() {
        let result = gen.addColumn(table: table, name: "status", dataType: "integer", isNullable: false, defaultValue: "0", generatedExpression: nil)
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD COLUMN \"status\" integer NOT NULL DEFAULT 0;")
    }

    @Test func addColumnWithGeneratedExpression() {
        let result = gen.addColumn(table: table, name: "full_name", dataType: "text", isNullable: true, defaultValue: "fallback", generatedExpression: "first || ' ' || last")
        #expect(result.contains("GENERATED ALWAYS AS (first || ' ' || last) STORED"))
        #expect(!result.contains("DEFAULT")) // generated takes priority over default
    }

    @Test func addColumnWithEmptyGeneratedExpression() {
        let result = gen.addColumn(table: table, name: "col", dataType: "text", isNullable: true, defaultValue: "x", generatedExpression: "  ")
        #expect(result.contains("DEFAULT x"))
        #expect(!result.contains("GENERATED"))
    }

    @Test func addColumnEmptyDefault() {
        let result = gen.addColumn(table: table, name: "col", dataType: "text", isNullable: true, defaultValue: "", generatedExpression: nil)
        #expect(!result.contains("DEFAULT"))
    }

    // MARK: alterColumnType

    @Test func alterColumnType() {
        let result = gen.alterColumnType(table: table, column: "age", newType: "bigint", isNullable: true)
        #expect(result == "ALTER TABLE \"public\".\"users\" ALTER COLUMN \"age\" TYPE bigint;")
    }

    @Test func alterColumnTypeIgnoresNullability() {
        // Postgres ALTER COLUMN TYPE does not include nullability
        let nullable = gen.alterColumnType(table: table, column: "age", newType: "int", isNullable: true)
        let notNullable = gen.alterColumnType(table: table, column: "age", newType: "int", isNullable: false)
        #expect(nullable == notNullable)
    }

    // MARK: alterColumnNullability

    @Test func alterColumnSetNullable() {
        let result = gen.alterColumnNullability(table: table, column: "email", isNullable: true, currentType: "text")
        #expect(result == "ALTER TABLE \"public\".\"users\" ALTER COLUMN \"email\" DROP NOT NULL;")
    }

    @Test func alterColumnSetNotNull() {
        let result = gen.alterColumnNullability(table: table, column: "email", isNullable: false, currentType: "text")
        #expect(result == "ALTER TABLE \"public\".\"users\" ALTER COLUMN \"email\" SET NOT NULL;")
    }

    // MARK: alterColumnSetDefault / dropDefault

    @Test func alterColumnSetDefault() {
        let result = gen.alterColumnSetDefault(table: table, column: "status", defaultValue: "'active'")
        #expect(result == "ALTER TABLE \"public\".\"users\" ALTER COLUMN \"status\" SET DEFAULT 'active';")
    }

    @Test func alterColumnDropDefault() {
        let result = gen.alterColumnDropDefault(table: table, column: "status")
        #expect(result == "ALTER TABLE \"public\".\"users\" ALTER COLUMN \"status\" DROP DEFAULT;")
    }

    // MARK: addPrimaryKey

    @Test func addPrimaryKeySingleColumn() {
        let result = gen.addPrimaryKey(table: table, name: "pk_users", columns: ["id"])
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD CONSTRAINT \"pk_users\" PRIMARY KEY (\"id\");")
    }

    @Test func addPrimaryKeyMultiColumn() {
        let result = gen.addPrimaryKey(table: table, name: "pk_composite", columns: ["org_id", "user_id"])
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD CONSTRAINT \"pk_composite\" PRIMARY KEY (\"org_id\", \"user_id\");")
    }

    // MARK: dropConstraint

    @Test func dropConstraint() {
        let result = gen.dropConstraint(table: table, name: "pk_users")
        #expect(result == "ALTER TABLE \"public\".\"users\" DROP CONSTRAINT \"pk_users\";")
    }

    // MARK: createIndex

    @Test func createIndexRegular() {
        let result = gen.createIndex(table: table, name: "idx_email", columns: [(name: "email", sort: "ASC")], isUnique: false, filter: nil)
        #expect(result == "CREATE INDEX \"idx_email\" ON \"public\".\"users\" (\"email\" ASC);")
    }

    @Test func createIndexUnique() {
        let result = gen.createIndex(table: table, name: "idx_email", columns: [(name: "email", sort: "ASC")], isUnique: true, filter: nil)
        #expect(result == "CREATE UNIQUE INDEX \"idx_email\" ON \"public\".\"users\" (\"email\" ASC);")
    }

    @Test func createIndexWithFilter() {
        let result = gen.createIndex(table: table, name: "idx_active", columns: [(name: "email", sort: "ASC")], isUnique: false, filter: "active = true")
        #expect(result.contains("WHERE active = true"))
    }

    @Test func createIndexMultiColumn() {
        let result = gen.createIndex(table: table, name: "idx_multi", columns: [(name: "a", sort: "ASC"), (name: "b", sort: "DESC")], isUnique: false, filter: nil)
        #expect(result.contains("(\"a\" ASC, \"b\" DESC)"))
    }

    // MARK: dropIndex

    @Test func dropIndex() {
        let result = gen.dropIndex(schema: "public", name: "idx_email", table: table)
        #expect(result == "DROP INDEX IF EXISTS \"public\".\"idx_email\";")
    }

    // MARK: addUniqueConstraint

    @Test func addUniqueConstraintSingleColumn() {
        let result = gen.addUniqueConstraint(table: table, name: "uq_email", columns: ["email"])
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD CONSTRAINT \"uq_email\" UNIQUE (\"email\");")
    }

    @Test func addUniqueConstraintMultiColumn() {
        let result = gen.addUniqueConstraint(table: table, name: "uq_combo", columns: ["first", "last"])
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD CONSTRAINT \"uq_combo\" UNIQUE (\"first\", \"last\");")
    }

    // MARK: addForeignKey

    @Test func addForeignKeySimple() {
        let result = gen.addForeignKey(
            table: table, name: "fk_order_user",
            columns: ["user_id"],
            referencedSchema: "public", referencedTable: "orders",
            referencedColumns: ["id"],
            onUpdate: nil, onDelete: nil
        )
        #expect(result.contains("FOREIGN KEY (\"user_id\") REFERENCES \"public\".\"orders\" (\"id\")"))
        #expect(!result.contains("ON UPDATE"))
        #expect(!result.contains("ON DELETE"))
        #expect(result.hasSuffix(";"))
    }

    @Test func addForeignKeyWithActions() {
        let result = gen.addForeignKey(
            table: table, name: "fk_order_user",
            columns: ["user_id"],
            referencedSchema: "public", referencedTable: "orders",
            referencedColumns: ["id"],
            onUpdate: "CASCADE", onDelete: "SET NULL"
        )
        #expect(result.contains("ON UPDATE CASCADE"))
        #expect(result.contains("ON DELETE SET NULL"))
    }

    @Test func addForeignKeyMultiColumn() {
        let result = gen.addForeignKey(
            table: table, name: "fk_multi",
            columns: ["org_id", "dept_id"],
            referencedSchema: "public", referencedTable: "departments",
            referencedColumns: ["org_id", "id"],
            onUpdate: nil, onDelete: "CASCADE"
        )
        #expect(result.contains("(\"org_id\", \"dept_id\")"))
        #expect(result.contains("(\"org_id\", \"id\")"))
        #expect(result.contains("ON DELETE CASCADE"))
        #expect(!result.contains("ON UPDATE"))
    }

    @Test func addForeignKeyEmptyActions() {
        let result = gen.addForeignKey(
            table: table, name: "fk_test",
            columns: ["col"],
            referencedSchema: "public", referencedTable: "ref",
            referencedColumns: ["id"],
            onUpdate: "", onDelete: ""
        )
        #expect(!result.contains("ON UPDATE"))
        #expect(!result.contains("ON DELETE"))
    }

    // MARK: - addColumn: identity & collation

    @Test func addColumnWithIdentityAlways() {
        let result = gen.addColumn(table: table, name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, identity: (seed: 1, increment: 1, generation: "ALWAYS"), collation: nil)
        #expect(result.contains("GENERATED ALWAYS AS IDENTITY"))
    }

    @Test func addColumnWithIdentityByDefault() {
        let result = gen.addColumn(table: table, name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, identity: (seed: 1, increment: 1, generation: "BY DEFAULT"), collation: nil)
        #expect(result.contains("GENERATED BY DEFAULT AS IDENTITY"))
    }

    @Test func addColumnWithIdentitySeedIncrement() {
        let result = gen.addColumn(table: table, name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, identity: (seed: 100, increment: 5, generation: "ALWAYS"), collation: nil)
        #expect(result.contains("START WITH 100 INCREMENT BY 5"))
    }

    @Test func addColumnWithCollation() {
        let result = gen.addColumn(table: table, name: "name", dataType: "text", isNullable: true, defaultValue: nil, generatedExpression: nil, identity: nil, collation: "en_US.utf8")
        #expect(result.contains("COLLATE \"en_US.utf8\""))
    }

    @Test func addColumnWithIdentityAndCollation() {
        let result = gen.addColumn(table: table, name: "id", dataType: "integer", isNullable: false, defaultValue: nil, generatedExpression: nil, identity: (seed: 1, increment: 1, generation: "ALWAYS"), collation: "en_US.utf8")
        #expect(result.contains("COLLATE \"en_US.utf8\""))
        #expect(result.contains("GENERATED ALWAYS AS IDENTITY"))
    }

    @Test func addColumnIdentitySkipsDefault() {
        let result = gen.addColumn(table: table, name: "id", dataType: "integer", isNullable: false, defaultValue: "0", generatedExpression: nil, identity: (seed: 1, increment: 1, generation: "ALWAYS"), collation: nil)
        #expect(!result.contains("DEFAULT"))
        #expect(result.contains("GENERATED ALWAYS AS IDENTITY"))
    }

    // MARK: - createIndex: includeColumns & indexType

    @Test func createIndexWithIncludeColumns() {
        let result = gen.createIndex(table: table, name: "idx_test", columns: [(name: "col1", sort: "ASC")], includeColumns: ["col3"], isUnique: false, filter: nil, indexType: nil)
        #expect(result.contains("INCLUDE (\"col3\")"))
    }

    @Test func createIndexWithIndexTypeGin() {
        let result = gen.createIndex(table: table, name: "idx_gin", columns: [(name: "col1", sort: "ASC")], includeColumns: [], isUnique: false, filter: nil, indexType: "gin")
        #expect(result.contains("USING gin"))
    }

    @Test func createIndexWithIndexTypeBtreeOmitted() {
        let result = gen.createIndex(table: table, name: "idx_btree", columns: [(name: "col1", sort: "ASC")], includeColumns: [], isUnique: false, filter: nil, indexType: "btree")
        #expect(!result.contains("USING"))
    }

    @Test func createIndexWithIncludeAndFilter() {
        let result = gen.createIndex(table: table, name: "idx_both", columns: [(name: "col1", sort: "ASC")], includeColumns: ["col2"], isUnique: false, filter: "active = true", indexType: nil)
        #expect(result.contains("INCLUDE (\"col2\")"))
        #expect(result.contains("WHERE active = true"))
    }

    // MARK: - addPrimaryKey: deferrable

    @Test func addPrimaryKeyDeferrable() {
        let result = gen.addPrimaryKey(table: table, name: "pk_users", columns: ["id"], isDeferrable: true, isInitiallyDeferred: false)
        #expect(result.contains("DEFERRABLE INITIALLY IMMEDIATE"))
    }

    @Test func addPrimaryKeyDeferrableInitiallyDeferred() {
        let result = gen.addPrimaryKey(table: table, name: "pk_users", columns: ["id"], isDeferrable: true, isInitiallyDeferred: true)
        #expect(result.contains("DEFERRABLE INITIALLY DEFERRED"))
    }

    @Test func addPrimaryKeyNotDeferrable() {
        let result = gen.addPrimaryKey(table: table, name: "pk_users", columns: ["id"], isDeferrable: false, isInitiallyDeferred: false)
        #expect(!result.contains("DEFERRABLE"))
    }

    // MARK: - addUniqueConstraint: deferrable

    @Test func addUniqueConstraintDeferrable() {
        let result = gen.addUniqueConstraint(table: table, name: "uq_email", columns: ["email"], isDeferrable: true, isInitiallyDeferred: true)
        #expect(result.contains("DEFERRABLE INITIALLY DEFERRED"))
    }

    // MARK: - addCheckConstraint

    @Test func addCheckConstraintSimple() {
        let result = gen.addCheckConstraint(table: table, name: "chk_age", expression: "age >= 0")
        #expect(result == "ALTER TABLE \"public\".\"users\" ADD CONSTRAINT \"chk_age\" CHECK (age >= 0);")
    }

    @Test func addCheckConstraintComplexExpression() {
        let result = gen.addCheckConstraint(table: table, name: "chk_status", expression: "status IN ('active', 'inactive')")
        #expect(result.contains("CHECK (status IN ('active', 'inactive'))"))
    }

    // MARK: - addForeignKey: deferrable

    @Test func addForeignKeyDeferrable() {
        let result = gen.addForeignKey(
            table: table, name: "fk_test",
            columns: ["user_id"],
            referencedSchema: "public", referencedTable: "orders",
            referencedColumns: ["id"],
            onUpdate: nil, onDelete: nil,
            isDeferrable: true, isInitiallyDeferred: true
        )
        #expect(result.contains("DEFERRABLE INITIALLY DEFERRED"))
    }

    @Test func addForeignKeyNotDeferrable() {
        let result = gen.addForeignKey(
            table: table, name: "fk_test",
            columns: ["user_id"],
            referencedSchema: "public", referencedTable: "orders",
            referencedColumns: ["id"],
            onUpdate: nil, onDelete: nil,
            isDeferrable: false, isInitiallyDeferred: false
        )
        #expect(!result.contains("DEFERRABLE"))
    }

    // MARK: - alterTableProperties

    @Test func alterTablePropertiesFillfactor() {
        let result = gen.alterTableProperties(table: table, properties: [("fillfactor", "90")])
        #expect(result.count == 1)
        #expect(result[0] == "ALTER TABLE \"public\".\"users\" SET (fillfactor = 90);")
    }

    @Test func alterTablePropertiesMultiple() {
        let result = gen.alterTableProperties(table: table, properties: [("fillfactor", "90"), ("autovacuum_enabled", "false")])
        #expect(result.count == 1)
        #expect(result[0].contains("fillfactor = 90, autovacuum_enabled = false"))
    }

    @Test func alterTablePropertiesEmpty() {
        let result = gen.alterTableProperties(table: table, properties: [])
        #expect(result.isEmpty)
    }
}

// MARK: - SQLServerDialectGenerator

@Suite("SQLServerDialectGenerator")
struct SQLServerDialectGeneratorTests {
    let gen = SQLServerDialectGenerator(schema: "dbo", database: "TestDB")

    private var table: String {
        gen.qualifiedTable(schema: "dbo", table: "users")
    }

    // MARK: quoteIdentifier

    @Test func quoteIdentifierRegularName() {
        #expect(gen.quoteIdentifier("name") == "[name]")
    }

    @Test func quoteIdentifierReservedWord() {
        #expect(gen.quoteIdentifier("SELECT") == "[SELECT]")
    }

    @Test func quoteIdentifierWithClosingBracket() {
        #expect(gen.quoteIdentifier("my]col") == "[my]]col]")
    }

    @Test func quoteIdentifierEmptyString() {
        #expect(gen.quoteIdentifier("") == "[]")
    }

    // MARK: qualifiedTable

    @Test func qualifiedTableSchemaAndTable() {
        let result = gen.qualifiedTable(schema: "dbo", table: "orders")
        #expect(result == "[dbo].[orders]")
    }

    @Test func qualifiedTableSpecialChars() {
        let result = gen.qualifiedTable(schema: "my]schema", table: "my]table")
        #expect(result == "[my]]schema].[my]]table]")
    }

    // MARK: Transaction statements

    @Test func beginTransaction() {
        #expect(gen.beginTransaction() == "BEGIN TRANSACTION;")
    }

    @Test func commitTransaction() {
        #expect(gen.commitTransaction() == "COMMIT TRANSACTION;")
    }

    @Test func rollbackTransaction() {
        #expect(gen.rollbackTransaction() == "ROLLBACK TRANSACTION;")
    }

    // MARK: dropColumn

    @Test func dropColumn() {
        let result = gen.dropColumn(table: table, column: "email")
        #expect(result == "ALTER TABLE [dbo].[users] DROP COLUMN [email];")
    }

    @Test func dropColumnNoCascade() {
        // SQL Server does not use CASCADE for drop column
        let result = gen.dropColumn(table: table, column: "col")
        #expect(!result.contains("CASCADE"))
    }

    // MARK: renameColumn

    @Test func renameColumn() {
        let result = gen.renameColumn(table: table, from: "old_name", to: "new_name")
        #expect(result == "EXEC sp_rename 'dbo.users.old_name', 'new_name', 'COLUMN';")
    }

    @Test func renameColumnStripsSquareBrackets() {
        let result = gen.renameColumn(table: "[dbo].[orders]", from: "a", to: "b")
        #expect(result.contains("dbo.orders.a"))
        #expect(!result.contains("["))
    }

    // MARK: addColumn

    @Test func addColumnNullable() {
        let result = gen.addColumn(table: table, name: "email", dataType: "nvarchar(255)", isNullable: true, defaultValue: nil, generatedExpression: nil)
        #expect(result == "ALTER TABLE [dbo].[users] ADD [email] nvarchar(255) NULL;")
    }

    @Test func addColumnNotNull() {
        let result = gen.addColumn(table: table, name: "email", dataType: "nvarchar(255)", isNullable: false, defaultValue: nil, generatedExpression: nil)
        #expect(result == "ALTER TABLE [dbo].[users] ADD [email] nvarchar(255) NOT NULL;")
    }

    @Test func addColumnWithDefault() {
        let result = gen.addColumn(table: table, name: "status", dataType: "int", isNullable: true, defaultValue: "0", generatedExpression: nil)
        #expect(result == "ALTER TABLE [dbo].[users] ADD [status] int NULL DEFAULT 0;")
    }

    @Test func addColumnWithGeneratedExpression() {
        let result = gen.addColumn(table: table, name: "full_name", dataType: "nvarchar(500)", isNullable: true, defaultValue: nil, generatedExpression: "first_name + ' ' + last_name")
        #expect(result.contains("AS (first_name + ' ' + last_name) PERSISTED"))
        #expect(!result.contains("NULL")) // computed columns don't have NULL/NOT NULL
        #expect(!result.contains("nvarchar")) // computed columns don't have data type
    }

    @Test func addColumnWithEmptyGeneratedExpression() {
        let result = gen.addColumn(table: table, name: "col", dataType: "int", isNullable: true, defaultValue: "5", generatedExpression: "  ")
        #expect(result.contains("int NULL DEFAULT 5"))
        #expect(!result.contains("PERSISTED"))
    }

    @Test func addColumnEmptyDefault() {
        let result = gen.addColumn(table: table, name: "col", dataType: "int", isNullable: false, defaultValue: "", generatedExpression: nil)
        #expect(!result.contains("DEFAULT"))
    }

    // MARK: alterColumnType

    @Test func alterColumnType() {
        let result = gen.alterColumnType(table: table, column: "age", newType: "bigint", isNullable: true)
        #expect(result == "ALTER TABLE [dbo].[users] ALTER COLUMN [age] bigint NULL;")
    }

    @Test func alterColumnTypeNotNull() {
        let result = gen.alterColumnType(table: table, column: "age", newType: "bigint", isNullable: false)
        #expect(result == "ALTER TABLE [dbo].[users] ALTER COLUMN [age] bigint NOT NULL;")
    }

    // MARK: alterColumnNullability

    @Test func alterColumnSetNullable() {
        let result = gen.alterColumnNullability(table: table, column: "email", isNullable: true, currentType: "nvarchar(255)")
        #expect(result == "ALTER TABLE [dbo].[users] ALTER COLUMN [email] nvarchar(255) NULL;")
    }

    @Test func alterColumnSetNotNull() {
        let result = gen.alterColumnNullability(table: table, column: "email", isNullable: false, currentType: "nvarchar(255)")
        #expect(result == "ALTER TABLE [dbo].[users] ALTER COLUMN [email] nvarchar(255) NOT NULL;")
    }

    // MARK: alterColumnSetDefault / dropDefault

    @Test func alterColumnSetDefault() {
        let result = gen.alterColumnSetDefault(table: table, column: "status", defaultValue: "1")
        #expect(result == "ALTER TABLE [dbo].[users] ADD CONSTRAINT [DF_status] DEFAULT 1 FOR [status];")
    }

    @Test func alterColumnDropDefault() {
        let result = gen.alterColumnDropDefault(table: table, column: "status")
        #expect(result.contains("sys.default_constraints"))
        #expect(result.contains("DROP CONSTRAINT"))
        #expect(result.contains("status"))
    }

    @Test func alterColumnDropDefaultExtractsTableName() {
        // The method parses the qualified table name to get schema and table for OBJECT_ID
        let result = gen.alterColumnDropDefault(table: "[dbo].[users]", column: "col")
        #expect(result.contains("OBJECT_ID('dbo.users')"))
    }

    @Test func alterColumnDropDefaultNoSchema() {
        let result = gen.alterColumnDropDefault(table: "mytable", column: "col")
        #expect(result.contains("OBJECT_ID('dbo.mytable')"))
    }

    // MARK: addPrimaryKey

    @Test func addPrimaryKeySingleColumn() {
        let result = gen.addPrimaryKey(table: table, name: "PK_users", columns: ["id"])
        #expect(result == "ALTER TABLE [dbo].[users] ADD CONSTRAINT [PK_users] PRIMARY KEY ([id]);")
    }

    @Test func addPrimaryKeyMultiColumn() {
        let result = gen.addPrimaryKey(table: table, name: "PK_composite", columns: ["org_id", "user_id"])
        #expect(result == "ALTER TABLE [dbo].[users] ADD CONSTRAINT [PK_composite] PRIMARY KEY ([org_id], [user_id]);")
    }

    // MARK: dropConstraint

    @Test func dropConstraint() {
        let result = gen.dropConstraint(table: table, name: "PK_users")
        #expect(result == "ALTER TABLE [dbo].[users] DROP CONSTRAINT [PK_users];")
    }

    // MARK: createIndex

    @Test func createIndexRegular() {
        let result = gen.createIndex(table: table, name: "IX_email", columns: [(name: "email", sort: "ASC")], isUnique: false, filter: nil)
        #expect(result == "CREATE INDEX [IX_email] ON [dbo].[users] ([email] ASC);")
    }

    @Test func createIndexUnique() {
        let result = gen.createIndex(table: table, name: "IX_email", columns: [(name: "email", sort: "ASC")], isUnique: true, filter: nil)
        #expect(result == "CREATE UNIQUE INDEX [IX_email] ON [dbo].[users] ([email] ASC);")
    }

    @Test func createIndexWithFilter() {
        let result = gen.createIndex(table: table, name: "IX_active", columns: [(name: "email", sort: "ASC")], isUnique: false, filter: "is_active = 1")
        #expect(result.contains("WHERE is_active = 1"))
    }

    @Test func createIndexMultiColumn() {
        let result = gen.createIndex(table: table, name: "IX_multi", columns: [(name: "a", sort: "ASC"), (name: "b", sort: "DESC")], isUnique: false, filter: nil)
        #expect(result.contains("([a] ASC, [b] DESC)"))
    }

    // MARK: dropIndex

    @Test func dropIndex() {
        let result = gen.dropIndex(schema: "dbo", name: "IX_email", table: table)
        #expect(result == "DROP INDEX [IX_email] ON [dbo].[users];")
    }

    @Test func dropIndexUsesTableNotSchema() {
        // SQL Server DROP INDEX uses ON table, not schema-qualified index name
        let result = gen.dropIndex(schema: "sales", name: "IX_test", table: "[sales].[orders]")
        #expect(result == "DROP INDEX [IX_test] ON [sales].[orders];")
        #expect(!result.contains("IF EXISTS")) // MSSQL version doesn't use IF EXISTS
    }

    // MARK: addUniqueConstraint

    @Test func addUniqueConstraintSingleColumn() {
        let result = gen.addUniqueConstraint(table: table, name: "UQ_email", columns: ["email"])
        #expect(result == "ALTER TABLE [dbo].[users] ADD CONSTRAINT [UQ_email] UNIQUE ([email]);")
    }

    @Test func addUniqueConstraintMultiColumn() {
        let result = gen.addUniqueConstraint(table: table, name: "UQ_combo", columns: ["first", "last"])
        #expect(result == "ALTER TABLE [dbo].[users] ADD CONSTRAINT [UQ_combo] UNIQUE ([first], [last]);")
    }

    // MARK: addForeignKey

    @Test func addForeignKeySimple() {
        let result = gen.addForeignKey(
            table: table, name: "FK_user_order",
            columns: ["order_id"],
            referencedSchema: "dbo", referencedTable: "orders",
            referencedColumns: ["id"],
            onUpdate: nil, onDelete: nil
        )
        #expect(result.contains("FOREIGN KEY ([order_id]) REFERENCES [dbo].[orders] ([id])"))
        #expect(!result.contains("ON UPDATE"))
        #expect(!result.contains("ON DELETE"))
        #expect(result.hasSuffix(";"))
    }

    @Test func addForeignKeyWithActions() {
        let result = gen.addForeignKey(
            table: table, name: "FK_user_order",
            columns: ["order_id"],
            referencedSchema: "dbo", referencedTable: "orders",
            referencedColumns: ["id"],
            onUpdate: "CASCADE", onDelete: "SET NULL"
        )
        #expect(result.contains("ON UPDATE CASCADE"))
        #expect(result.contains("ON DELETE SET NULL"))
    }

    @Test func addForeignKeyMultiColumn() {
        let result = gen.addForeignKey(
            table: table, name: "FK_multi",
            columns: ["org_id", "dept_id"],
            referencedSchema: "dbo", referencedTable: "departments",
            referencedColumns: ["org_id", "id"],
            onUpdate: nil, onDelete: "CASCADE"
        )
        #expect(result.contains("([org_id], [dept_id])"))
        #expect(result.contains("([org_id], [id])"))
        #expect(!result.contains("ON UPDATE"))
        #expect(result.contains("ON DELETE CASCADE"))
    }

    @Test func addForeignKeyEmptyActions() {
        let result = gen.addForeignKey(
            table: table, name: "FK_test",
            columns: ["col"],
            referencedSchema: "dbo", referencedTable: "ref",
            referencedColumns: ["id"],
            onUpdate: "", onDelete: ""
        )
        #expect(!result.contains("ON UPDATE"))
        #expect(!result.contains("ON DELETE"))
    }

    // MARK: - addColumn: identity & collation

    @Test func addColumnWithIdentity() {
        let result = gen.addColumn(table: table, name: "id", dataType: "int", isNullable: false, defaultValue: nil, generatedExpression: nil, identity: (seed: 1, increment: 1, generation: nil), collation: nil)
        #expect(result.contains("IDENTITY(1, 1)"))
    }

    @Test func addColumnWithIdentitySeedIncrement() {
        let result = gen.addColumn(table: table, name: "id", dataType: "int", isNullable: false, defaultValue: nil, generatedExpression: nil, identity: (seed: 100, increment: 10, generation: nil), collation: nil)
        #expect(result.contains("IDENTITY(100, 10)"))
    }

    @Test func addColumnWithCollation() {
        let result = gen.addColumn(table: table, name: "name", dataType: "nvarchar(255)", isNullable: true, defaultValue: nil, generatedExpression: nil, identity: nil, collation: "Latin1_General_CI_AS")
        #expect(result.contains("COLLATE Latin1_General_CI_AS"))
        #expect(!result.contains("\"")) // MSSQL collation has no quotes
    }

    @Test func addColumnIdentitySkipsDefault() {
        let result = gen.addColumn(table: table, name: "id", dataType: "int", isNullable: false, defaultValue: "0", generatedExpression: nil, identity: (seed: 1, increment: 1, generation: nil), collation: nil)
        #expect(!result.contains("DEFAULT"))
        #expect(result.contains("IDENTITY(1, 1)"))
    }

    // MARK: - createIndex: includeColumns & indexType

    @Test func createIndexWithIncludeColumns() {
        let result = gen.createIndex(table: table, name: "IX_test", columns: [(name: "col1", sort: "ASC")], includeColumns: ["col3", "col4"], isUnique: false, filter: nil, indexType: nil)
        #expect(result.contains("INCLUDE ([col3], [col4])"))
    }

    @Test func createIndexIgnoresIndexType() {
        let result = gen.createIndex(table: table, name: "IX_test", columns: [(name: "col1", sort: "ASC")], includeColumns: [], isUnique: false, filter: nil, indexType: "gin")
        #expect(!result.contains("USING"))
    }

    // MARK: - addCheckConstraint

    @Test func addCheckConstraintSimple() {
        let result = gen.addCheckConstraint(table: table, name: "CK_age", expression: "age >= 0")
        #expect(result == "ALTER TABLE [dbo].[users] ADD CONSTRAINT [CK_age] CHECK (age >= 0);")
    }

    // MARK: - addPrimaryKey: ignores deferrable

    @Test func addPrimaryKeyIgnoresDeferrable() {
        let result = gen.addPrimaryKey(table: table, name: "PK_users", columns: ["id"], isDeferrable: true, isInitiallyDeferred: true)
        #expect(!result.contains("DEFERRABLE"))
    }

    // MARK: - addUniqueConstraint: ignores deferrable

    @Test func addUniqueConstraintIgnoresDeferrable() {
        let result = gen.addUniqueConstraint(table: table, name: "UQ_email", columns: ["email"], isDeferrable: true, isInitiallyDeferred: true)
        #expect(!result.contains("DEFERRABLE"))
    }

    // MARK: - addForeignKey: ignores deferrable

    @Test func addForeignKeyIgnoresDeferrable() {
        let result = gen.addForeignKey(
            table: table, name: "FK_test",
            columns: ["col"],
            referencedSchema: "dbo", referencedTable: "ref",
            referencedColumns: ["id"],
            onUpdate: nil, onDelete: nil,
            isDeferrable: true, isInitiallyDeferred: true
        )
        #expect(!result.contains("DEFERRABLE"))
    }

    // MARK: - alterTableProperties

    @Test func alterTablePropertiesCompression() {
        let result = gen.alterTableProperties(table: table, properties: [("DATA_COMPRESSION", "PAGE")])
        #expect(result.count == 1)
        #expect(result[0].contains("REBUILD WITH (DATA_COMPRESSION = PAGE)"))
    }

    @Test func alterTablePropertiesLockEscalation() {
        let result = gen.alterTableProperties(table: table, properties: [("LOCK_ESCALATION", "AUTO")])
        #expect(result.count == 1)
        #expect(result[0].contains("SET (LOCK_ESCALATION = AUTO)"))
    }

    @Test func alterTablePropertiesEmpty() {
        let result = gen.alterTableProperties(table: table, properties: [])
        #expect(result.isEmpty)
    }
}

// MARK: - MySQLDialectGenerator

@Suite("MySQLDialectGenerator")
struct MySQLDialectGeneratorTests {
    let gen = MySQLDialectGenerator(schema: "sakila")

    private var table: String {
        gen.qualifiedTable(schema: "sakila", table: "actor")
    }

    @Test func quoteIdentifierRegularName() {
        #expect(gen.quoteIdentifier("name") == "`name`")
    }

    @Test func qualifiedTableSchemaAndTable() {
        #expect(table == "`sakila`.`actor`")
    }

    @Test func beginTransaction() {
        #expect(gen.beginTransaction() == "START TRANSACTION;")
    }

    @Test func addColumnWithAutoIncrement() {
        let result = gen.addColumn(
            table: table,
            name: "actor_id",
            dataType: "int",
            isNullable: false,
            defaultValue: nil,
            generatedExpression: nil,
            identity: (seed: 1, increment: 1, generation: "AUTO_INCREMENT"),
            collation: nil
        )
        #expect(result == "ALTER TABLE `sakila`.`actor` ADD COLUMN `actor_id` int NOT NULL AUTO_INCREMENT;")
    }

    @Test func addColumnWithGeneratedExpression() {
        let result = gen.addColumn(
            table: table,
            name: "full_name",
            dataType: "varchar(255)",
            isNullable: true,
            defaultValue: "'fallback'",
            generatedExpression: "concat(first_name, ' ', last_name)",
            identity: nil,
            collation: nil
        )
        #expect(result.contains("GENERATED ALWAYS AS (concat(first_name, ' ', last_name)) STORED"))
        #expect(!result.contains("DEFAULT"))
    }

    @Test func alterColumnTypeUsesModifyColumn() {
        let result = gen.alterColumnType(table: table, column: "first_name", newType: "varchar(100)", isNullable: false)
        #expect(result == "ALTER TABLE `sakila`.`actor` MODIFY COLUMN `first_name` varchar(100) NOT NULL;")
    }

    @Test func addPrimaryKeyOmitsConstraintName() {
        let result = gen.addPrimaryKey(table: table, name: "PRIMARY", columns: ["actor_id"], isDeferrable: false, isInitiallyDeferred: false)
        #expect(result == "ALTER TABLE `sakila`.`actor` ADD PRIMARY KEY (`actor_id`);")
    }

    @Test func dropConstraintPrimaryKey() {
        #expect(gen.dropConstraint(table: table, name: "PRIMARY") == "ALTER TABLE `sakila`.`actor` DROP PRIMARY KEY;")
    }

    @Test func dropConstraintForeignKey() {
        #expect(gen.dropConstraint(table: table, name: "fk_actor") == "ALTER TABLE `sakila`.`actor` DROP FOREIGN KEY `fk_actor`;")
    }

    @Test func createUniqueIndexWithIndexType() {
        let result = gen.createIndex(
            table: table,
            name: "idx_actor_name",
            columns: [(name: "last_name", sort: "ASC")],
            includeColumns: [],
            isUnique: true,
            filter: nil,
            indexType: "hash"
        )
        #expect(result == "CREATE UNIQUE INDEX `idx_actor_name` ON `sakila`.`actor` USING HASH (`last_name` ASC);")
    }

    @Test func alterTablePropertiesBuildsExpectedStatements() {
        let result = gen.alterTableProperties(
            table: table,
            properties: [("ENGINE", "InnoDB"), ("AUTO_INCREMENT", "42"), ("CHARACTER SET", "utf8mb4")]
        )
        #expect(result.count == 2)
        #expect(result[0] == "ALTER TABLE `sakila`.`actor` ENGINE = InnoDB, AUTO_INCREMENT = 42;")
        #expect(result[1] == "ALTER TABLE `sakila`.`actor` CONVERT TO CHARACTER SET utf8mb4;")
    }
}
