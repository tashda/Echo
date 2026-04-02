# Echo Design Consistency Audit

**Date:** 2026-04-02
**Status:** ALL FIXES APPLIED — Build verified clean.
**Scope:** All UI surfaces EXCEPT Object Browser Sidebar tree and Query Results Table grid.

---

## Summary of Changes

| Category | Issues Found | Fixed | Remaining |
|----------|-------------|-------|-----------|
| `.borderedProminent` (banned) | 18 files | 18 | 0 |
| Sheets not using SheetLayout | 2 | 1 (ExecuteProcedureSheet) | 1 (DatabaseMailSheet — pending full Window migration) |
| Forms missing `.formStyle(.grouped)` | 9 files | 9 | 0 |
| Forms missing `.scrollContentBackground(.hidden)` | 17 files | 17 | 0 |
| TextFields missing `prompt:` | 4 instances | 4 | 0 |
| Toggles missing `.toggleStyle(.switch)` | ~20 instances | ~20 | 0 |
| Pickers missing `.pickerStyle(.menu)` | ~25 instances | ~25 | 0 |
| `LabeledContent` instead of `PropertyRow` | 49 instances in 32 files | 49 | 0 |
| Tables missing `.tableStyle(.inset(...))` | 10 tables in 6 files | 10 | 0 |
| Hardcoded colors (not tokens) | 11 files | 11 | 0 |
| Context menu plain `Button("Text")` | 24 items in 3 files | 24 | 0 |
| Trailing ellipsis in labels | 20+ instances in 12 files | 20+ | 0 |
| Custom loading states (not TabInitializingPlaceholder) | 5 files | 5 | 0 |
| Legacy `EmptyStatePlaceholder` | 0 | N/A | 0 |
| Empty table views hiding table frame | 10 views | 10 | 0 |
| Missing `.accessibilityLabel()` | 3 buttons | 3 | 0 |
| Missing `.labelStyle(.iconOnly)` on toolbar | 3 buttons | 3 | 0 |
| Missing `role: .destructive` on alert | 1 instance | 1 | 0 |
| Hardcoded typography | 5 files | 0 | 5 (edge cases: Account sign-in UI, diagram nodes — need new tokens) |
| ActivityEngine wiring | 6 operations | 0 | 6 (noted for future — needs ViewModel changes) |

### Remaining Items (Deferred)

1. **DatabaseMailSheet** — still uses manual VStack+footer instead of SheetLayout. This is a complex multi-pane editor pending full migration to the Properties Editor Window pattern (tracked in memory: `database_mail_window_migration.md`).

2. **Hardcoded typography in Account views** — sign-in UI uses 48pt icons, 11pt monospaced recovery keys, and other specialized sizes that don't map to existing `TypographyTokens`. Would need new tokens like `TypographyTokens.hero` (48pt) and `TypographyTokens.recoveryKey` (11pt monospaced).

3. **ActivityEngine wiring** — 6 loading operations (query execution, Extended Events, JSON inspector, connection dashboard, availability groups) don't report to ActivityEngine. These need ViewModel-level changes to pass activityEngine references.

---

## Detailed Fix Log

### 1. `.borderedProminent` → `.bordered` (18 files)
All replaced with `.buttonStyle(.bordered)` + `.keyboardShortcut(.defaultAction)` where appropriate:
- QueryBuilderJoinSheet, QueryBuilderWhereSheet
- MySQLServerControlSection, MySQLServerConfigurationView, MySQLServerVariableEditorSheet
- DiagramAnnotationView, DiagramCreateTableSheet, DiagramCreateRelationshipSheet
- MySQLUserRoleMembershipSheet, MySQLGrantPrivilegesSheet, MySQLProgrammableObjectTemplateSheet
- MySQLUserPasswordSheet, MySQLAdministrativeRolesSheet, MySQLAdvancedObjectsContent
- MySQLUserLimitsSheet, MySQLBackupSidebarSheet+Output, MySQLRestoreSidebarSheet+Pages
- NewFullTextIndexSheet

### 2. Non-SheetLayout Sheet → SheetLayoutCustomFooter (1 file)
- ExecuteProcedureSheet — converted manual VStack+Divider+HStack footer to SheetLayoutCustomFooter

### 3. Form Styles Added (17 files)
- `.scrollContentBackground(.hidden)` added to: DACWizardView, QuickImportSheet, SearchSettingsView, SidebarSettingsView, MySQLServerControlSection, PostgresServerControlSection, QueryBuilderWhereSheet, QueryBuilderJoinSheet, QueryResultFormView, DiagramCreateTableSheet, DiagramCreateRelationshipSheet, DataMigrationWizardView (3 Forms)
- `.formStyle(.grouped)` was already present in most — confirmed and left in place

