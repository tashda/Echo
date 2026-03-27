# mysql-wire Package Plan

> Created: 2026-03-26
> Status: Package Complete, Echo Integration In Progress
> Related: `MYSQL_WORKBENCH_REPLACEMENT_ANALYSIS.md`, `MYSQL_WORKBENCH_FEATURE_INVENTORY.md`

## Implementation Progress

### Completed so far
- Package scaffold created at `/Users/k/Development/mysql-wire` with `MySQLWire` and `MySQLKit` targets
- Native async `MySQLWireConnection` wrapper built on top of `mysql-nio`
- `MySQLServerConnection` implemented with primary, metadata, activity, dedicated, and cancel-query connection flows
- `MySQLKit.query` namespace implemented for simple query, prepared query, streaming, and transaction entry points
- `MySQLKit.bulk` implemented for typed batched inserts plus import/export command generation
- `MySQLDedicatedSession` implemented for independent query-tab style sessions
- `MySQLKit.metadata` implemented for databases, schema objects, columns, object definitions, and table structure
- `MySQLKit.metadata` expanded for routines, triggers, events, and cross-object search
- `MySQLKit.metadata` expanded with convenience table/view/function/procedure listing APIs
- `MySQLKit.admin` implemented for global status, global variables, process list, kill query, and maintenance commands
- `MySQLKit.admin` expanded for DDL execution across tables, views, routines, triggers, and events, plus log discovery/table-log reads and backup command generation
- `MySQLKit.admin` expanded for global variable mutation, repair/flush maintenance, restore command generation, and configurable dump/import options
- `MySQLKit.security` implemented for user listing, `SHOW GRANTS`, role assignments, and table privilege inspection
- `MySQLKit.security` expanded for user/role mutation plus GRANT/REVOKE helpers
- `MySQLKit.security` expanded for password rotation, account locking, role grant/revoke, and default-role assignment
- `MySQLKit.security` expanded for per-account limits plus Workbench-style administrative role grant/revoke/detection helpers
- `MySQLKit.session` implemented for current user/database inspection, session variables, isolation level, and named locks
- `MySQLKit.activity` implemented for typed snapshots and polling stream
- `MySQLKit.performance` implemented for `EXPLAIN`, dashboard status, and generic report surfaces
- `MySQLKit.performance` expanded for runtime/full-scan reports, wait/host reports, and InnoDB status
- `MySQLKit.performance` expanded with schema index/table statistics and wait-latency report access
- `MySQLKit.replication` implemented for typed `SHOW REPLICA STATUS` and primary status access
- `PreparedStatementCache` implemented for LRU statement tracking
- Prepared query execution now uses cached SQL `PREPARE` / `EXECUTE` lifecycle at the `MySQLKit` layer
- `MySQLConnectionHealthPolicy` implemented for reconnect/close classification
- `MySQLKitTesting` target added with fixture/test configuration helpers
- Swift Testing coverage added for configuration, connection routing, metadata, admin, and security

### In progress now
- Echo feature parity work on top of the shipped `mysql-wire` package
- Echo migration from raw MySQL admin SQL toward typed `mysql-wire` admin/activity/security APIs
- Echo backup/restore tooling on top of `mysql-wire` command-generation helpers

### Still remaining after current work
- Complete Echo-side feature wiring for activity monitoring, administration, security management, backup/restore, and schema tooling

## Current State

The package milestone is effectively complete:
- `mysql-wire` exists as a standalone repository at `/Users/k/Development/mysql-wire`
- package APIs now cover query, metadata, admin, security, session, activity, performance, replication, and testing support
- Echo no longer depends on direct `MySQLNIO` for its primary MySQL dialect adapter

The remaining work for the broader MySQL plan is now in Echo:
- migrate MySQL UI features from raw SQL and placeholders onto `mysql-wire`
- close the remaining Workbench-replacement feature gaps

## The Decision: Fork mysql-nio + Restructure to Match postgres-wire Pattern

**Don't start from scratch. Don't copy mysql-nio as-is either.**

Fork Vapor's `mysql-nio` as the **wire protocol foundation**, then build a `MySQLKit` layer on top following the exact postgres-wire architecture. Here's why:

### What mysql-nio does well (keep)
- Packet framing (4-byte header, sequence IDs, little-endian encoding) — **solid, tested**
- TLS/SSL negotiation — **works**
- HandshakeV10 protocol — **correct**
- `mysql_native_password` and `caching_sha2_password` auth — **the two auth plugins that matter for 99% of users**
- `COM_QUERY` (text protocol) and `COM_STMT_PREPARE/EXECUTE/CLOSE` (binary protocol) — **both implemented**
- 28 MySQL data type encoders/decoders — **comprehensive**
- ColumnDefinition41 parsing — **correct**
- Binary result set row decoding with null bitmap — **correct**

### What mysql-nio does poorly (replace/extend)
- **No async/await** — everything returns `EventLoopFuture`. We need native async.
- **No connection management** — single connection only, no keepalive, no reconnect, no multi-connection coordination.
- **No prepared statement caching** — prepares and closes every query. We need an LRU cache.
- **No streaming** — rows collected in memory or via callback. We need `AsyncSequence`.
- **No typed metadata APIs** — no `listTables()`, `listColumns()`. Raw SQL only.
- **No `COM_PING`** — can't health-check connections for keepalive.
- **No `COM_RESET_CONNECTION`** — can't reuse connections cleanly.
- **No `COM_INIT_DB`** — can't switch database without `USE`.
- **No backpressure** — large result sets buffer entirely in memory.
- **No connection attributes** — can't send client name/version to server.
- **Hardcoded charset** — always utf8mb4, no negotiation.

