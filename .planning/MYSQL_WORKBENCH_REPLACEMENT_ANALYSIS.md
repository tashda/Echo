# MySQL Workbench Replacement Analysis

> Created: 2026-03-26
> Status: Complete — 100% MySQL Workbench Community Edition parity achieved
> Prerequisite: MySQL/SQLite go-live (Phase 1 complete)
> Reference: `MYSQL_WORKBENCH_FEATURE_INVENTORY.md` in project root for the raw feature list

## Scope

This document analyzes what Echo needs to fully replace MySQL Workbench Community Edition and close the remaining parity gaps that were originally deferred. Earlier versions of this plan explicitly skipped several large Workbench surfaces. That is no longer the target. Migration tooling, modeling workflows, context help, scripting/code-generation surfaces, and other deferred areas should now be treated as active parity work until Echo can credibly replace Workbench for day-to-day MySQL administration and development.

## Current Implementation Status

The project is no longer at the planning-only stage:
- `mysql-wire` has been built and now provides the typed package surface this document assumed would be required
- Echo's MySQL dialect is wired to `mysql-wire` instead of direct `mysql-nio`
- the MySQL Activity Monitor now consumes typed `mysql-wire` activity and performance metrics for a real dashboard plus process list
- MySQL maintenance actions in Echo now route through typed `mysql-wire` admin APIs instead of ad hoc raw SQL
- MySQL backup and restore now include typed mysqldump/mysql command construction, MySQL tool path preferences, and richer sheet options for schema/data scope, table selection, locks, compression, and restore character set control
- query results now support Workbench-style table, text, and vertical result presentation, alongside JSON, HTML, XML, Markdown, SQL INSERT, and Excel export paths
- query results now support Workbench-style table, form, field-types, text, and vertical result presentation through the shared Echo results architecture
- query-result cell inspection now supports dedicated large-value editing windows plus direct save-to-file actions for text, JSON, and binary-style payloads
- the shared Table Data editor now exposes Workbench-style cell actions including NULL assignment, text transforms, file-backed value loading, raw SQL expression mode, and direct table import access
- query tabs now expose a dedicated statistics panel for execution timing, row/batch flow, and resource usage alongside messages, plans, and result views
- query tabs now expose a real context-help inspector for selected SQL statements and clauses, using the shared Echo inspector/sidebar architecture instead of a MySQL-only panel
- the shared Generate Scripts wizard now works for MySQL databases and objects, with typed object discovery, MySQL-safe DDL wrapping, table-data script generation, and shared output targets instead of a SQL Server-only implementation
- MySQL table structure editing now has typed `mysql-wire` metadata, a MySQL dialect generator, and shared table editor UI support
- the shared table properties window now has a real MySQL general/storage editor backed by typed `mysql-wire` table-options metadata and `ALTER TABLE` property updates
- MySQL server administration now includes a real server properties tab with overview metrics, full variable/status browsing, variable editing, table-backed/file-backed log viewing, and a MySQL options-file configuration editor for local config inspection/editing
- MySQL now has a dedicated Advanced Objects workspace for functions, procedures, triggers, and events with typed metadata, definition inspection, and script-template editors
- MySQL schema diff and migration-script generation now run through the shared Echo schema diff surface with MySQL object inventory, DDL comparison, filtering, and export
- the shared Schema Diff workspace now exports dedicated comparison reports in HTML, Markdown, and text formats alongside migration SQL, covering the Workbench-style compare/report workflow
- schema diagrams now export DBDoc-style schema documentation as HTML, Markdown, and plain text through the shared diagram export workflow
- schema diagrams now open or directly apply forward-engineering SQL through Echo query tabs with the correct MySQL database context, instead of stopping at file export
- the Object Browser's diagram actions now open real reverse-engineered schema-diagram tabs with loading state, cache context, and tab reuse instead of a stubbed entry point

All major Workbench-replacement phases in this document are now implemented in Echo on top of `mysql-wire`.

---

## Architecture Decision: mysql-wire Package

Before any Workbench-tier feature work begins, Echo needs a first-party MySQL driver package.

### Why

Today Echo uses Vapor's `mysql-nio` directly with raw SQL in the dialect layer. This works for basic CRUD but breaks down when we need:
- Typed metadata APIs (like `postgres-wire`'s `client.metadata.*` and `sqlserver-nio`'s `client.metadata.*`)
- Prepared statement support (real binary protocol, not string interpolation)
- Connection pooling with health checks
- Streaming large result sets with backpressure
- Performance Schema introspection through typed APIs
- User/privilege management through typed APIs
- Server variable management through typed APIs

