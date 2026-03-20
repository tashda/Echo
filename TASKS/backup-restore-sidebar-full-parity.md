# Task: Backup & Restore — Sidebar Layout + Full SSMS/pgAdmin4 Parity

## Goal

Rewrite the backup and restore popup windows to use a sidebar layout (matching Database Properties) and achieve **full feature parity** with SSMS (SQL Server) and pgAdmin4 (PostgreSQL). No user should need another application to manage their database backups.

The design should be **simpler than pgAdmin4** (which has 6 cluttered tabs) but **complete** — every option SSMS and pgAdmin4 offer must be available in Echo. Group options by intent, not by T-SQL clause.

## Current State

Backup/restore currently uses a single scrolling form sheet. It works for basic operations but lacks:
- Many SSMS options (encryption, media management, striped backups, URL backup, close connections, STANDBY)
- Many pgAdmin4 options (encoding, role, sections, INSERTs mode, table patterns, disable triggers, extra arguments)
- No sidebar navigation — everything is one long scroll

## Design: Sidebar Layout

Use the same pattern as `DatabasePropertiesSheet`: sidebar `List` (170pt) + `Divider` + form content pane. Footer bar with status + action buttons.

### MSSQL Backup Sidebar Pages

| Page | Icon | Contents |
|---|---|---|
| **General** | `doc.badge.plus` | Database name (read-only), Backup type picker (Full/Diff/Log) with description text, Destination path (server-side, monospaced), Backup name, Description |
| **Media** | `opticaldisc` | Overwrite media toggle (INIT/NOINIT) with info, Media set name (MEDIANAME) text field, Verify media name before writing toggle, Format new media set toggle (FORMAT) |
| **Options** | `gearshape` | Compression toggle, Copy-Only toggle, Checksum toggle, Continue on Error toggle, Verify backup when finished toggle (auto-runs RESTORE VERIFYONLY after backup), Expiration date picker (EXPIREDATE) |
| **Encryption** | `lock.shield` | Enable encryption toggle, Algorithm picker (AES_128/AES_192/AES_256/TRIPLE_DES_3KEY), Certificate or Asymmetric Key name field |

### MSSQL Restore Sidebar Pages

| Page | Icon | Contents |
|---|---|---|
| **General** | `arrow.counterclockwise` | Source path (server-side, monospaced), List Backup Sets button, Backup Sets scrollable table, Target database name, File Number |
| **Files** | `doc.on.doc` | File relocation grid (logical name → physical path), editable monospaced text fields |
| **Options** | `gearshape` | Overwrite existing (REPLACE) toggle, Close existing connections (SET SINGLE_USER) toggle, Preserve replication (KEEP_REPLICATION) toggle, Restrict access (RESTRICTED_USER) toggle, Checksum toggle, Continue on Error toggle |
| **Recovery** | `clock.arrow.circlepath` | Recovery mode picker (RECOVERY / NORECOVERY / STANDBY), Standby file path (only when STANDBY selected), Point-in-Time toggle + DatePicker (STOPAT), Tail-log backup toggle (backs up log before restore) |
| **Verify** | `checkmark.shield` | Verify Backup button, result display |

### PostgreSQL Backup Sidebar Pages

| Page | Icon | Contents |
|---|---|---|
| **General** | `doc.badge.plus` | Database name (read-only), Format picker (Custom/Plain SQL/Tar/Directory) with description text, Destination path (local, editable + Browse), Compression stepper (Custom/Directory only), Encoding picker, Role name field |
| **Scope** | `square.dashed` | Schema Only / Data Only toggles (mutually exclusive), Include Blobs toggle (default on), Include tables pattern field, Exclude tables pattern field, Include schemas pattern field, Exclude schemas pattern field, Exclude table data pattern field |
| **Options** | `gearshape` | No Owner toggle, No Privileges toggle, No Tablespaces toggle, Clean (DROP before CREATE) toggle, If Exists toggle (requires Clean), Create Database toggle, Use INSERTs toggle, Column INSERTs toggle (requires Use INSERTs), Rows per INSERT stepper (requires Use INSERTs), On Conflict Do Nothing toggle (requires Use INSERTs) |
| **Advanced** | `wrench` | Parallel Jobs stepper (Directory only), Verbose toggle (default on), Disable Triggers toggle, Disable Dollar Quoting toggle, Force Double Quotes toggle, Use SET SESSION AUTHORIZATION toggle, Lock Wait Timeout field, Extra Float Digits field, Extra Arguments text field (escape hatch for any pg_dump flag not in the UI) |

### PostgreSQL Restore Sidebar Pages