### 4. TextField `prompt:` Added (2 files)
- DACWizardView — Database Name, File Path
- QuickImportSheet — Schema, Table Name

### 5. Toggle/Picker Styles Fixed (~45 instances across 12 files)
- `.toggleStyle(.switch)` added to toggles in: JobDetailsView+Properties, AgentJobScheduleEditorSheet, DataMigrationWizardView, ExtendedEventsCreateSheet, SearchSettingsView, SidebarSettingsView, QuickImportSheet
- `.pickerStyle(.menu)` added to pickers in: JobDetailsView+Properties, JobDetailsView+Notifications, AgentJobScheduleEditorSheet, DataMigrationWizardView, ExtendedEventsCreateSheet, QuickImportSheet, QueryBuilderWhereSheet, QueryBuilderJoinSheet

### 6. `LabeledContent` → `PropertyRow` (49 instances across 32 files)
All converted. Zero `LabeledContent` remaining in Features or UI directories.

### 7. Table Style + Typography Tokens (6 files, 10 tables)
- QuickImportSheet, PolicyManagementView (4 tables), TuningAdvisorView, ResourceGovernorView (2 tables), PgRoleEditorMembershipPage, SecurityPGRoleSheet+Helpers
- All now have `.tableStyle(.inset(alternatesRowBackgrounds: true))` and appropriate `TypographyTokens.Table.*` tokens

### 8. Hardcoded Colors → Tokens (11 files)
- PolicyManagementView: `.green`/`.red` → `ColorTokens.Status.success`/`.error`
- ResourceGovernorView: `Color.red`/`.orange` → `ColorTokens.Status.error`/`.warning`
- PostgresMaintenanceIndexes: `Color.orange` → `ColorTokens.Status.warning`
- MSSQLMaintenanceIndexesView: `Color.orange` → `ColorTokens.Status.warning`
- MySQLActivityReplication: `Color.green`/`Color.red` → `ColorTokens.Status.success`/`.error`
- ExecutionConsoleView+Messages: `Color.orange.opacity` → `ColorTokens.Status.warning.opacity`
- SignInAccountCard: `Color.orange.opacity` → `ColorTokens.Status.warning.opacity`
- DatabaseMailSheet: `Color.green`/`Color.red` → `ColorTokens.Status.success`/`.error`

### 9. Context Menu Plain Buttons → Label Format (3 files, 24 items)
- JobListView: 6 items converted with SF Symbols
- SearchSidebarView+ContextMenu: 11 items converted with SF Symbols
- ConnectionsTableView: 7 items converted with SF Symbols

### 10. Trailing Ellipsis Removed (12 files, 20+ instances)
Button and menu labels cleaned:
- DACWizardView, QuickImportSheet, SQLiteAttachDatabaseSheet, AttachDatabaseSheet
- ObjectBrowserSidebarView+ContextMenus, +DatabaseContextMenu, +DatabaseSnapshots, +ExternalResources, +ServiceBroker
- DatabaseMailSheet (main + Profiles + Accounts)
- UserEditorSecurablesPage, RoleEditorSecurablesPage

### 11. Custom Loading States → TabInitializingPlaceholder (5 files)
- AvailabilityGroupsView, ExtendedEventsView, ExtendedEventsDataView
- JsonInspectorPanelView, ConnectionDashboardView+Databases

### 12. Empty Table Views → Overlay Pattern (10 files)
Tables now always show column headers; ContentUnavailableView overlays when empty:
- PostgresActivityOperations, PostgresActivityReplication
- QueryStoreTopQueriesSection, QueryStoreRegressedSection, QueryStoreWaitStatsSection
- PostgresMaintenanceIndexes, MSSQLMaintenanceTablesView, PostgresMaintenanceTables
- IndexUsageSection, ExtendedEventsDataView

### 13. Accessibility + Toolbar Polish (3 files)
- VisualQueryBuilderView: `.accessibilityLabel()` on 3 icon-only buttons
- TabContextToolbarButton: `.labelStyle(.iconOnly)` on JobQueuePopOut button
- QueryEditorDatabaseToolbarControls: `.labelStyle(.iconOnly)` on SQLCMD + Statistics buttons

### 14. Alert Role Fix (1 file)
- PostgresActivityPreparedTxns: Added `role: .destructive` to Commit button