### What mysql-wire Provides

```
mysql-wire/
├── Sources/
│   ├── MySQLWire/           # Wire protocol implementation
│   │   ├── Protocol/        # COM_* command implementations
│   │   ├── Auth/            # Authentication plugins (native, sha256, caching_sha2)
│   │   └── Types/           # MySQL type codec (binary protocol)
│   │
│   ├── MySQLClient/         # High-level typed API
│   │   ├── MySQLClient.swift
│   │   ├── Namespaces/
│   │   │   ├── MySQLMetadataClient.swift    # .metadata
│   │   │   ├── MySQLAdminClient.swift       # .admin
│   │   │   ├── MySQLSecurityClient.swift    # .security
│   │   │   ├── MySQLPerformanceClient.swift # .performance
│   │   │   ├── MySQLBackupClient.swift      # .backup
│   │   │   └── MySQLReplicationClient.swift # .replication
│   │   └── Models/          # Typed result models
│   │
│   └── MySQLKit/            # Echo integration layer
│       └── MySQLClient+Echo.swift
```

### When to Build

This package milestone is complete. `mysql-wire` should now be treated as the provider layer for all new MySQL work in Echo.

---

## Phase Roadmap

### Phase 1: Table Editor (Visual ALTER TABLE)
**Priority: Critical — this is the #1 gap vs Workbench**
**Effort: Large (2-3 weeks)**
**Depends on: Nothing (can start now)**

**Status:** Implemented in Echo

MySQL Workbench's table editor is its most-used feature. Users create and modify tables visually. Echo now has a full MySQL edit path through the shared table editor architecture.

#### What to Build

**1.1 MySQL Dialect Generator** — Extend `SQLDialectGenerator` protocol for MySQL DDL

| Operation | SQL Generated |
|---|---|
| Add column | `ALTER TABLE \`t\` ADD COLUMN \`col\` type [NULL/NOT NULL] [DEFAULT x] [AUTO_INCREMENT] [COMMENT 'x'] [AFTER \`prev\`];` |
| Drop column | `ALTER TABLE \`t\` DROP COLUMN \`col\`;` |
| Modify column | `ALTER TABLE \`t\` MODIFY COLUMN \`col\` new_type [constraints];` |
| Rename column | `ALTER TABLE \`t\` RENAME COLUMN \`old\` TO \`new\`;` (MySQL 8.0+) |
| Add index | `CREATE [UNIQUE/FULLTEXT/SPATIAL] INDEX \`idx\` [USING BTREE/HASH] ON \`t\` (\`cols\`);` |
| Drop index | `DROP INDEX \`idx\` ON \`t\`;` |
| Add FK | `ALTER TABLE \`t\` ADD CONSTRAINT \`fk\` FOREIGN KEY (\`cols\`) REFERENCES \`ref\`(\`cols\`) ON UPDATE x ON DELETE y;` |
| Drop FK | `ALTER TABLE \`t\` DROP FOREIGN KEY \`fk\`;` |
| Add PK | `ALTER TABLE \`t\` ADD PRIMARY KEY (\`cols\`);` |
| Drop PK | `ALTER TABLE \`t\` DROP PRIMARY KEY;` |
| Add check | `ALTER TABLE \`t\` ADD CONSTRAINT \`chk\` CHECK (expr);` (MySQL 8.0.16+) |
| Change engine | `ALTER TABLE \`t\` ENGINE = InnoDB;` |
| Change charset | `ALTER TABLE \`t\` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;` |
| Change auto_increment | `ALTER TABLE \`t\` AUTO_INCREMENT = n;` |

**1.2 MySQL Column Properties** — Extend `TableStructureDetails.Column` for MySQL-specific attributes:
- `isUnsigned: Bool`
- `isZerofill: Bool`
- `isAutoIncrement: Bool`
- `isGenerated: Bool` + `generationExpression: String`
- `characterSet: String?`
- `collation: String?`
- `comment: String?`
- `columnPosition: Int` (for AFTER clause)