| Page | Icon | Contents |
|---|---|---|
| **General** | `arrow.counterclockwise` | Source file (editable + Browse), Detected format display, Contents table (scrollable), Target database name |
| **Options** | `gearshape` | Clean toggle, If Exists toggle, No Owner toggle, No Privileges toggle, No Tablespaces toggle, Schema Only / Data Only toggles, Create Database toggle, Use SET SESSION AUTHORIZATION toggle, Disable Triggers toggle |
| **Advanced** | `wrench` | Parallel Jobs stepper, Verbose toggle, Extra Arguments text field |

## Implementation Plan

### Phase 1: MSSQL Backup/Restore sidebar (highest impact)

1. **Update sqlserver-nio** with remaining options:
   - `SQLServerBackupOptions`: add `mediaName: String?`, `formatMedia: Bool`, `verifyMediaName: Bool`, `expireDate: Date?`, `encryption: EncryptionOptions?`
   - `SQLServerRestoreOptions`: add `standbyFile: String?`, `keepReplication: Bool`, `restrictedUser: Bool`
   - `buildBackupSQL`: emit MEDIANAME, FORMAT, EXPIREDATE, ENCRYPTION clauses
   - `buildRestoreSQL`: emit STANDBY, KEEP_REPLICATION, RESTRICTED_USER clauses
   - Add `func closeConnections(database:) async throws` — executes `ALTER DATABASE [db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE`
   - Add `func restoreMultiUser(database:) async throws` — executes `ALTER DATABASE [db] SET MULTI_USER`
   - Commit + push to dev

2. **Create `MSSQLBackupSidebarSheet`** — new file replacing `MSSQLMaintenanceBackupsView+BackupForm.swift`
   - Follow `DatabasePropertiesSheet` pattern: sidebar + detail pane
   - Enum `BackupPage: general, media, options, encryption`
   - Each page is a separate `@ViewBuilder` method
   - Footer: progress indicator + Close + Back Up buttons
   - Wire `executeBackup()` to pass all new options
   - Add "Verify after backup" logic: if toggle is on, call `verifyBackup()` after `backup()` succeeds

3. **Create `MSSQLRestoreSidebarSheet`** — new file replacing `MSSQLMaintenanceBackupsView+RestoreForm.swift`
   - Enum `RestorePage: general, files, options, recovery, verify`
   - "Close existing connections" calls `closeConnections()` before restore, `restoreMultiUser()` after
   - Recovery page: picker for RECOVERY/NORECOVERY/STANDBY, standby file path only visible when STANDBY selected

4. **Update `MSSQLBackupRestoreViewModel`** with all new properties:
   - Backup: `mediaName`, `formatMedia`, `verifyMediaName`, `verifyAfterBackup`, `expireDate`, `encryptionEnabled`, `encryptionAlgorithm`, `encryptionCertificate`
   - Restore: `closeConnections`, `standbyFile`, `keepReplication`, `restrictedUser`, `recoveryMode` enum (recovery/norecovery/standby)
   - Add `resetBackupState()` and `resetRestoreState()` methods

5. **Update `MSSQLMaintenanceBackupsView`** — the "New Backup" and "Restore" buttons now present the sidebar sheets

### Phase 2: PostgreSQL Backup/Restore sidebar

6. **Create `PgBackupSidebarSheet`** — replaces `PostgresMaintenanceBackupsView+BackupForm.swift`
   - Enum `PgBackupPage: general, scope, options, advanced`
   - General: format picker with description, destination, compression, encoding (dropdown of PG encodings), role name
   - Scope: schema/data toggles, blobs, table/schema patterns (text fields, comma-separated)
   - Options: all the no-X toggles, clean, if-exists, create database, INSERTs mode
   - Advanced: parallel jobs, verbose, disable triggers, extra arguments text field

7. **Create `PgRestoreSidebarSheet`** — replaces `PostgresMaintenanceBackupsView+RestoreForm.swift`
   - Enum `PgRestorePage: general, options, advanced`
   - Same pattern

8. **Update `PostgresBackupRestoreViewModel`** with all new properties
   - Add all the missing pg_dump/pg_restore flags
   - Update `executeBackup()` to build args from all properties
   - Update `executeRestore()` similarly
   - Extra Arguments field: split by whitespace, append to args array

9. **Update `PgBackupRestoreSheetContainers`** to use the new sidebar sheets

### Phase 3: Shared improvements

10. **Notifications**: backup/restore completion/failure sends notifications (already done for PG, verify MSSQL)
11. **Activity Engine**: all operations report to toolbar (already done)
12. **`.interactiveDismissDisabled()`** during execution (already done)
13. **State reset**: fresh VM per sheet presentation (already done for PG, verify MSSQL)

