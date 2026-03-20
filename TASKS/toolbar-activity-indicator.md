# Task: Toolbar Activity Indicator Engine

## Status: Implemented (Phase 1 + Phase 2)

## What Was Built

A shared `ActivityEngine` that any component in the app can use to report long-running operations to the toolbar refresh button. The refresh button shows a spinner while operations run, then a checkmark (success) or X (failure) that auto-fades.

## Architecture

### Core Engine

| File | Purpose |
|------|---------|
| `Shared/ActivityEngine/ActivityEngine.swift` | Central hub: `begin()` returns `OperationHandle`, tracks concurrent operations, auto-clears results |
| `Shared/ActivityEngine/ActivityEngineTypes.swift` | `TrackedOperation`, `OperationResult`, `OperationHandle` types |

### How It Works

1. Any operation calls `activityEngine.begin("Backup mydb", connectionSessionID: id)` → gets an `OperationHandle`
2. Operation does its work, optionally calls `handle.updateProgress()` or `handle.updateMessage()`
3. When done: `handle.succeed()`, `handle.fail("reason")`, or `handle.cancel()`
4. The toolbar observes `ActivityEngine` and shows spinner/checkmark/X accordingly
5. Results auto-clear after 1.5s (success) or 3s (failure)

### Toolbar Integration

`RefreshToolbarButton` and `RefreshButtonContent` now read from both `ConnectionSession.structureLoadingState` (existing schema refresh) and `ActivityEngine` (everything else). The existing animated overlay (`RefreshAnimatedOverlay`) required no changes — it already handles all phase transitions.

### Per-Connection Filtering

Operations are tagged with `connectionSessionID`. The toolbar only shows activity for the currently active connection. A backup on connection B doesn't spin the toolbar while viewing connection A.

## Wired Operations

### MSSQL (via `MSSQLMaintenanceViewModel` + `MSSQLBackupRestoreViewModel`)
- Backup database
- Restore database
- Verify backup
- Integrity check (DBCC CHECKDB)
- Shrink database
- Check table
- Rebuild table
- Rebuild all indexes (per table)
- Reorganize all indexes (per table)
- Rebuild single index
- Reorganize single index
- Update table statistics
- Update index statistics

### PostgreSQL (via `MaintenanceViewModel` + `PostgresBackupRestoreViewModel`)
- Backup (pg_dump)
- Restore (pg_restore + plain SQL)
- Vacuum table (regular, full, analyze)
- Analyze table
- Reindex table
- Reindex index

### Bulk Import (via `BulkImportViewModel`)
- BCP bulk copy import (with cancel support)

### Table Structure Editor (via `TableStructureEditorViewModel`)
- Apply DDL changes (ALTER TABLE, CREATE INDEX, etc.)
- Rebuild index

## Future Adoption

These operations can adopt the engine by adding `activityEngine?.begin()` / `handle.succeed()` / `handle.fail()`:

- Query execution (debatable — tab bar already shows execution time)
- Connection establishing (currently handled by `RefreshButtonPendingContent`)
- Extended Events session toggle
- Database properties save
- Security operations (create/alter login, role, user)
- Schema diagram generation
- Drop index (Postgres)

## Key Design Decisions

- **Runs alongside `StructureLoadingState`** — no breaking changes to existing schema refresh flow
- **`OperationHandle` pattern** — prevents ID management bugs, callers can't complete wrong operation
- **Optional `activityEngine`** — all wiring uses `activityEngine?.begin()` so nothing breaks if engine isn't set
- **Per-view-model state preserved** — `backupPhase`, `isApplying`, etc. still drive local sheet UI; the engine drives the toolbar