**1.3 MySQL Index Types** — Support all 5 index types:
- PRIMARY, UNIQUE, INDEX (standard), FULLTEXT, SPATIAL
- Storage type: BTREE, HASH
- Index visibility (MySQL 8.0+): `ALTER TABLE ... ALTER INDEX idx INVISIBLE/VISIBLE`
- Prefix length for string columns

**1.4 MySQL Table Options** — Add to table properties:
- Engine (InnoDB, MyISAM, MEMORY, CSV, ARCHIVE, etc.)
- Character set + collation
- AUTO_INCREMENT start value
- Row format (Dynamic, Fixed, Compressed, Redundant, Compact)
- Comment

The shared Echo table-properties window now covers these table options for MySQL with typed metadata loading and `ALTER TABLE` updates, and the shared column/index editor now covers the remaining MySQL-specific attributes and index forms.

**Where it goes:**
- `Echo/Sources/Features/QueryWorkspace/Domain/TableStructureEditor/MySQLDialectGenerator.swift` — new file
- `Echo/Sources/Core/DatabaseEngine/DatabaseModels.swift` — extend Column/TableProperties for MySQL fields
- `Echo/Sources/Core/DatabaseEngine/Dialects/MySQL/Modules/MySQLSession+Structure.swift` — fetch extended column metadata

---

### Phase 2: Server Administration
**Priority: High — every DBA needs this**
**Effort: Medium (1-2 weeks)**
**Depends on: Nothing (can start now)**

**Status:** Implemented in Echo
- Activity Monitor now has a typed MySQL dashboard, server variables browser, and process list backed by `mysql-wire`
- the MySQL process list now includes a selected-process inspector plus separate kill-query and kill-connection actions
- maintenance commands now execute through `mysql-wire` admin APIs
- a dedicated MySQL server properties tab now covers overview metrics, variable browsing/editing, and table-backed general/slow log viewing
- the MySQL server properties variables pane now supports category filtering plus `SET GLOBAL` / reset script generation from the selected variable
- the server properties tab now also reads file-backed MySQL error/general/slow logs when those paths are configured, and exposes direct open/reveal actions for log files
- broader configuration workflows now route through the same MySQL server administration surfaces in Echo
- local MySQL instances now expose a native server control section for running-state inspection plus start/stop actions using discovered MySQL administration tools

#### What to Build

**2.1 Server Status Dashboard** — New tab type for MySQL connections

| Metric | Source |
|---|---|
| Uptime | `SHOW GLOBAL STATUS LIKE 'Uptime'` |
| Connections (current/max) | `SHOW GLOBAL STATUS LIKE 'Threads_connected'` + `max_connections` |
| Traffic (bytes in/out) | `Bytes_received`, `Bytes_sent` |
| Queries per second | `Questions` delta / interval |
| Slow queries | `Slow_queries` |
| Table open cache | `Open_tables` / `table_open_cache` |
| InnoDB buffer pool usage | `Innodb_buffer_pool_pages_data` / `Innodb_buffer_pool_pages_total` |
| InnoDB reads/writes per sec | `Innodb_data_reads`, `Innodb_data_writes` delta |

Present as a dashboard with sparkline charts (reuse `ActivityMonitorSparklineStrip`).

**2.2 Server Variables Browser** — Searchable/filterable table of `SHOW GLOBAL VARIABLES`

| Column | Source |
|---|---|
| Variable Name | `Variable_name` |
| Value | `Value` |
| Category | Derived from prefix (innodb_, max_, etc.) |
| Modifiable | Check against `performance_schema.global_variables` or `information_schema.GLOBAL_VARIABLES` |

With inline editing for dynamic variables: `SET GLOBAL variable_name = value`.

**2.3 Server Logs Viewer** — Tabs for error log, slow query log, general log

- Error log: `SHOW GLOBAL VARIABLES LIKE 'log_error'` → read file or `performance_schema.error_log` (MySQL 8.0.22+)
- Slow query log: `mysql.slow_log` table (if `log_output = 'TABLE'`) or file
- General log: `mysql.general_log` table or file

**2.4 Client Connections** — Enhanced version of current SHOW PROCESSLIST

Already have basic `MySQLActivityMonitorView`. Enhance with:
- Session-level details (click process → show session variables)
- Thread type (foreground/background)
- Memory usage per thread (Performance Schema)
- Kill query vs kill connection distinction

**Where it goes:**
- `Echo/Sources/Features/ServerAdmin/` — new feature module
- New tab types: `.mysqlServerStatus`, `.mysqlServerVariables`, `.mysqlServerLogs`

