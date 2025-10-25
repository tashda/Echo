SQLServerNIO is a non-blocking Swift client for Microsoft SQL Server. It builds on the original SwiftTDS (tds-nio) project and the SwiftNIO networking stack.

- `SQLServerConnection` gives you fine-grained control over a single TDS session.
- `SQLServerClient` manages pooled connections with retries and metadata caching.
- Async/await-first APIs with convenient futures-based overloads for legacy code.
- Metadata helpers (databases, schemas, tables, columns) with safe fallbacks.
- Additional clients for administrative tasks and SQL Agent workflows.


## Installation

Add the dependency to `Package.swift`:

```swift
.package(url: "https://github.com/sqlserver-nio/sqlserver-nio.git", from: "0.1.0")
```

Then add the product to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "SQLServerNIO", package: "sqlserver-nio")
    ]
)
```

## Quick Start

### Pooled client

```swift
import SQLServerNIO

let configuration = SQLServerClient.Configuration(
    hostname: "localhost",
    port: 1433,
    login: .init(
        database: "master",
        authentication: .sqlPassword(username: "sa", password: "StrongPassword123")
    ),
    tlsConfiguration: nil
)

let client = try await SQLServerClient.connect(configuration: configuration)
let rows = try await client.query("SELECT @@VERSION AS version;")
print(rows.first?.column("version")?.string ?? "<unknown>")
try await client.shutdownGracefully()
```

### Single connection

```swift
let single = try await SQLServerConnection.connect(configuration: configuration.connection)
let databases = try await single.listDatabases()
try await single.close()
```

## Connection Configuration

`SQLServerConnection.Configuration` lets you specify hostname, port, database, authentication, TLS, metadata caching, retry behaviour, and session defaults.

Session defaults mirror SQL Server Management Studio (ANSI settings, `SET NOCOUNT ON`, `SET FMTONLY OFF`) and can be customised via `SessionOptions`:

```swift
var configuration = makeSQLServerClientConfiguration()
configuration.connection.sessionOptions = .init(
    nocount: false,
    fmtOnlyOff: true,
    additionalStatements: ["SET DEADLOCK_PRIORITY LOW;"]
)
```

## Querying

### Async/await

```swift
let rows = try await client.query("SELECT name FROM sys.databases ORDER BY name;")
for row in rows {
    print(row.column("name")?.string ?? "<unknown>")
}
```

### Futures

```swift
client.query("SELECT COUNT(*) AS count FROM sys.tables;").whenSuccess { rows in
    print(rows.first?.column("count")?.int ?? 0)
}
```

### Execute with row counts

```swift
let result = try await client.execute("INSERT INTO Logs(Message) VALUES (N'hello');")
print("rows: \(result.totalRowCount)")
```

`execute(_:)` returns an `SQLServerExecutionResult`, exposing the rows (if any), informational messages, and `UInt64` row counts for each DONE token.

### Scalar helpers

```swift
let databaseName: String? = try await client.queryScalar("SELECT DB_NAME();", as: String.self)
```

The scalar helper bridges to `TDSDataConvertible`, so you can request `String`, `Int`, `UUID`, etc.

### Changing databases

```swift
try await connection.changeDatabase("msdb")
print(connection.currentDatabase) // "msdb"
```

Connections keep track of the active database and automatically switch back to the original catalog when returned to the pool.

### Streaming (AsyncSequence)

**Single connection**

```swift
for try await event in connection.streamQuery("SELECT TOP (5) name FROM sys.databases ORDER BY name;") {
    switch event {
    case .metadata(let columns):
        let columnNames = columns.map(\.name)
        print("Columns: \(columnNames)")
    case .row(let row):
        print(row.column("name")?.string ?? "<nil>")
    case .done(let done):
        print("batch complete rows=\(done.rowCount)")
    case .message(let message):
        print("message: \(message.message)")
    }
}
```

**Via the pooled client**

```swift
try await client.withConnection { connection in
    for try await event in connection.streamQuery("SELECT TOP (5) name FROM sys.databases ORDER BY name;") {
        switch event {
        case .metadata(let columns):
            let columnNames = columns.map(\.name)
            print("Columns: \(columnNames)")
        case .row(let row):
            print(row.column("name")?.string ?? "<nil>")
        case .done(let done):
            print("batch complete rows=\(done.rowCount)")
        case .message(let message):
            print("message: \(message.message)")
        }
    }
}
```

```Note:``` cancel either loop to stop early; the underlying connection is returned to the pool (or left open for you) once the sequence completes or is cancelled.

### Parameterised SQL

Use string interpolation for safe parameter binding:

```swift
let dbName = "AdventureWorks2022"
try await client.query(
    """
    IF DB_ID(\(dbName)) IS NULL CREATE DATABASE \(dbName);
    """
)
```

## Metadata Helpers

SQLServerNIO ships with a full metadata surface so application code no longer needs to hit `INFORMATION_SCHEMA` or `sys.*` directly.

- `listColumns` covers tables *and* views, exposing identity/computed flags, default definitions, collation, and ordinal position. Driver-internal artifacts (`meta_client_%`) are filtered automatically.
- `listParameters` returns stored procedure & function parameters (return values are flagged via `isReturnValue`).
- `listPrimaryKeys`, `listUniqueConstraints`, `listIndexes`, and `listForeignKeys` capture relational structure including column order, sort direction, included columns, and referential actions.
- `listDependencies` reports referencing objects (views, procedures, triggers, etc.) so you can build dependency graphs without custom SQL.
- `listProcedures`, `listFunctions`, and `listTriggers` list routines/triggers with system/shipped flags; set `metadataConfiguration.includeRoutineDefinitions = true` to hydrate definitions while listing.
- Database and parameter metadata flows through Microsoft’s stored procedures (`sp_databases`, `sp_sproc_columns_100`, `sp_fkeys`, etc.). Schema/table listings read from `sys.schemas`, `sys.tables`, and `sys.views` so they stay available even on SQL Server editions that omit the legacy `sp_schemata` procedure.

```swift
// Columns (tables & views)
let columns = try await client.listColumns(schema: "dbo", table: "Employees")
for column in columns {
    print("\(column.name) \(column.typeName) default=\(column.defaultDefinition ?? "<none>")")
}