## Key Files

### Existing (to be rewritten)
| File | Current | Becomes |
|---|---|---|
| `MSSQLMaintenanceBackupsView+BackupForm.swift` | Single form sheet | `MSSQLBackupSidebarSheet.swift` (sidebar) |
| `MSSQLMaintenanceBackupsView+RestoreForm.swift` | Single form sheet | `MSSQLRestoreSidebarSheet.swift` (sidebar) |
| `PostgresMaintenanceBackupsView+BackupForm.swift` | Single form sheet | `PgBackupSidebarSheet.swift` (sidebar) |
| `PostgresMaintenanceBackupsView+RestoreForm.swift` | Single form sheet | `PgRestoreSidebarSheet.swift` (sidebar) |
| `MSSQLBackupRestoreViewModel.swift` | Partial options | Full SSMS parity |
| `PostgresBackupRestoreViewModel.swift` | Partial options | Full pgAdmin4 parity |

### Package (sqlserver-nio)
| File | Changes |
|---|---|
| `SQLServerBackupRestoreClient.swift` | Add encryption, media, standby, close connections, restricted user |

### Reference files (read for patterns)
| File | What to learn |
|---|---|
| `DatabasePropertiesSheet.swift` | Sidebar + detail pane layout |
| `DatabasePropertiesSheet+Types.swift` | Page enum with title/icon |
| `DatabasePropertiesSheet+MSSQLPages.swift` | How MSSQL pages are structured |
| `DatabasePropertiesSheet+Postgres.swift` | How PG pages are structured |

## PostgreSQL Encoding List

For the encoding picker, use this list (from `pg_encoding_to_char`):
`UTF8, LATIN1, LATIN2, LATIN3, LATIN4, LATIN5, LATIN6, LATIN7, LATIN8, LATIN9, LATIN10, SQL_ASCII, EUC_JP, EUC_CN, EUC_KR, EUC_TW, JOHAB, KOI8R, KOI8U, WIN866, WIN874, WIN1250, WIN1251, WIN1252, WIN1253, WIN1254, WIN1255, WIN1256, WIN1257, WIN1258, ISO_8859_5, ISO_8859_6, ISO_8859_7, ISO_8859_8, SJIS, BIG5, GBK, UHC, GB18030, SHIFT_JIS_2004, EUC_JIS_2004, MULE_INTERNAL`

Default: empty (inherits from database).

## MSSQL Encryption Algorithms

For the encryption picker: `AES_128, AES_192, AES_256, TRIPLE_DES_3KEY`

The certificate/key name is a text field — the user types the name of a server certificate or asymmetric key already created on the SQL Server.

## Design Principles

1. **Simpler than pgAdmin4** — don't expose 6 tabs for PostgreSQL. 4 sidebar pages max.
2. **Complete** — every option SSMS and pgAdmin4 offer must be somewhere in the UI. Use "Advanced" page + "Extra Arguments" as escape hatch.
3. **Info popovers on everything** — every toggle/field has an (i) button explaining what it does and when to use it.
4. **Description text under pickers** — format/type pickers have dynamic helper text below (already established pattern).
5. **Monospaced for paths** — all file/server paths use `TypographyTokens.monospaced`.
6. **Footer status** — progress spinner during execution, checkmark on success, cross on failure.
7. **Selectable output** — all result text uses `.textSelection(.enabled)`.
8. **Match Database Properties** visual style — same sidebar width (170pt), same footer layout, same form style.

## What NOT to do

- Don't add file/filegroup backup for MSSQL (SSMS has it but it's rarely used — defer)
- Don't add striped backup to multiple files (SSMS has it but niche — defer)
- Don't add URL backup to Azure Blob (important but needs Azure auth work — separate task)
- Don't build a visual restore timeline/plan (SSMS has it but complex — defer)
- Don't build a local backup history tracker for PostgreSQL (discussed and deferred)

## Verification

After implementation, test:
1. MSSQL: Full backup with checksum + verify after → should show VERIFYONLY result
2. MSSQL: Restore with REPLACE + close connections → should work on active database
3. MSSQL: Backup with encryption → verify SQL includes ENCRYPTION clause
4. PG: Backup with encoding override → verify --encoding flag
5. PG: Backup with table include/exclude → verify --table/--exclude-table flags
6. PG: Backup with INSERTs mode → verify --inserts flag
7. PG: Restore with extra arguments → verify custom flags are passed
8. Both: Verify sidebar navigation works, all pages accessible
9. Both: Verify `.interactiveDismissDisabled()` during execution
10. Both: Verify info popovers on all options