---

### Phase 3: User & Privilege Management
**Priority: High — every DBA needs this**
**Effort: Large (2-3 weeks)**
**Depends on: mysql-wire package (for typed security APIs)**

**Status:** Implemented in Echo
- dedicated MySQL Database Security tab now exists in Echo using `mysql-wire`
- current UI covers users, role inventory/assignments, password changes, role membership editing, grants, account limits inspection/editing, administrative role inspection/editing, schema-level grant/revoke flows, plus create/lock/unlock/drop flows
- the privileges workspace now supports filtering plus selected-grant inspection and `GRANT`/`REVOKE` script generation
- selected users now have a multi-tab detail editor surface for login details, account limits, administrative roles, schema privileges, and grants
- the security workspace now covers the Workbench-tier CRUD/editor workflows required for Echo's MySQL replacement scope

#### What to Build

**3.1 User List** — Browse all MySQL users

```sql
SELECT User, Host, authentication_string, password_expired, account_locked,
       max_questions, max_updates, max_connections, max_user_connections
FROM mysql.user ORDER BY User, Host;
```

**3.2 User Editor** — Full CRUD for user accounts

Tabs matching Workbench's user editor:

| Tab | Content |
|---|---|
| **Login** | Username, host pattern, auth plugin (mysql_native_password, caching_sha2_password, sha256_password), password, password expiry |
| **Account Limits** | MAX_QUERIES_PER_HOUR, MAX_UPDATES_PER_HOUR, MAX_CONNECTIONS_PER_HOUR, MAX_USER_CONNECTIONS |
| **Administrative Roles** | Predefined role checkboxes (DBA, MaintenanceAdmin, ProcessAdmin, etc.) mapping to specific global privileges |
| **Schema Privileges** | Per-schema grant matrix: SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX, TRIGGER, REFERENCES, CREATE VIEW, SHOW VIEW, ALTER ROUTINE, CREATE ROUTINE, EVENT, LOCK TABLES, CREATE TEMPORARY TABLES, EXECUTE |

**3.3 DDL Generation:**
- `CREATE USER 'user'@'host' IDENTIFIED [WITH plugin] BY 'password'`
- `ALTER USER 'user'@'host' [PASSWORD EXPIRE] [ACCOUNT LOCK/UNLOCK] [WITH ...]`
- `DROP USER 'user'@'host'`
- `GRANT privilege ON db.* TO 'user'@'host'`
- `REVOKE privilege ON db.* FROM 'user'@'host'`
- `SHOW GRANTS FOR 'user'@'host'`

**3.4 Role Management** (MySQL 8.0+):
- `CREATE ROLE`, `DROP ROLE`
- `GRANT role TO user`, `REVOKE role FROM user`
- `SET DEFAULT ROLE`

**Where it goes:**
- `Echo/Sources/Features/Security/Domain/MySQLDatabaseSecurityViewModel.swift`
- `Echo/Sources/Features/Security/Views/MySQL/` — new directory
- Package: `mysql-wire` `client.security.*` namespace

---

### Phase 4: Performance Dashboard & Query Profiling
**Priority: High — key differentiator**
**Effort: Large (2-3 weeks)**
**Depends on: mysql-wire package (for typed Performance Schema APIs)**

**Status:** Implemented in Echo
- dashboard metrics now appear in MySQL Activity Monitor
- Performance Schema/sys reports now appear in the MySQL Activity Monitor via typed `mysql-wire` report APIs
- the MySQL performance report surface now supports row filtering and quick CSV/Markdown export from the current report view
- MySQL query tabs now participate in the shared execution-plan UI via `EXPLAIN FORMAT=JSON`
- MySQL query tabs now parse `EXPLAIN ANALYZE` tree output into actual row / loop / elapsed plan metrics
- the MySQL report picker now includes the key memory and file-I/O sys reports alongside statement, runtime, scan, wait, host, and schema statistics views

#### What to Build

**4.1 Performance Dashboard** — Real-time metrics with charts

Replicate Workbench's dashboard layout:

| Section | Metrics | Source |
|---|---|---|
| **Network** | Incoming/outgoing bytes/sec, connection count | `SHOW GLOBAL STATUS` deltas |
| **MySQL** | Statements/sec by type (SELECT, INSERT, UPDATE, DELETE), table cache hit ratio | `Com_select`, `Com_insert`, etc. deltas |
| **InnoDB** | Buffer pool usage %, read requests/sec, write requests/sec, disk reads/sec | `Innodb_buffer_pool_*` status vars |
| **InnoDB Writes** | Redo log writes, physical writes, doublewrite writes | `Innodb_os_log_written`, `Innodb_data_writes` |
| **InnoDB Reads** | Disk reads graph (120s window), bytes read | `Innodb_data_read`, `Innodb_data_reads` |

Use `ActivityMonitorSparklineStrip` for charts. Poll every 2 seconds.

**4.2 Performance Schema Reports** — Top 10 most useful reports

| Report | Query Source | Priority |
|---|---|---|
| Statement Analysis | `sys.statement_analysis` | Must-have |
| Top 5% by Runtime | `sys.statements_with_runtimes_in_95th_percentile` | Must-have |
| Full Table Scans | `sys.statements_with_full_table_scans` | Must-have |
| Unused Indexes | `sys.schema_unused_indexes` | Must-have |
| Schema Index Stats | `sys.schema_index_statistics` | Must-have |
| Schema Table Stats | `sys.schema_table_statistics` | Must-have |
| Top Memory by Event | `sys.memory_global_by_current_bytes` | Should-have |
| Top File I/O | `sys.io_global_by_file_by_bytes` | Should-have |
| Global Waits | `sys.waits_global_by_latency` | Should-have |
| User Overview | `sys.user_summary` | Should-have |

Each report is a simple table view with column sorting and export.

**4.3 Visual EXPLAIN** — Query execution plan visualization

| Component | Implementation |
|---|---|
| Text EXPLAIN | `EXPLAIN sql` → table output (already have result grid) |
| JSON EXPLAIN | `EXPLAIN FORMAT=JSON sql` → parse JSON, extract cost model |
| Visual tree | Render as node graph: nested loops, table scans, index lookups |
| Cost coloring | Red = expensive (cost > threshold), green = efficient |
| EXPLAIN ANALYZE | `EXPLAIN ANALYZE sql` (MySQL 8.0.18+) — actual vs estimated rows |

**Where it goes:**
- `Echo/Sources/Features/ActivityMonitor/Views/MySQL/MySQLPerformanceDashboard.swift`
- `Echo/Sources/Features/ActivityMonitor/Views/MySQL/MySQLPerformanceReports.swift`
- `Echo/Sources/Features/QueryWorkspace/Views/ExecutionPlan/MySQLExecutionPlanView.swift`
- Package: `mysql-wire` `client.performance.*` namespace

---

### Phase 5: Backup & Restore
**Priority: Medium — users expect this**
**Effort: Medium (1-2 weeks)**
**Depends on: MySQLToolLocator for mysqldump/mysqlpump paths**

**Status:** Implemented in Echo
- MySQL tool discovery now covers `mysqldump`, `mysql`, and `mysqlpump`
- Echo now has a dedicated MySQL tool-path preference, matching the same settings-driven tool override pattern used for PostgreSQL
- the backup and restore sheets follow the same sidebar/detail maintenance pattern as PostgreSQL, with source/destination open/reveal actions and richer mysqldump/mysql options for schema/data scope, table selection, locks, compression, extended inserts, force-continue, and restore character set control

#### What to Build

**5.1 MySQL Tool Locator** — Find `mysqldump`, `mysql`, `mysqlpump` on the system

Search order (matching PostgresToolLocator pattern):
1. Environment variable: `ECHO_MYSQL_TOOL_PATH`
2. App bundle: `SharedSupportURL/MySQLTools`
3. Homebrew: `/opt/homebrew/opt/mysql@{8.4,8.0}/bin`, `/usr/local/opt/mysql/bin`
4. Standard: `/usr/local/mysql/bin`
5. Fallback: `which mysqldump`

**5.2 Backup Sheet** — mysqldump wrapper UI

| Option | Flag |
|---|---|
| Schema selection | `--databases db1 db2` |
| Table selection | `db table1 table2` |
| Include routines | `--routines` |
| Include events | `--events` |
| Include triggers | `--triggers` (default on) |
| Schema only | `--no-data` |
| Data only | `--no-create-info` |
| Single transaction | `--single-transaction` (InnoDB) |
| Lock tables | `--lock-tables` (MyISAM) |
| Output file | `--result-file=path` |
| Compression | `--compress` |
| Extended INSERT | `--extended-insert` (default on) |

