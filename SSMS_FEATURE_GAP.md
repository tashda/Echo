# Echo vs SSMS — Feature Gap Analysis

This is a living document. Update status as features are built. The goal is for Echo to match
and exceed SQL Server Management Studio on macOS.

**Reference docs:** `/Users/k/Tools/docs/sql-docs` (local clone of Microsoft sql-docs, ~14,500 files)
**Protocol reference:** `/Users/k/Development/tds-mcp`
**Driver:** `/Users/k/Development/sqlserver-nio`

Status legend: ✅ Done · 🔧 In Progress · ❌ Not Started

---

## Already Built

| Feature | Echo UI | sqlserver-nio | Notes |
|---|---|---|---|
| Query Editor (highlight, format, autocomplete) | ✅ | ✅ | SQLTextView, SQLFormatterService, SQLAutocompleteRuleEngine |
| Results grid (streaming, sorting, column visibility) | ✅ | ✅ | ResultSpoolCoordinator, QueryResultsGridView |
| Object Explorer | ✅ | ✅ | ExplorerSidebarViewModel, DatabaseObjectBrowserView |
| Activity Monitor | ✅ | ✅ | ActivityMonitorView, SQLServerActivityMonitor |
| SQL Agent (jobs, steps, schedules, alerts, operators, proxies) | ✅ | ✅ | AgentSidebarView, SQLServerAgentOperations |
| Security (logins, users, roles, schemas, permissions) | ✅ | ✅ | SecuritySidebarView, SQLServerSecurityClient |
| Table Structure Editor (columns, indexes, FK, constraints) | ✅ | ✅ | TableStructureEditorView |
| Script Generation | ✅ | ✅ | MSSQLScriptProvider |
| Database Properties Sheet | ✅ | ✅ | DatabasePropertiesSheet+MSSQL |
| Schema Diagram (ER) | ✅ | ✅ | SchemaDiagramView, DiagramCoordinator |
| Connection Vault + Keychain | ✅ | ✅ | ConnectionVault, KeychainVault |
| JSON Viewer / Cell Inspector | ✅ | — | JsonViewerSheet, CellValueInspectorPanel |
| Query History + Bookmarks | ✅ | — | HistoryRepository, BookmarkRepository |
| Tab management | ✅ | — | TabStore, WorkspaceTabs |
| PSQL terminal tab | ✅ | — | PSQLTabView |
| SQL Formatter | ✅ | — | SQLFormatterService |
| Export results (clipboard) | ✅ | — | ResultTableExportFormatter (TSV, CSV, JSON, SQL INSERT, Markdown) |
| Clipboard History | ✅ | — | ClipboardHistoryStore |
| Autocomplete Inspector | ✅ | — | AutocompleteInspectorView |
| **Execution Plan Viewer** | ✅ | ✅ | ExecutionPlanView — tree view, XML view, missing indexes. SQLServerSessionAdapter+ExecutionPlan |
| **Query Statistics (IO/TIME)** | ✅ | ✅ | Toggle in query editor prepends SET STATISTICS IO/TIME. Server messages displayed in Messages tab |
| **Extended Properties** | ✅ | ✅ | ExtendedPropertiesSection in table structure editor. SQLServerExtendedPropertiesClient (list, add, update, drop, upsert) |
| **Results to File (Save As)** | ✅ | — | NSSavePanel integration in results context menu. TSV, CSV, JSON, SQL INSERT, Markdown formats |
| **Query Store UI** | ✅ | ✅ | QueryStoreView — top consumers, regressed queries, plan details, force/unforce. SQLServerQueryStoreClient |
| **Backup / Restore** | ✅ | ✅ | BackupSheet + RestoreSheet. SQLServerBackupRestoreClient (full/diff/log backup, restore, HEADERONLY, FILELISTONLY) |
| **Import / Export (BCP)** | ✅ | ✅ | BulkImportSheet — CSV/TSV file picker, column mapping, preview, progress. SQLServerBulkCopyClient |
| **Linked Servers** | ✅ | ✅ | ObjectBrowserSidebarView+LinkedServers. SQLServerLinkedServersClient (list, add, drop, login mapping, test) |
| **Data Classification** | ✅ | ✅ | Colored sensitivity dots on column headers with tooltips. DataClassification model, SQLServerSensitivityClassification |
| **Extended Events** | ✅ | ✅ | ExtendedEventsView — session list, start/stop, live data viewer, create wizard. SQLServerExtendedEventsClient |
| **Template / Snippet Manager** | ✅ | — | SnippetsSidebarView — new sidebar tab with dialect-specific SQL snippets from SQLSnippetCatalog |
| **Always On / Availability Groups** | ✅ | ✅ | AvailabilityGroupsView — group picker, replica table, database table, failover. SQLServerAvailabilityGroupsClient |
| **Database Mail** | ✅ | ✅ | DatabaseMailSheet — profiles, accounts, status, mail queue. SQLServerDatabaseMailClient |
| **Change Tracking / CDC** | ✅ | ✅ | ChangeTrackingSheet — CDC tables with enable/disable, CT database status. SQLServerChangeTrackingClient |
| **Full-Text Search Management** | ✅ | ✅ | FullTextSearchSheet — catalogs, indexes. SQLServerFullTextClient |
| **Maintenance Tasks** | ✅ | ✅ | MaintenanceSheet — CHECKDB, shrink, rebuild/reorganize indexes, update statistics. SQLServerMaintenanceClient |
| **SQLCMD Mode** | ✅ | — | SQLCMDPreprocessor — :setvar, :r, :connect, :error/:out, :quit/:exit, !! directives. Variable substitution with $(varName). 18 tests |
| **T-SQL Debugger** | ✅ | ✅ | Statement-by-statement execution with breakpoints, variable inspection, debug controls (step/continue/stop). TSQLStatementSplitter + DebugControls. 24 tests |
| **Replication** | ✅ | ✅ | ReplicationSheet — publications, subscriptions, distribution agent status. SQLServerReplicationClient |
| **Multi-server Queries (CMS)** | ✅ | ✅ | CMSSheet — server group registration, multi-server query execution. SQLServerCMSClient |