### What we build new (the MySQLKit layer)
- Full typed API matching postgres-wire's namespace pattern
- Dedicated connection management with keepalive and reconnect (not a pool — see Connection Model below)
- Prepared statement LRU cache per connection
- Streaming result sets via `AsyncThrowingStream`
- Activity monitoring via `SHOW PROCESSLIST` + Performance Schema
- All the admin/security/metadata namespaces the Workbench replacement needs

---

## Connection Model: Dedicated Connections, Not a Pool

**This is the most important architectural decision in the package.**

### Why Not a Connection Pool

The MySQL protocol is **half-duplex and strictly sequential** — one command per connection at a time. A connection IS a session. It carries:

- Transaction state (uncommitted work, locks)
- Session variables (`SET @var`, `SET SESSION`)
- Temporary tables
- Prepared statements (server-side, tied to connection ID)
- Selected database (`USE db`)
- Character set/collation
- `LAST_INSERT_ID()`, `FOUND_ROWS()`
- Advisory locks (`GET_LOCK()`)

**Every production MySQL GUI client uses dedicated long-lived connections, not pools:**

| Client | Model |
|---|---|
| MySQL Workbench | 3-4 dedicated connections per tab (query, schema, autocomplete, admin) |
| DBeaver | 1 per editor + 1 for metadata navigator |
| DataGrip | 1 per console + 1 for introspection |
| Navicat | 1 per tab + 1 for nav tree + extras for background ops |
| Sequel Ace | 1 per window (shared for everything — causes UI freezes) |

Connection pooling is for web servers where each HTTP request is stateless. A desktop GUI client is the opposite — each tab is a persistent, stateful session. Pooling would silently lose session state between queries and break user expectations.

### Echo's MySQL Connection Architecture

```
ConnectionSession (one per server connection in sidebar)
├── Primary Connection         — user queries, carries all session state
│                                (transactions, temp tables, variables, selected DB)
├── Metadata Connection        — object browser, autocomplete, schema loading
│                                (COM_RESET_CONNECTION between uses, no user state)
├── Cancel Connection          — opened on-demand to send KILL QUERY <thread_id>
│                                (short-lived, created when needed, destroyed after)
└── Activity Connection        — SHOW PROCESSLIST polling, performance metrics
                                 (optional, only when activity monitor tab is open)
```

**Rules:**
- The Primary Connection is NEVER shared or reset. It is the user's session.
- The Metadata Connection is reset (`COM_RESET_CONNECTION`) between metadata operations to avoid state leaks. It always does `USE <db>` before each operation.
- Cancel Connection is ephemeral — connect, send `KILL QUERY <id>`, disconnect.
- Activity Connection is only created when the user opens Activity Monitor.
- Each additional query tab that needs independent execution gets its own connection (mirrors DataGrip's "separate console" model and Echo's existing MSSQL dedicated session pattern).

### MySQLServerConnection (Multi-Connection Manager)

```swift
public actor MySQLServerConnection: Sendable {
    private let config: MySQLConfiguration
    private var primaryConnection: MySQLWireConnection?
    private var metadataConnection: MySQLWireConnection?
    private var activityConnection: MySQLWireConnection?

    /// The user's query session — carries all state
    public func primary() async throws -> MySQLWireConnection

    /// A clean connection for metadata operations — reset between uses
    public func metadata() async throws -> MySQLWireConnection

    /// Opens a fresh connection, sends KILL QUERY, closes it
    public func cancelQuery(threadID: UInt32) async throws

    /// Connection for activity monitoring (lazy, only when needed)
    public func activity() async throws -> MySQLWireConnection

    /// Create a new dedicated connection for a query tab
    public func newDedicatedConnection() async throws -> MySQLWireConnection

    /// Keepalive — sends COM_PING on idle connections
    public func ping() async throws

    /// Close all connections
    public func close() async
}
```

### Connection Health

- **Keepalive:** `COM_PING` sent periodically (configurable, default 300s) on idle connections to prevent `wait_timeout` server-side disconnection.
- **Reconnect:** If a connection dies (error 2006 "MySQL server has gone away" or error 2013 "Lost connection during query"), the connection is marked dead. On next use, a new connection is established. **Session state is lost** — this is unavoidable with MySQL. Echo shows a notification: "Connection was lost and re-established. Session state (variables, temp tables, transactions) was reset."
- **Validation:** Before returning a metadata connection to "idle" after use, send `COM_PING` to verify it's still alive.

---

## Package Architecture