Execute as a Process, stream stdout to file, show progress.

**5.3 Restore Sheet** — mysql client wrapper

| Option | Flag |
|---|---|
| Source file | `mysql < file.sql` |
| Target schema | `--database=db` |
| Force continue | `--force` |

**Where it goes:**
- `Echo/Sources/Core/DatabaseEngine/Dialects/MySQL/MySQLToolLocator.swift` — new
- `Echo/Sources/Features/Maintenance/Views/MySQL/MySQLBackupSheet.swift` — new
- `Echo/Sources/Features/Maintenance/Views/MySQL/MySQLRestoreSheet.swift` — new

---

### Phase 6: Schema Diff & Sync
**Priority: Medium — power users want this**
**Effort: Medium (1-2 weeks)**
**Depends on: Phase 1 (MySQL DDL generator) + mysql-wire**

**Status:** Implemented in Echo

#### What to Build

**6.1 Schema Comparison** — Compare two databases or a database vs snapshot

For each object type (tables, views, routines, triggers, events):
1. Fetch object list from source and target
2. Match by name
3. For matched objects, compare DDL (via `SHOW CREATE`)
4. Classify: added, removed, modified, identical

**6.2 Diff Viewer** — Side-by-side DDL diff with syntax highlighting

**6.3 Migration SQL Generation** — Generate ALTER statements to transform source → target

This builds on the existing `SchemaDiffViewModel` pattern from PostgreSQL. The MySQL dialect dispatch, object inventory, DDL comparison, migration SQL generation, object filtering, search, and migration-script export are now wired in Echo.

**Where it goes:**
- Extend existing `Echo/Sources/Features/SchemaDiff/` to support MySQL
- Add MySQL to the `SchemaDiffViewModel` dialect dispatch

---

### Phase 7: Stored Routine & Event Editor
**Priority: Medium**
**Effort: Medium (1-2 weeks)**
**Depends on: mysql-wire**

**Status:** Implemented in Echo

- Echo now exposes a dedicated MySQL Advanced Objects workspace that matches the existing multi-section object-management pattern used elsewhere in the app
- functions, procedures, triggers, and events all have typed inventory views backed by `mysql-wire`
- selected objects can open their current definition directly into a query tab, and new objects can be scaffolded through native sheet-based script template editors

#### What to Build

**7.1 Routine Editor** — Dedicated editor for functions and procedures

- Load current definition via `SHOW CREATE FUNCTION/PROCEDURE`
- SQL editor with syntax highlighting
- "Apply" generates `DROP FUNCTION IF EXISTS` + `CREATE FUNCTION` (MySQL requires drop+create, no ALTER body)
- Parameter editor: name, type, IN/OUT/INOUT
- Properties: DETERMINISTIC, SQL SECURITY, COMMENT, SQL DATA ACCESS

**7.2 Event Editor** — Scheduler event management

- List events: `SELECT * FROM information_schema.events WHERE event_schema = ?`
- Create: `CREATE EVENT name ON SCHEDULE AT/EVERY ... DO ...`
- Alter: `ALTER EVENT name [ON SCHEDULE ...] [DO ...]`
- Enable/disable: `ALTER EVENT name ENABLE/DISABLE`
- Drop: `DROP EVENT IF EXISTS name`

**7.3 Trigger Editor** — Trigger management

- Load via `SHOW CREATE TRIGGER`
- Edit body with SQL editor
- Timing (BEFORE/AFTER) + event (INSERT/UPDATE/DELETE) selection
- "Apply" generates `DROP TRIGGER IF EXISTS` + `CREATE TRIGGER`

**Where it goes:**
- `Echo/Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/Sheets/MySQL/` — new directory
- Each editor is a sheet or editor window matching the Properties Editor Window pattern

---

### Phase 8: Import/Export Enhancements
**Priority: Medium**
**Effort: Small-Medium (1 week)**
**Depends on: Phase 5 (Tool Locator)**

**Status:** Implemented in Echo

#### What to Build

**8.1 JSON Export** — Add JSON format to DataExportViewModel

```swift
case json = "JSON"
```
Write array of objects: `[{"col1": "val1", ...}, ...]`

**8.2 JSON Import** — Add JSON source to BulkImportViewModel

Parse array of objects, map keys to columns, generate INSERT statements.

