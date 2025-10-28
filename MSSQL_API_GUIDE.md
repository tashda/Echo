# SQLServerKit API Usage Guide for Echo

## Overview

Your Echo application uses SQLServerKit (from `/Users/k/Development/sqlserver-nio`) to connect to Microsoft SQL Server databases. This guide explains the proper API usage based on your current implementation.

## Connection Architecture

### 1. Connection Setup (`MSSQLNIOFactory`)

```swift
let configuration = SQLServerConnection.Configuration(
    hostname: host,
    port: port,
    login: .init(database: databaseName, authentication: login),
    tlsConfiguration: tls ? TLSConfiguration.makeClientConfiguration() : nil,
    metadataConfiguration: metadataConfiguration
)

let connection = try await SQLServerConnection.connect(
    configuration: configuration,
    eventLoopGroupProvider: .createNew(numberOfThreads: 1),
    logger: logger
).get()
```

**Key Points:**
- `SQLServerConnection` is the main connection type
- Metadata configuration controls what system objects are included
- Connection returns an `EventLoopFuture` that you `.get()` to await

### 2. Metadata Client Configuration

```swift
var metadataConfiguration = SQLServerMetadataClient.Configuration()
metadataConfiguration.includeSystemSchemas = false
metadataConfiguration.includeSystemObjects = false
```

**Purpose:** Controls filtering of system databases, schemas, and objects

## SQLServerKit Metadata API Methods

Your `MSSQLSession` class wraps `SQLServerConnection` and uses these metadata methods:

### Database Operations

```swift
// List all databases on the server
let databases = try await connection.listDatabases()
// Returns: [DatabaseMetadata]
// Properties: name, isSystemDatabase, state, etc.
```

### Schema Operations

```swift
// List schemas in a database
let schemas = try await connection.listSchemas(in: databaseName)
// Returns: [SchemaMetadata]
```

### Table Operations

```swift
// List tables and views in a schema
let tables = try await connection.listTables(database: databaseName, schema: schemaName)
// Returns: [TableMetadata]
// Properties: name, schema, type, isSystemObject
```

### Column Operations

```swift
// List columns for a table
let columns = try await connection.listColumns(database: databaseName, schema: schemaName, table: tableName)
// Returns: [ColumnMetadata]
// Properties: name, typeName, maxLength, precision, scale, isNullable, ordinalPosition
```

### Constraint Operations

```swift
// Primary keys
let primaryKeys = try await connection.listPrimaryKeys(database: databaseName, schema: schemaName, table: tableName)
// Returns: [KeyConstraintMetadata]

// Unique constraints
let uniqueConstraints = try await connection.listUniqueConstraints(database: databaseName, schema: schemaName, table: tableName)
// Returns: [KeyConstraintMetadata]

// Foreign keys
let foreignKeys = try await connection.listForeignKeys(database: databaseName, schema: schemaName, table: tableName)
// Returns: [ForeignKeyMetadata]
```

### Index Operations

```swift
// List indexes
let indexes = try await connection.listIndexes(database: databaseName, schema: schemaName, table: tableName)
// Returns: [IndexMetadata]
```

### Routine Operations

```swift
// List functions
let functions = try await connection.listFunctions(database: databaseName, schema: schemaName)
// Returns: [RoutineMetadata]

// List stored procedures
let procedures = try await connection.listProcedures(database: databaseName, schema: schemaName)
// Returns: [RoutineMetadata]

// List parameters for a routine
let parameters = try await connection.listParameters(database: databaseName, schema: schemaName, object: objectName)
// Returns: [ParameterMetadata]
```

### Trigger Operations

```swift
// List triggers
let triggers = try await connection.listTriggers(database: databaseName, schema: schemaName)
// Returns: [TriggerMetadata]
```

### Dependency Operations

```swift
// List object dependencies
let dependencies = try await connection.listDependencies(database: databaseName, schema: schemaName, object: objectName)
// Returns: [DependencyMetadata]
```

## Query Execution

### Streaming Queries

```swift
for try await event in connection.streamQuery(sql) {
    switch event {
    case .metadata(let metadata):
        // Column metadata
    case .row(let row):
        // Data row (TDSRow)
    case .done(let done):
        // Query completion
    case .message(let message):
        // Info/error messages
    }
}
```

### Simple Queries

```swift
_ = try await connection.query(sql)
```

## Error Handling

```swift
catch let sqlError as SQLServerError {
    if case .connectionClosed = sqlError {
        throw MSSQLSessionError.connectionClosed
    }
    throw DatabaseError.queryError(sqlError.description)
}
```

## Current Implementation Issues

### Issue 1: Database Listing

**Problem:** Only showing 2 databases instead of 5

**Root Cause:** The `listDatabases()` implementation was using manual SQL queries instead of the SQLServerKit API

**Solution:** Updated to use `connection.listDatabases()` which properly queries the server's database catalog

```swift
func listDatabases() async throws -> [String] {
    let databases = try await connection.listDatabases()
    let names = databases
        .filter { !$0.isSystemDatabase }
        .map { $0.name }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    return names
}
```

### Issue 2: Metadata Configuration

**Problem:** `includeSystemObjects` property might not have been set

**Solution:** Explicitly set both system filtering options:

```swift
metadataConfiguration.includeSystemSchemas = false
metadataConfiguration.includeSystemObjects = false
```

## Testing Your Changes

1. **Build the project** to ensure no compilation errors
2. **Connect to your MSSQL server** with 5 databases
3. **Check the logs** for:
   - "MSSQL listDatabases found X user databases: [...]"
   - Verify X = 5 and all database names are listed
4. **Verify in UI** that all 5 databases appear in the database selector

## Debugging Tips

### Enable Verbose Logging

The logger is already configured. Check console output for:
- Connection establishment
- Database enumeration
- Metadata queries
- Error messages

### Common Issues

1. **Permission Issues**: User needs `VIEW ANY DATABASE` permission
2. **Database State**: Databases must be ONLINE
3. **System Databases**: Filtered by `isSystemDatabase` property
4. **Connection Context**: Ensure you're not filtering by current database context

### Verify Database Permissions

Run this query to check what databases the user can see:

```sql
SELECT name, state_desc, user_access_desc 
FROM sys.databases 
WHERE state_desc = 'ONLINE'
ORDER BY name;
```

## Next Steps

1. Test the updated `listDatabases()` implementation
2. Verify all 5 databases appear
3. Check that tables/objects load correctly for each database
4. Monitor performance of metadata queries

## API Reference

For complete API documentation, refer to the SQLServerKit package at:
`/Users/k/Development/sqlserver-nio`

Key types to understand:
- `SQLServerConnection` - Main connection class
- `DatabaseMetadata` - Database information
- `TableMetadata` - Table/view information
- `ColumnMetadata` - Column information
- `SQLServerError` - Error types
