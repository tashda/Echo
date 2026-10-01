import SQLServerKit

/// Shorthand for the tables the SQL Server suites make through sqlserver-nio instead of SQL text.
extension SQLServerColumnDefinition {
    /// A column as `CREATE TABLE` makes it by default: nullable unless it is the primary key.
    static func column(
        _ name: String,
        _ type: SQLDataType,
        primaryKey: Bool = false,
        nullable: Bool? = nil,
        identity: (seed: Int, increment: Int)? = nil,
        default defaultValue: String? = nil
    ) -> SQLServerColumnDefinition {
        SQLServerColumnDefinition(name: name, definition: .standard(.init(
            dataType: type,
            isNullable: nullable ?? !primaryKey,
            isPrimaryKey: primaryKey,
            identity: identity,
            defaultValue: defaultValue
        )))
    }
}

extension MSSQLLabTestCase {
    /// Makes a table in the suite's scratch database through sqlserver-nio.
    func createTable(_ name: String, schema: String = "dbo", _ columns: [SQLServerColumnDefinition]) async throws {
        try await sqlserverClient.withConnection { connection in
            try await connection.createTable(name: name, columns: columns, schema: schema)
        }
    }
}