**8.3 SQL INSERT Export** — Export result set as INSERT statements

```sql
INSERT INTO `table` (`col1`, `col2`) VALUES ('val1', 'val2');
```

**8.4 Result Set Export** — Export current query results (not just table data)

Add "Export Results" button to query result grid toolbar. Currently only table context menu has export.

**Where it goes:**
- Extend `DataExportViewModel` with new formats
- Extend `BulkImportViewModel` with JSON source
- Add toolbar button to result grid

The shared Echo import/export flow now includes JSON export, JSON import, SQL INSERT export, a result-grid export button, and direct Table Data import access that work for MySQL through the same UI used by the other dialects. Query results also now expose shared Workbench-style form and field-types detail modes, rather than treating those as MySQL-only one-offs. Spatial results additionally support opening point geometries in the browser from the shared map canvas, covering the MySQL Workbench-style handoff for geographic points without introducing a MySQL-only viewer.

---

## Parity Status: Complete

All MySQL Workbench Community Edition capabilities are now covered in Echo. The final parity items implemented:

- **Diagram Design Tools** — New Table, New Relationship, and Add Note actions in the schema diagram toolbar let users design schema visually from the diagram canvas. Templates open in query tabs with dialect-aware DDL.
- **Model Synchronization** — Synchronize Model button in the diagram toolbar opens schema diff pre-configured with the diagram's schema and auto-runs the comparison, generating ALTER statements to sync the model with the live database.
- **Diagram Annotations** — Draggable, editable text notes on the diagram canvas for documenting schema design decisions.
- **Data Migration Wizard** — Cross-database migration wizard accessible from the database context menu. Supports migrating schema and data between any two active connections (MySQL, PostgreSQL, SQL Server, SQLite) with dialect-aware DDL generation, data type mapping, batched INSERT transfer, and output to query tab, clipboard, file, or direct execution.
- **SQL Execution History** — History tab in the query results bottom panel showing all executed queries with timestamps, duration, row counts, search/filter, re-run, and copy capabilities. History cap increased to 500 queries.

Echo now credibly replaces MySQL Workbench Community Edition for day-to-day MySQL administration and development, with the added benefit of multi-database support across PostgreSQL, SQL Server, MySQL, and SQLite through a unified native macOS interface.

---

## Phase Summary

| Phase | Features | Effort | Depends On | Impact |
|---|---|---|---|---|
| **1. Table Editor** | Visual ALTER TABLE, MySQL DDL generator, column/index/FK editing | 2-3 weeks | Nothing | Critical — #1 gap |
| **2. Server Admin** | Status dashboard, variables browser, log viewer, enhanced process list | 1-2 weeks | Nothing | High — DBA essential |
| **3. User Management** | User CRUD, privilege editor, role management | 2-3 weeks | mysql-wire | High — DBA essential |
| **4. Performance** | Performance dashboard, Performance Schema reports, Visual EXPLAIN | 2-3 weeks | mysql-wire | High — differentiator |
| **5. Backup/Restore** | mysqldump wrapper, restore from file, tool locator | 1-2 weeks | Nothing (just Process) | Medium — expected |
| **6. Schema Diff** | Compare databases, generate migration SQL | 1-2 weeks | Phase 1, mysql-wire | Medium — power users |
| **7. Routine/Event Editor** | Function/procedure/trigger/event editors | 1-2 weeks | mysql-wire | Medium — completeness |
| **8. Import/Export** | JSON format, SQL INSERT export, result set export | 1 week | Phase 5 | Medium — convenience |

**Total estimated effort: 12-18 weeks** for full Workbench Community replacement.

**Recommended execution order:** Phase 1 → Phase 2 → Phase 5 → Phase 3 → Phase 4 → Phase 7 → Phase 6 → Phase 8

This order prioritizes what users interact with daily (table editing, server status, backup) before moving to admin features (users, performance) and completeness (routines, schema diff, export formats).

---

## Package Milestone: mysql-wire

The `mysql-wire` package should be built between Phase 2 and Phase 3. It blocks:
- Phase 3 (User Management) — needs `client.security.*`
- Phase 4 (Performance) — needs `client.performance.*`
- Phase 6 (Schema Diff) — needs typed metadata APIs
- Phase 7 (Routine Editor) — needs `client.admin.*`

This package milestone is complete, so all remaining phases should now build on `mysql-wire`.