```
mysql-wire/
├── Package.swift
├── Sources/
│   ├── MySQLWire/                    # Low-level wire protocol (forked from mysql-nio)
│   │   ├── Protocol/                 # Packet types (COM_*, handshake, auth, etc.)
│   │   │   ├── MySQLPacket.swift
│   │   │   ├── MySQLPacketDecoder.swift
│   │   │   ├── MySQLPacketEncoder.swift
│   │   │   ├── HandshakeV10.swift
│   │   │   ├── HandshakeResponse41.swift
│   │   │   ├── COM_Query.swift
│   │   │   ├── COM_StmtPrepare.swift
│   │   │   ├── COM_StmtExecute.swift
│   │   │   ├── COM_StmtClose.swift
│   │   │   ├── COM_Ping.swift           # NEW
│   │   │   ├── COM_ResetConnection.swift # NEW
│   │   │   ├── COM_InitDB.swift          # NEW
│   │   │   ├── COM_ChangeUser.swift      # NEW
│   │   │   ├── CapabilityFlags.swift
│   │   │   ├── ColumnDefinition41.swift
│   │   │   ├── ResultSetRow.swift
│   │   │   ├── BinaryResultSetRow.swift
│   │   │   ├── ErrorPacket.swift
│   │   │   ├── OKPacket.swift
│   │   │   └── EOFPacket.swift
│   │   ├── Auth/                     # Authentication plugins
│   │   │   ├── MySQLNativePassword.swift     # existing
│   │   │   ├── CachingSHA2Password.swift     # existing
│   │   │   └── ClearPassword.swift           # NEW (for PAM/LDAP over TLS)
│   │   ├── Connection/               # Single connection management
│   │   │   ├── MySQLWireConnection.swift     # async/await native (replaces MySQLConnection)
│   │   │   ├── MySQLConnectionHandler.swift  # NIO channel handler (keep from mysql-nio)
│   │   │   ├── MySQLConnectionState.swift    # State machine
│   │   │   └── MySQLPacketSequence.swift     # Sequence ID tracking
│   │   ├── Types/                    # Data type codec
│   │   │   ├── MySQLData.swift              # Core data wrapper
│   │   │   ├── MySQLDataType.swift          # Type enum (28 types)
│   │   │   ├── MySQLData+Encoding.swift     # Binary encoding
│   │   │   ├── MySQLData+Decoding.swift     # Binary decoding
│   │   │   └── MySQLData+Conversions.swift  # Swift type conversions
│   │   ├── Streaming/                # NEW — streaming infrastructure
│   │   │   ├── MySQLRowStream.swift         # AsyncSequence of rows
│   │   │   ├── MySQLStreamUpdate.swift      # Progress callback model
│   │   │   └── MySQLStreamConfiguration.swift
│   │   └── Errors/
│   │       ├── MySQLError.swift
│   │       └── MySQLErrorCode.swift
│   │
│   ├── MySQLKit/                     # High-level typed API (NEW — follows postgres-wire pattern)
│   │   ├── Client/
│   │   │   ├── MySQLClient.swift            # Main entry point
│   │   │   ├── MySQLClient+Namespaces.swift # Namespace computed properties
│   │   │   ├── MySQLConfiguration.swift     # Connection + keepalive configuration
│   │   │   └── MySQLDedicatedSession.swift  # Dedicated connection for query tabs
│   │   ├── Connection/                # Connection lifecycle management
│   │   │   ├── MySQLServerConnection.swift  # Multi-connection manager (primary, metadata, cancel, activity)
│   │   │   ├── MySQLConnectionHealth.swift  # COM_PING keepalive, reconnect on failure, validation
│   │   │   └── PreparedStatementCache.swift # LRU cache per connection, cleared on COM_RESET_CONNECTION
│   │   ├── Execution/                # Query execution
│   │   │   ├── MySQLQueryClient.swift       # .query namespace
│   │   │   ├── MySQLTransaction.swift       # BEGIN/COMMIT/ROLLBACK helpers
│   │   │   └── MySQLBulkInsert.swift        # Batch INSERT optimization
│   │   ├── Metadata/                 # Schema introspection
│   │   │   ├── MySQLMetadataClient.swift    # .metadata namespace
│   │   │   ├── MySQLMetadata+Schemas.swift  # listSchemas, listDatabases
│   │   │   ├── MySQLMetadata+Tables.swift   # listTables, getTableDetails
│   │   │   ├── MySQLMetadata+Columns.swift  # listColumns, getColumnDetails
│   │   │   ├── MySQLMetadata+Indexes.swift  # listIndexes
│   │   │   ├── MySQLMetadata+ForeignKeys.swift
│   │   │   ├── MySQLMetadata+Routines.swift # functions, procedures
│   │   │   ├── MySQLMetadata+Triggers.swift
│   │   │   ├── MySQLMetadata+Events.swift
│   │   │   ├── MySQLMetadata+Views.swift
│   │   │   └── MySQLMetadata+Search.swift   # Cross-object search
│   │   ├── Admin/                    # Server administration
│   │   │   ├── MySQLAdminClient.swift       # .admin namespace
│   │   │   ├── MySQLAdmin+DDL.swift         # CREATE/ALTER/DROP table/view/etc.
│   │   │   ├── MySQLAdmin+Variables.swift   # SHOW/SET GLOBAL VARIABLES
│   │   │   ├── MySQLAdmin+Status.swift      # SHOW GLOBAL STATUS
│   │   │   ├── MySQLAdmin+Logs.swift        # Error/slow/general log access
│   │   │   ├── MySQLAdmin+Maintenance.swift # OPTIMIZE, ANALYZE, CHECK, REPAIR
│   │   │   └── MySQLAdmin+Backup.swift      # mysqldump orchestration helpers
│   │   ├── Security/                 # User & privilege management
│   │   │   ├── MySQLSecurityClient.swift    # .security namespace
│   │   │   ├── MySQLSecurity+Users.swift    # CREATE/ALTER/DROP USER
│   │   │   ├── MySQLSecurity+Grants.swift   # GRANT/REVOKE
│   │   │   ├── MySQLSecurity+Roles.swift    # Role management (MySQL 8.0+)
│   │   │   └── MySQLSecurity+Privileges.swift # Privilege introspection
│   │   ├── Performance/              # Performance monitoring
│   │   │   ├── MySQLPerformanceClient.swift # .performance namespace
│   │   │   ├── MySQLPerformance+Dashboard.swift   # Status variable metrics
│   │   │   ├── MySQLPerformance+PerfSchema.swift  # Performance Schema reports
│   │   │   ├── MySQLPerformance+Explain.swift     # EXPLAIN / EXPLAIN ANALYZE
│   │   │   └── MySQLPerformance+InnoDBStatus.swift # InnoDB engine status
│   │   ├── Activity/                 # Activity monitoring
│   │   │   ├── MySQLActivityClient.swift    # .activity namespace
│   │   │   ├── MySQLActivitySnapshot.swift  # Typed snapshot model
│   │   │   └── MySQLActivityMonitor.swift   # Streaming snapshots
│   │   ├── Replication/              # Replication monitoring
│   │   │   ├── MySQLReplicationClient.swift # .replication namespace
│   │   │   └── MySQLReplication+Status.swift # SHOW REPLICA STATUS
│   │   └── Models/                   # All typed result models
│   │       ├── MySQLSchemaInfo.swift
│   │       ├── MySQLTableInfo.swift
│   │       ├── MySQLColumnDetail.swift
│   │       ├── MySQLIndexInfo.swift
│   │       ├── MySQLForeignKeyInfo.swift
│   │       ├── MySQLRoutineInfo.swift
│   │       ├── MySQLTriggerInfo.swift
│   │       ├── MySQLEventInfo.swift
│   │       ├── MySQLUserInfo.swift
│   │       ├── MySQLPrivilegeInfo.swift
│   │       ├── MySQLServerStatus.swift
│   │       ├── MySQLServerVariable.swift
│   │       ├── MySQLExplainNode.swift
│   │       ├── MySQLPerfSchemaReport.swift
│   │       └── MySQLReplicationStatus.swift
│   │
│   └── MySQLKitTesting/              # Test support
│       ├── MySQLFixture.swift
│       ├── MySQLDockerManager.swift
│       └── MySQLTestConfiguration.swift
│
├── Tests/
│   ├── MySQLWireTests/               # Protocol-level tests
│   │   ├── PacketEncoderTests.swift
│   │   ├── PacketDecoderTests.swift
│   │   ├── AuthPluginTests.swift
│   │   ├── DataTypeTests.swift
│   │   └── HandshakeTests.swift
│   ├── MySQLKitTests/                # Integration tests
│   │   ├── MetadataTests.swift
│   │   ├── AdminTests.swift
│   │   ├── SecurityTests.swift
│   │   ├── PerformanceTests.swift
│   │   ├── ActivityTests.swift
│   │   ├── TransactionTests.swift
│   │   ├── StreamingTests.swift
│   │   └── ConnectionLifecycleTests.swift
│   └── MySQLKitTestingTests/
│       └── FixtureTests.swift
│
└── AGENTS.md                         # Claude Code instructions
```

