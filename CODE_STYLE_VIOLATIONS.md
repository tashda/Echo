# Code Style Violations

Last updated: 2026-03-15

## DispatchQueue Usage (should use structured concurrency)

| Location | Notes |
| :--- | :--- |
| Sources/Core/DatabaseEngine/ResultStreamBatchWorker.swift | Performance-critical parallel formatting — needs profiling before migration |
| Sources/Shared/DesignSystem/Components/NavigationHistoryToolbar.swift | `DispatchQueue.main.async` for focus workaround |
| Sources/Features/ObjectBrowser/Views/BookmarkSidebarRow.swift | `DispatchQueue.main.async` |
| Sources/Core/DatabaseEngine/Dialects/MSSQL/Modules/SQLServerSessionAdapter+Queries.swift | `DispatchQueue.main.async` |
| Sources/Core/DatabaseEngine/Dialects/Postgres/Modules/PostgresDatabase+Streaming.swift | Multiple `DispatchQueue.main.async` |
| Sources/Features/ConnectionVault/Persistence/ClipboardHistoryStore.swift | Background save queue |
| Sources/Features/QueryWorkspace/Formatting/SQLFormatter.swift | Serial formatting queue |
| Sources/Features/QueryWorkspace/Execution/ResultSpooler.swift | Maintenance queue |
| Sources/Features/ObjectBrowser/Views/Explorer/ExplorerSidebarFocusResetter.swift | `DispatchQueue.main.async` |

~38 files total with ~61 DispatchQueue usages. Replace with `Task {}`, `@concurrent async`, or actors.

## ObservableObject (should use @Observable)

28 types still use `ObservableObject` + `@Published`. Key types:

| Location | Type |
| :--- | :--- |
| Sources/Features/AppHost/Domain/AppDirector.swift | AppDirector |
| Sources/Features/AppHost/Domain/State/TabDirector.swift | TabDirector |
| Sources/Features/AppHost/Domain/State/EnvironmentState.swift | EnvironmentState |
| Sources/Features/AppHost/Domain/State/StatusToastPresenter.swift | StatusToastPresenter |
| Sources/Features/AppHost/Domain/State/NavigationState.swift | NavigationState |
| Sources/Features/AppHost/Domain/State/AppState.swift | AppState |
| Sources/Features/AppHost/Domain/WorkspaceTab.swift | WorkspaceTab |
| Sources/Features/ConnectionVault/Domain/ConnectionSession.swift | ConnectionSession, ActiveSessionGroup |
| Sources/Features/ObjectBrowser/Views/Explorer/ExplorerSidebarViewModel.swift | ExplorerSidebarViewModel |
| Sources/Features/ObjectBrowser/Views/SecuritySidebarViewModel.swift | SecuritySidebarViewModel |
| Sources/Features/ObjectBrowser/Views/AgentSidebar/AgentSidebarViewModel.swift | AgentSidebarViewModel |
| Sources/Features/ObjectBrowser/Search/SearchSidebarViewModel.swift | SearchSidebarViewModel |
| Sources/Features/ActivityMonitor/Domain/ActivityMonitorViewModel.swift | ActivityMonitorViewModel |
| Sources/Features/QueryWorkspace/Domain/QueryEditorState/QueryEditorState.swift | QueryEditorState |
| Sources/Features/QueryWorkspace/Domain/PSQL/PSQLTabViewModel.swift | PSQLTabViewModel |
| Sources/Features/QueryWorkspace/Domain/TableStructureEditor/TableStructureEditorViewModel.swift | TableStructureEditorViewModel |
| Sources/Features/QueryWorkspace/Views/ExtensionStructure/PostgresExtensionsViewModel.swift | PostgresExtensionsViewModel |
| Sources/Features/QueryWorkspace/Views/ExtensionStructure/PostgresExtensionStructureViewModel.swift | PostgresExtensionStructureViewModel |
| Sources/Features/AppHost/Views/Navigation/JobManagement/JobQueueViewModel.swift | JobQueueViewModel |
| Sources/Features/Preferences/Domain/AppearanceStore.swift | AppearanceStore |
| Sources/Features/ConnectionVault/Persistence/ClipboardHistoryStore.swift | ClipboardHistoryStore |
| Sources/Features/SchemaDiagram/Domain/SchemaDiagramModel.swift | SchemaDiagramModel (2 classes) |
| Sources/Shared/Notifications/NotificationEngine.swift | NotificationEngine |
| Sources/Shared/CommonUI/DragDropDelegate.swift | DragDropDelegate |

## Hardcoded Font Sizes (should use TypographyTokens)

| Location | Value |
| :--- | :--- |
| Sources/Features/ObjectBrowser/Views/HistorySidebarView.swift:12 | `.system(size: 40)` |
| Sources/Features/AppHost/Views/Toolbar/RefreshToolbarButton/RefreshToolbarButton+AnimatedOverlay.swift:45 | `.system(size: 13)` |
| Sources/Features/ObjectBrowser/Views/Search/SearchPlaceholderView.swift:13 | `.system(size: 28)` |
| Sources/Features/AppHost/Views/Tabs/EditorContainer/ConnectionDashboardView+Actions.swift:61 | `.system(size: 14)` |
| Sources/Features/AppHost/Views/Inspector/InfoSidebar/JsonInspectorPanelView.swift:118 | `.system(size: 11)` |
| Sources/Features/AppHost/Views/Tabs/TabOverview/TabPreviewCard+Components.swift:27,32 | `.system(size: 11)` |