---

## No Remaining Gaps

All SSMS features have been implemented. Echo now has full feature parity with SQL Server Management Studio, plus additional capabilities SSMS lacks (see below).

---

## "Better Than SSMS" Opportunities

Features SSMS lacks that Echo can do natively on macOS.

| Idea | Status | Notes |
|---|---|---|
| Schema Diagram (ER) | ✅ | SSMS has no built-in ER diagram |
| AI Agent Sidebar | ✅ | SSMS has no AI integration |
| Clipboard History | ✅ | SSMS lacks this |
| Native macOS design (Liquid Glass, system materials) | ✅ | SSMS is Windows-only |
| Multi-database tab workspace | ✅ | SSMS is single-connection per query window |
| Dark mode (true native) | ✅ | SSMS dark mode is poor |
| JSON Cell Viewer | ✅ | SSMS shows raw JSON text only |
| Real-time streaming results | ✅ | SSMS buffers all rows before display |
| Git-integrated query history | ❌ | Save query history to a local git repo |
| Query diff / comparison | ❌ | Side-by-side query comparison with diff highlighting |
| Execution plan diff | ❌ | Compare two plans visually |
| Collaborative sessions | ❌ | Share a live query session (future) |

---

## How to Update This Document

When a feature is completed:
1. Move the row from its gap table into **Already Built**.
2. Change ❌ to ✅ in Echo UI and sqlserver-nio columns as appropriate.
3. Add a brief note about the implementation location.

When a new gap is discovered:
1. Add it to the appropriate priority section.
2. Find the relevant sql-docs path using `grep -r "keyword" /Users/k/Tools/docs/sql-docs --include="*.md" -l`.
3. Link to the most specific doc file, not a directory.