---

## Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mysql-wire",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MySQLWire", targets: ["MySQLWire"]),
        .library(name: "MySQLKit", targets: ["MySQLKit"]),
        .library(name: "MySQLKitTesting", targets: ["MySQLKitTesting"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.27.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MySQLWire",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "MySQLKit",
            dependencies: [
                "MySQLWire",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .target(
            name: "MySQLKitTesting",
            dependencies: ["MySQLKit"]
        ),
        .testTarget(name: "MySQLWireTests", dependencies: ["MySQLWire"]),
        .testTarget(name: "MySQLKitTests", dependencies: ["MySQLKit", "MySQLKitTesting"]),
    ]
)
```

---

## The Approach: How to Fork + Restructure

### Step 1: Fork mysql-nio protocol layer → MySQLWire

Take these files from mysql-nio and reorganize:

| mysql-nio file | → MySQLWire location | Changes needed |
|---|---|---|
| `MySQLPacketDecoder.swift` | `Protocol/MySQLPacketDecoder.swift` | None — keep as-is |
| `MySQLPacketEncoder.swift` | `Protocol/MySQLPacketEncoder.swift` | None |
| `Protocol/*.swift` (23 files) | `Protocol/` | Minor cleanup |
| `MySQLConnectionHandler.swift` | `Connection/MySQLConnectionHandler.swift` | Add COM_PING/RESET/INIT_DB command support |
| `MySQLConnection.swift` | `Connection/MySQLWireConnection.swift` | Wrap with async/await API |
| `MySQLData.swift` + type files | `Types/` | None — keep as-is |
| Auth plugins | `Auth/` | Add ClearPassword |
| Error types | `Errors/` | Extend with error code enum |

**New files to add:**
- `Protocol/COM_Ping.swift` — implement `COM_PING` command (single byte 0x0e, expect OK)
- `Protocol/COM_ResetConnection.swift` — implement `COM_RESET_CONNECTION` (0x1f, expect OK)
- `Protocol/COM_InitDB.swift` — implement `COM_INIT_DB` (0x02 + database name, expect OK)
- `Protocol/COM_ChangeUser.swift` — implement `COM_CHANGE_USER` (0x11 + auth data)
- `Streaming/MySQLRowStream.swift` — `AsyncThrowingStream<MySQLRow, Error>` that wraps the callback-based row delivery
- `Auth/ClearPassword.swift` — send password as plaintext (required for PAM over TLS)

**Key change: async/await wrapper**

Replace mysql-nio's `EventLoopFuture` public API with native async:

```swift
// mysql-nio (current):
public func query(_ sql: String, _ binds: [MySQLData]) -> EventLoopFuture<[MySQLRow]>

// MySQLWire (new):
public func query(_ sql: String, _ binds: [MySQLData]) async throws -> [MySQLRow]
public func queryStream(_ sql: String, _ binds: [MySQLData]) -> AsyncThrowingStream<MySQLRow, Error>
```

The NIO EventLoopFuture stays internal. The public API is pure async/await.

### Step 2: Build MySQLKit (entirely new)

This is the layer Echo talks to. Follow postgres-wire's pattern exactly:

**MySQLClient — Main Entry Point:**
```swift
public final class MySQLClient: Sendable {
    internal let server: MySQLServerConnection
    internal let logger: Logger

    public static func connect(configuration: MySQLConfiguration) async throws -> MySQLClient

    // Namespace access — each uses the appropriate connection role
    public var query: MySQLQueryClient { .init(client: self) }       // → primary connection
    public var metadata: MySQLMetadataClient { .init(client: self) } // → metadata connection
    public var admin: MySQLAdminClient { .init(client: self) }       // → metadata connection
    public var security: MySQLSecurityClient { .init(client: self) } // → metadata connection
    public var performance: MySQLPerformanceClient { .init(client: self) } // → metadata connection
    public var activity: MySQLActivityClient { .init(client: self) } // → activity connection
    public var replication: MySQLReplicationClient { .init(client: self) } // → metadata connection

    /// Create a new dedicated connection for a separate query tab
    public func newDedicatedSession() async throws -> MySQLDedicatedSession

    /// Cancel a running query on the primary or a dedicated connection
    public func cancelQuery(threadID: UInt32) async throws

    public func close() async
}
```

**Namespace Example — MySQLMetadataClient:**
```swift
public struct MySQLMetadataClient: Sendable {
    internal let client: MySQLClient
    // All methods use client.server.metadata() — the metadata connection,
    // which is reset between operations for clean state.

    public func listDatabases() async throws -> [String]
    public func listTables(database: String) async throws -> [MySQLTableInfo]
    public func listColumns(database: String, table: String) async throws -> [MySQLColumnDetail]
    public func listIndexes(database: String, table: String) async throws -> [MySQLIndexInfo]
    public func listForeignKeys(database: String, table: String) async throws -> [MySQLForeignKeyInfo]
    public func listRoutines(database: String) async throws -> [MySQLRoutineInfo]
    public func listTriggers(database: String) async throws -> [MySQLTriggerInfo]
    public func listEvents(database: String) async throws -> [MySQLEventInfo]
    public func getTableDetails(database: String, table: String) async throws -> MySQLTableDetail
    public func getObjectDefinition(database: String, name: String, type: MySQLObjectType) async throws -> String
    public func searchObjects(database: String, query: String, types: Set<MySQLObjectType>) async throws -> [MySQLSearchResult]
}
```

**Prepared Statement Cache (per-connection):**
```swift
internal actor PreparedStatementCache {
    private var cache: OrderedDictionary<String, UInt32> = [:]  // SQL → statement ID
    private let maxSize: Int = 256

    func get(_ sql: String) -> UInt32?
    func put(_ sql: String, statementID: UInt32)
    func evict(_ sql: String)
    func clear()  // Called on COM_RESET_CONNECTION since server deallocates all statements
}
```

### Step 3: Build MySQLKitTesting

```swift
public struct MySQLTestConfiguration {
    public static var host: String { env("MYSQL_HOST") ?? "localhost" }
    public static var port: Int { Int(env("MYSQL_PORT") ?? "3306") ?? 3306 }
    public static var username: String { env("MYSQL_USER") ?? "root" }
    public static var password: String { env("MYSQL_PASSWORD") ?? "" }
    public static var database: String { env("MYSQL_DATABASE") ?? "test" }
}

public final class MySQLDockerManager {
    public static func ensureRunning(version: String = "8.4") async throws -> MySQLConfiguration
    public static func stopContainer() async throws
}
```

---

## Implementation Order

### Milestone 1: Wire layer fork (1 week)

1. Create the repo at `/Users/k/Development/mysql-wire`
2. Copy mysql-nio protocol files into `MySQLWire/Protocol/`
3. Copy auth plugins into `MySQLWire/Auth/`
4. Copy data type codec into `MySQLWire/Types/`
5. Copy connection handler into `MySQLWire/Connection/`
6. Build `MySQLWireConnection` with async/await public API wrapping the NIO internals
7. Add `COM_PING`, `COM_RESET_CONNECTION`, `COM_INIT_DB`
8. Add `MySQLRowStream` (AsyncThrowingStream wrapper)
9. Write protocol-level tests (packet encode/decode, auth, data types)
10. Verify: can connect, authenticate, query, stream rows

### Milestone 2: Connection management + statement cache (1 week)

1. Build `MySQLServerConnection` actor (multi-connection manager: primary, metadata, cancel, activity)
2. Build `MySQLConnectionHealth` (COM_PING keepalive, reconnect on failure, validation)
3. Build `PreparedStatementCache` actor (per-connection LRU, cleared on COM_RESET_CONNECTION)
4. Build `MySQLClient` with server connection integration
5. Build `MySQLConfiguration` (host, port, database, auth, TLS, keepalive interval)
6. Build `MySQLDedicatedSession` (for additional query tabs)
7. Write connection lifecycle tests (connect, ping, reset, reconnect after timeout, cancel query via KILL)
8. Write cache tests (hit, miss, eviction, clear on reset)
9. Verify: primary connection holds state, metadata connection resets cleanly, cancel works on running query

### Milestone 3: Metadata namespace (1 week)

1. Build `MySQLMetadataClient` with all introspection methods
2. All queries go through `information_schema` + `SHOW CREATE`
3. Build typed models: `MySQLTableInfo`, `MySQLColumnDetail`, `MySQLIndexInfo`, etc.
4. Build `MySQLMetadata+Search` for cross-object search
5. Write integration tests against real MySQL
6. Verify: Echo can switch from raw SQL to `client.metadata.*` calls

### Milestone 4: Admin + Security namespaces (1 week)

1. Build `MySQLAdminClient` — DDL, variables, status, logs, maintenance
2. Build `MySQLSecurityClient` — users, grants, roles, privileges
3. Build typed models for all admin/security results
4. Write integration tests
5. Verify: user management, variable browsing, maintenance operations all work through typed API

### Milestone 5: Performance + Activity namespaces (1 week)

1. Build `MySQLPerformanceClient` — dashboard metrics, Performance Schema reports, EXPLAIN
2. Build `MySQLActivityClient` — process list, streaming snapshots
3. Build `MySQLExplainNode` model for JSON EXPLAIN parsing
4. Write integration tests
5. Verify: performance dashboard, EXPLAIN visualization, activity monitor all work through typed API

### Milestone 6: Echo integration (1 week)

1. Replace `mysql-nio` dependency in Echo with `mysql-wire`
2. Rewrite `MySQLSession` to use `MySQLClient` (like how `SQLServerSessionAdapter` uses `SQLServerClient`)
3. Replace all raw SQL in Echo's MySQL dialect layer with typed API calls
4. Remove `MySQLSession+Objects.swift`, `MySQLSession+Structure.swift`, `MySQLSession+Queries.swift` raw SQL
5. Update `MySQLSearchStrategy` to use `client.metadata.searchObjects()`
6. Verify: full build, all existing MySQL features still work

---

## Concurrency Model

| Type | Isolation | Rationale |
|---|---|---|
| `MySQLWireConnection` | `nonisolated`, `Sendable` | NIO handles thread safety internally |
| `MySQLClient` | `nonisolated`, `Sendable` | Wraps `MySQLServerConnection` actor |
| `MySQLServerConnection` | `actor` | Manages multiple connections, mutable state |
| `MySQLDedicatedSession` | `nonisolated`, `Sendable` | Wraps a single `MySQLWireConnection` |
| `PreparedStatementCache` | `actor` | Per-connection mutable LRU cache |
| Namespace clients | `struct`, `Sendable` | Lightweight wrappers, no state |
| All result models | `struct`, `Sendable` | Value types, safe to share |
| `MySQLActivityMonitor` | `actor` | Manages baseline state for delta computation |

**No MainActor.** The package is isolation-agnostic. Echo's app layer handles MainActor.

---

## Echo Integration: How MySQLSession Maps to MySQLClient

When mysql-wire is ready, Echo's `MySQLSession` gets rewritten to match the `SQLServerSessionAdapter` pattern:

### Current (mysql-nio, raw SQL in Echo)

```
Echo MySQLSession
  └── mysql-nio MySQLConnection (single, no management)
       └── raw SQL for everything (listTables, getColumns, etc.)
```

### Target (mysql-wire, typed API)

```
Echo MySQLSessionAdapter (nonisolated, Sendable)
  └── MySQLClient
       ├── .metadata  → MySQLMetadataClient  → metadata connection
       ├── .admin     → MySQLAdminClient     → metadata connection
       ├── .security  → MySQLSecurityClient  → metadata connection
       ├── .activity  → MySQLActivityClient  → activity connection
       └── .query     → MySQLQueryClient     → primary connection

Echo MySQLDedicatedQuerySession (per query tab)
  └── MySQLDedicatedSession
       └── dedicated MySQLWireConnection (owns session state)
       └── references MySQLSessionAdapter for metadata delegation
```

### Connection-to-Tab Mapping in Echo

```
User connects to MySQL server
  │
  ├── ConnectionSession created
  │     └── MySQLSessionAdapter wraps MySQLClient
  │           ├── primary connection    → sidebar context menu actions, inline queries
  │           ├── metadata connection   → object browser, autocomplete, schema loading
  │           └── activity connection   → activity monitor tab (lazy)
  │
  ├── User opens Query Tab 1
  │     └── MySQLDedicatedQuerySession created via client.newDedicatedSession()
  │           └── fresh TCP connection → tab's exclusive session
  │           └── metadata delegated to MySQLSessionAdapter
  │
  ├── User opens Query Tab 2
  │     └── another MySQLDedicatedQuerySession
  │           └── another fresh TCP connection
  │
  └── User opens Activity Monitor
        └── MySQLClient.activity → lazy activity connection created
```

### Key Differences from Current Echo MySQL Code

| Aspect | Current (mysql-nio) | Target (mysql-wire) |
|---|---|---|
| `listTables()` | Raw SQL in `MySQLSession+Objects.swift` | `client.metadata.listTables(database:)` |
| `getTableSchema()` | Raw SQL via `information_schema` | `client.metadata.listColumns(database:table:)` |
| `getTableStructureDetails()` | Raw SQL in `MySQLSession+Structure.swift` | `client.metadata.getTableDetails(database:table:)` |
| Search | Raw SQL in `MySQLSearchStrategy.swift` | `client.metadata.searchObjects(database:query:types:)` |
| Activity monitor | `SHOW PROCESSLIST` in Echo | `client.activity.snapshot()` / `.streamSnapshots(every:)` |
| Maintenance | Raw SQL in `GenericMaintenanceOperations.swift` | `client.admin.optimizeTable()`, `.checkTable()`, etc. |
| Query execution | Single shared `MySQLConnection` | Dedicated `MySQLDedicatedSession` per tab |
| Cancel query | Not implemented | `client.cancelQuery(threadID:)` via ephemeral connection |
| Database switching | `USE db` in SQL | `COM_INIT_DB` on wire connection |

### Files to Delete After Migration

These Echo files become dead code once mysql-wire provides typed APIs:

- `Echo/Sources/Core/DatabaseEngine/Dialects/MySQL/Modules/MySQLSession+Objects.swift` — replaced by `client.metadata.*`
- `Echo/Sources/Core/DatabaseEngine/Dialects/MySQL/Modules/MySQLSession+Structure.swift` — replaced by `client.metadata.getTableDetails()`
- `Echo/Sources/Core/DatabaseEngine/Dialects/MySQL/Modules/MySQLSession+Queries.swift` — replaced by `client.query.*` + dedicated sessions
- `Echo/Sources/Core/DatabaseEngine/Dialects/MySQL/Modules/MySQLCellFormatter.swift` — replaced by `MySQLData` conversions in mysql-wire
- `Echo/Sources/Core/DatabaseEngine/Dialects/MySQL/MySQLSearchStrategy.swift` — replaced by `client.metadata.searchObjects()`

The remaining file `MySQLDatabase.swift` gets rewritten as `MySQLSessionAdapter.swift` — a thin bridge from `MySQLClient` to Echo's `DatabaseSession` protocol, matching the `SQLServerSessionAdapter` pattern.

---

## Why Not Start From Scratch

Starting from scratch means reimplementing:
- MySQL client/server protocol handshake (500+ lines)
- TLS negotiation with MySQL's special "upgrade mid-handshake" flow
- Two authentication plugins with their cryptographic algorithms
- 28 data type binary encoders/decoders
- Binary result set row decoding with null bitmap
- Packet framing and sequence tracking
- NIO channel handler pipeline

That's 4,000+ lines of protocol code that mysql-nio has already written, tested, and battle-tested across the Vapor ecosystem. Forking lets us keep all of that and focus our energy on the layers that matter: connection management, caching, streaming, and the typed API.

## Why Not Use mysql-nio As-Is (Like Today)

Using mysql-nio directly means:
- Echo keeps raw SQL in the dialect layer (violates the boundary rule)
- No connection lifecycle management (no keepalive, no reconnect, no cancel)
- No prepared statement caching (each query prepares/closes — server overhead)
- No streaming with backpressure (large results buffer in memory)
- Every new feature requires raw SQL in Echo instead of a typed API in the package
- Can't add `COM_PING` for connection health checks
- Can't add `COM_RESET_CONNECTION` for clean metadata connection reuse
- Can't add `COM_INIT_DB` for efficient database switching
- Can't send `KILL QUERY` on a separate connection (no multi-connection coordination)
- Locked into Vapor's release cadence for bug fixes
- No dedicated session model — query tabs can't get isolated connections

---

## Protocol Reference: MySQL Client/Server Protocol

Key characteristics that drive every design decision in this package:

### Half-Duplex, Strictly Sequential
One command per connection at a time. Client sends `COM_*` → server sends full response → client can send next command. No multiplexing, no pipelining, no interleaving. This is fundamentally different from PostgreSQL (which supports pipelining) and SQL Server (which has MARS).

### Connection = Session
A MySQL connection carries all session state: transactions, temp tables, session variables, prepared statements, selected database, character set, advisory locks, `LAST_INSERT_ID()`. There is no way to "detach" state from a connection. Disconnecting loses everything. `COM_RESET_CONNECTION` clears everything except the authenticated user.

### Cancel Requires a Second Connection
The only way to cancel a running query is to open a separate TCP connection and send `KILL QUERY <thread_id>`. You cannot cancel from the connection that's executing the query — it's blocked waiting for the response.

### Database Switching is Session State
`USE database` (or `COM_INIT_DB`) changes the connection's default database. This is session state — it persists until changed or the connection is closed. Unlike PostgreSQL, MySQL does not require a new TCP connection to switch databases.

### Prepared Statements are Per-Connection
`COM_STMT_PREPARE` returns a statement ID that is only valid on that connection. If the connection is reset or closed, all prepared statements are deallocated. The server has a global limit (`max_prepared_stmt_count`, default 16,382) — leaking prepared statements is a real production issue.

### Implications for mysql-wire
1. **Dedicated connections, not a pool** — session state must not be lost between operations
2. **Multi-connection manager** — need separate connections for query, metadata, cancel, activity
3. **Per-connection prepared statement cache** — cache must be cleared on `COM_RESET_CONNECTION`
4. **Ephemeral cancel connection** — created on-demand, used once, destroyed
5. **AsyncThrowingStream for streaming** — since the connection is blocked during result set transfer, streaming must be cooperative (read rows as they arrive, not buffer all in memory)

---

## Testing Infrastructure

### Docker Container

Tests run against a real MySQL server in Docker:

```yaml
# docker-compose.yml (for local development)
services:
  mysql:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: testpassword
      MYSQL_DATABASE: test
    ports:
      - "3306:3306"
    command: --default-authentication-plugin=caching_sha2_password
```

### Test Fixture Database

`MySQLFixture` creates a test database with tables covering all common scenarios:

- `basic_types` — every MySQL data type (INT, VARCHAR, TEXT, BLOB, JSON, DATETIME, DECIMAL, ENUM, SET, GEOMETRY, etc.)
- `indexed_table` — table with PRIMARY, UNIQUE, INDEX, FULLTEXT, SPATIAL indexes
- `parent_table` + `child_table` — foreign key relationship with CASCADE/RESTRICT
- `partitioned_table` — RANGE partitioning by date
- `with_triggers` — BEFORE/AFTER INSERT/UPDATE/DELETE triggers
- `test_view` — view definition
- `test_proc` — stored procedure with IN/OUT/INOUT parameters
- `test_func` — stored function
- `test_event` — scheduled event (disabled)

### Test Environment Variables

```
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=testpassword
MYSQL_DATABASE=test
USE_DOCKER=1          # Auto-start Docker container
MYSQL_VERSION=8.4     # Docker image tag
```

### CI Pipeline

Same pattern as sqlserver-nio:
- **Unit tests** (no database) — packet encoding/decoding, auth plugin crypto, data type conversions. Run on GitHub-hosted runner.
- **Integration tests** (need MySQL) — connect, query, metadata, admin, security, performance. Run on self-hosted runner with Docker.

### Test Patterns

```swift
import Testing
import MySQLKitTesting

@Suite(.serialized)
struct MetadataTests {
    let client: MySQLClient

    init() async throws {
        let config = try await MySQLDockerManager.ensureRunning()
        client = try await MySQLClient.connect(configuration: config)
    }

    @Test func listDatabases() async throws {
        let databases = try await client.metadata.listDatabases()
        #expect(databases.contains("test"))
        #expect(!databases.contains("information_schema"))  // system schemas filtered
    }

    @Test func listTablesReturnsFixtureTable() async throws {
        let tables = try await client.metadata.listTables(database: "test")
        let names = tables.map(\.name)
        #expect(names.contains("basic_types"))
    }

    @Test func columnDetailsIncludeAllProperties() async throws {
        let columns = try await client.metadata.listColumns(database: "test", table: "basic_types")
        let idColumn = try #require(columns.first(where: { $0.name == "id" }))
        #expect(idColumn.isPrimaryKey)
        #expect(idColumn.isAutoIncrement)
        #expect(!idColumn.isNullable)
        #expect(idColumn.dataType == "int")
    }
}
```

---

## AGENTS.md Content (for the mysql-wire repo)

The AGENTS.md file in the mysql-wire repo root should contain:

```markdown
# mysql-wire

First-party MySQL driver for Echo. Two modules:
- `MySQLWire` — low-level wire protocol (forked from Vapor mysql-nio, restructured)
- `MySQLKit` — high-level typed API (namespace pattern matching postgres-wire)

## Architecture

Connection model: dedicated long-lived connections, NOT a pool.
The MySQL protocol is half-duplex (one command at a time) and stateful (connection = session).
See `MySQLServerConnection` actor for the multi-connection manager.

## Concurrency

- No MainActor — this is a package, not an app
- `MySQLServerConnection` is an actor (manages connection state)
- `PreparedStatementCache` is an actor (per-connection LRU)
- Namespace clients are Sendable structs
- All result models are Sendable value types
- NIO EventLoopFutures are internal only — public API is async/await

## Testing

- Unit tests: no database needed (packet/auth/type tests)
- Integration tests: need MySQL in Docker (set USE_DOCKER=1)
- Use Swift Testing (@Test, #expect, #require)
- Cleanup with deferred SQL, not defer { Task {} }

## Key Rules

- Every public API returns typed models, never raw rows
- Never expose NIO types in public API
- COM_RESET_CONNECTION after every metadata operation
- Prepared statement cache cleared on COM_RESET_CONNECTION
- Cancel query via ephemeral connection + KILL QUERY
- COM_PING for keepalive on idle connections
```