// Procedure / function parameters
let parameters = try await client.listParameters(schema: "dbo", object: "usp_UpdateEmployee")
let inputs = parameters.filter { !$0.isReturnValue }

// Keys & indexes
let primaryKeys = try await client.listPrimaryKeys(schema: "dbo", table: "Employees")
let indexes = try await client.listIndexes(schema: "dbo", table: "EmployeeAudit")

// Foreign keys & dependencies
let foreignKeys = try await client.listForeignKeys(schema: "dbo", table: "EmployeeAudit")
let dependencies = try await client.listDependencies(schema: "dbo", object: "Employees")

// Routines & triggers
let procedures = try await client.listProcedures(schema: "dbo")
let functions = try await client.listFunctions(schema: "dbo")
let triggers = try await client.listTriggers(schema: "dbo", table: "EmployeeAudit")
```

> Routine listings return core metadata by default. Enable definition hydration by toggling the metadata configuration:

```swift
var clientConfig = makeSQLServerClientConfiguration()
clientConfig.connection.metadataConfiguration.includeRoutineDefinitions = true
let client = try await SQLServerClient.connect(configuration: clientConfig)

let procedures = try await client.listProcedures(schema: "dbo") // definitions populated
```

### Object definitions

When you need the full module text, use the definition helpers. They work with procedures, functions, views, and triggers, and report the SQL Server system flag so you can filter Microsoft-shipped objects.

```swift
let identifiers = [
    SQLServerMetadataObjectIdentifier(database: nil, schema: "dbo", name: "usp_ReportSales", kind: .procedure),
    SQLServerMetadataObjectIdentifier(database: nil, schema: "dbo", name: "vw_Sales", kind: .view)
]

let definitions = try await client.fetchObjectDefinitions(identifiers)

let single = try await client.fetchObjectDefinition(schema: "dbo", name: "usp_ReportSales", kind: .procedure)
print(single?.definition)
```

### Metadata search

Search across object names, definitions, columns, indexes, and constraints without crafting raw SQL:

```swift
let hits = try await client.searchMetadata(
    query: "Customer",
    scopes: [.objectNames, .definitions, .columns]
)

for hit in hits {
    print("\(hit.matchKind): \(hit.schema).\(hit.name) -> \(hit.detail ?? "")")
}
```

## Administration Helpers

```swift
let admin = SQLServerAdministrationClient(client: client)
let logins = try await admin.listServerLogins()
```

## SQL Agent Helpers

```swift
let agent = SQLServerAgentClient(client: client)
let jobs = try await agent.listJobs()
```

## Error Handling & Retries


Errors surface as `SQLServerError`:

- `.authenticationFailed`
- `.connectionClosed`
- `.timeout(description:underlying:)`
- `.protocol(TDSError)`
- `.transient(Error)`
- `.unknown(Error)`

Configure retries via `SQLServerRetryConfiguration` on your connection/client configuration.

## Testing

1. Copy `.env.example` to `.env` and adjust credentials.
2. Start a SQL Server instance locally or via `docker/scripts/docker-compose.yml`.
3. Enable the suites you want using the `TDS_ENABLE_*` flags in `.env`.
4. Run `swift test` or open `SQLServerNIO.xctestplan` in Xcode.

```
TDS_HOSTNAME=127.0.0.1 TDS_PORT=1433 TDS_DATABASE=master TDS_USERNAME=sa TDS_PASSWORD=StrongPassword123! swift test
```

`SQLServerNIO.xctestplan` includes configurations for core, admin, and SQL Agent suites. Use environment flags such as `TDS_HOSTNAME`, `TDS_PORT`, `TDS_USERNAME`, `TDS_PASSWORD`, `TDS_DATABASE`, `TDS_ENABLE_SCHEMA_TESTS`, and `TDS_ENABLE_AGENT_TESTS`.

## Contributing

Issues and pull requests welcome. See `Docs/API_Audit.md` and `Docs/Roadmap.md` for active work. Security concerns? Please reach out privately.

## License

MIT. See [LICENSE].

[SwiftNIO]: https://github.com/apple/swift-nio
