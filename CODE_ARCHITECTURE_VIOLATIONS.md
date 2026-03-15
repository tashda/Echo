# Code Architecture Violations

Last updated: 2026-03-15

## Files Exceeding Line Limits

### Views exceeding 200 lines

| Location | Lines | Notes |
| :--- | :--- | :--- |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/ObjectBrowserSidebarView+SecurityActions.swift | 491 | Split further |
| Sources/Features/ConnectionVault/Views/ManageConnections/ManageConnectionsView+ProjectImportExport.swift | 486 | Split further |
| Sources/Features/AppHost/Views/Toolbar/Breadcrumbs/BreadcrumbToolbarContent.swift | 481 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/ObjectBrowserSidebarView+SecurityDatabase.swift | 474 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/DatabasePropertiesSheet+MSSQL.swift | 452 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/SecurityPGRoleSheet+Pages.swift | 417 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/NewAgentJobSheet.swift | 399 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/SecurityLoginSheet.swift | 383 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/ObjectBrowserSidebarView+SecurityMSSQL.swift | 376 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/ObjectBrowserSidebarView+Security.swift | 376 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/SecurityPGRoleSheet.swift | 372 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/SecurityUserSheet.swift | 370 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/ObjectBrowserSidebarView+AgentJobs.swift | 329 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/DatabasePropertiesSheet.swift | 302 | Split further |
| Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/WorkspaceTabContainerView+Execution.swift | 282 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/SecurityLoginSheet+Actions.swift | 269 | Split further |
| Sources/Features/ConnectionVault/Views/ManageConnections/ManageConnectionsView+Details.swift | 252 | Split further |
| Sources/Features/ConnectionVault/Views/ConnectionEditor/ConnectionEditorView+Detail.swift | 249 | Split further |
| Sources/Features/QueryWorkspace/Views/TableStructure/Sheets/ForeignKeyEditorSheet.swift | 246 | Split further |
| Sources/Features/ConnectionVault/Views/ConnectionEditor/ConnectionEditorView+DetailSections.swift | 245 | Split further |
| Sources/Features/AppHost/Views/Navigation/WorkspaceView+SplitView.swift | 245 | Split further |
| Sources/Features/QueryWorkspace/Views/Results/NativeTable/QueryResultsTableBridge+CellInteraction.swift | 244 | Split further |
| Sources/Features/Preferences/Views/KeyboardShortcutsSettingsView+Recorder.swift | 237 | Split further |
| Sources/Features/QueryWorkspace/Views/Results/NativeTable/QueryResultsTableBridge+Menu.swift | 229 | Split further |
| Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/ObjectBrowserSidebarView+CreationOptions.swift | 228 | Split further |
| Sources/Features/AppHost/Views/Tabs/WorkspaceContainer/ConnectionsPopoverController.swift | 228 | Split further |
| Sources/Features/Preferences/Views/SettingsWindow.swift | 227 | Split further |
| Sources/Features/QueryWorkspace/Views/Results/Section/QueryResultsSection+Views.swift | 222 | Split further |
| Sources/Features/AppHost/Views/Tabs/TabOverview/TabOverviewTabCard.swift | 218 | Split further |
| Sources/Features/QueryWorkspace/Views/ExtensionStructure/PostgresExtensionsView+Lists.swift | 212 | Split further |
| Sources/Features/QueryWorkspace/Views/TableStructure/TableStructureEditorView+ForeignKeys.swift | 211 | Split further |
| Sources/Features/QueryWorkspace/Views/Query/SQLEditorView/SQLEditorView+SuppressionPresentation.swift | 210 | Split further |
| Sources/Features/QueryWorkspace/Views/Results/NativeTable/QueryResultsTableBridge+SelectionLogic.swift | 202 | Split further |
| Sources/Features/ConnectionVault/Views/ManageConnections/ManageConnectionsView+Sidebar.swift | 202 | Split further |

### ViewModels exceeding 300 lines

| Location | Lines |
| :--- | :--- |
| Sources/Features/QueryWorkspace/Domain/PSQL/PSQLTabViewModel+MetaCommands.swift | 390 |

### Other files exceeding 500 lines

| Location | Lines |
| :--- | :--- |
| Sources/Features/QueryWorkspace/Execution/ResultSpoolTypes.swift | 564 |

## Explicit @MainActor on Types (redundant with MainActor-by-default)

~75 types have explicit `@MainActor` that is redundant because the Echo app module uses `Default Actor Isolation = MainActor`. However, most of these are on `ObservableObject` classes where removing `@MainActor` causes compiler errors. **Fix: migrate to `@Observable` first, then the explicit `@MainActor` becomes removable.**

This is tracked jointly with the ObservableObject migration in CODE_STYLE_VIOLATIONS.md.
