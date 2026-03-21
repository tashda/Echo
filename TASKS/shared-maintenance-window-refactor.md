# Task: Shared Maintenance/Activity Monitor Window Components

## Goal

Extract shared components so all database types (MSSQL, PostgreSQL, MySQL, SQLite, MariaDB) use a unified maintenance window pattern. Currently MSSQL and Postgres maintenance views are built differently — MSSQL has a bottom messages panel and status bar, Postgres doesn't. Activity Monitor has ~85% code duplication between MSSQL and Postgres.

## Current Architecture

### Shared components that already exist:
- `TabSectionToolbar` (`Echo/Sources/Shared/DesignSystem/Components/TabSectionToolbar.swift`) — generic toolbar container
- `TabInitializingPlaceholder` (`Echo/Sources/Shared/DesignSystem/Components/TabInitializingPlaceholder.swift`) — loading state
- `TabContentWithPanel` (`Echo/Sources/Features/AppHost/Views/Tabs/TabContentWithPanel.swift`) — split layout with draggable bottom panel
- `BottomPanelState` (`Echo/Sources/Features/AppHost/Domain/BottomPanelState.swift`) — message state, has `.forMaintenanceTab()` factory
- `BottomPanelStatusBar` (`Echo/Sources/Shared/DesignSystem/Components/BottomPanelStatusBar.swift`) — status bar with connection label, segment toggles, status bubbles
- `ExecutionConsoleView` (`Echo/Sources/Features/QueryWorkspace/Views/Results/ExecutionConsole/ExecutionConsoleView.swift`) — message list
- `MaintenanceToolbar` (`Echo/Sources/Features/Maintenance/Views/MaintenanceToolbar.swift`) — 11-line wrapper around TabSectionToolbar

### What's inconsistent:

| Feature | MSSQL Maintenance | Postgres Maintenance |
|---|---|---|
| Bottom panel (messages) | Yes (TabContentWithPanel) | NO |
| Status bar | Yes (connection + status bubbles) | NO |
| Operation feedback | Messages panel | Only in backup sheet |
| Section picker state | In ViewModel | Local @State in view |

Activity Monitor: `MSSQLActivityMonitorView.swift` and `PostgresActivityMonitorView.swift` are both 361 lines with ~85% identical structure.

## Tasks (in priority order)

### 1. Add bottom panel to Postgres Maintenance

**File:** `Echo/Sources/Features/Maintenance/Views/Postgres/PostgresMaintenanceView.swift`

Wrap the content in `TabContentWithPanel` (matching `MSSQLMaintenanceView.swift` pattern). This requires:
- Add `@Bindable var panelState: BottomPanelState` to `PostgresMaintenanceView`
- Create the `BottomPanelState` in `ConnectionSession.addMaintenanceTab()` (file: `Echo/Sources/Features/ConnectionVault/Domain/ConnectionSession.swift`, line ~310)
- Add `ExecutionConsoleView` as the panel content
- Add `BottomPanelStatusBar` with connection text and status bubbles for loading states
- Pass `panelState` to `PostgresBackupRestoreViewModel` so backup/restore results flow to messages

**Reference:** See how `MSSQLMaintenanceView.swift` does it — copy that pattern exactly.

### 2. Extract `MaintenanceTabFrame` shared container

Create a reusable container that all maintenance views use:

```swift
struct MaintenanceTabFrame<SectionPicker: View, Content: View>: View {
    @Bindable var panelState: BottomPanelState
    let statusBarConfiguration: BottomPanelStatusBarConfiguration
    @ViewBuilder let sectionPicker: () -> SectionPicker
    @ViewBuilder let content: () -> Content
}
```

This wraps `TabContentWithPanel` + `MaintenanceToolbar` + `TabInitializingPlaceholder` + `Divider` into one component. Both MSSQL and Postgres maintenance views would use it, and any future database type gets the full pattern for free.

### 3. Extract `ActivityMonitorBase` to reduce duplication

**Files:**
- `Echo/Sources/Features/ActivityMonitor/Views/MSSQL/MSSQLActivityMonitorView.swift` (361 lines)
- `Echo/Sources/Features/ActivityMonitor/Views/Postgres/PostgresActivityMonitorView.swift` (361 lines)

The shared pattern:
```
ActivityMonitorToolbar (section picker)
├── Sparkline strip (4 metrics — different per DB)
├── Divider
└── Section table (switched by enum — different per DB)
    └── Inspector push on selection (different fields per DB)
```

Create `ActivityMonitorContentView<Section: CaseIterable & Hashable>` parameterized by:
- Section enum
- Sparkline metrics array
- Content view builder per section
- Inspector field builder per selection

Each database provides a thin wrapper (50-80 lines) that supplies these parameters.

### 4. Move `MaintenanceToolbar` to absorb common controls

Currently `MaintenanceToolbar` is just a wrapper. Enhance it to include:
- Section picker (passed in)
- Database switcher dropdown (shared pattern)
- Refresh button (shared)
- Status indicator for the selected section

## Key Files to Read

| File | What to learn |
|---|---|
| `MSSQL/MSSQLMaintenanceView.swift` | The "complete" pattern with panel + status bar |
| `Postgres/PostgresMaintenanceView.swift` | What's missing vs MSSQL |
| `MaintenanceView.swift` | The router that switches between MSSQL/Postgres |
| `TabContentWithPanel.swift` | How the split panel works |
| `BottomPanelState.swift` | Factory methods, message appending |
| `BottomPanelStatusBar.swift` | Status bar configuration |
| `ConnectionSession.swift` (lines 254-340) | How maintenance tabs are created |
| `MSSQLActivityMonitorView.swift` | Full activity monitor pattern |
| `PostgresActivityMonitorView.swift` | Compare for duplication |
| `ActivityMonitorSharedComponents.swift` | Already-shared components |
| `ActivityMonitorViewModel.swift` | Shared ViewModel |

## Rules

- Follow CLAUDE.md guidelines (macOS only, design tokens, 200-line view limit, etc.)
- Use `TabContentWithPanel` for the panel — don't build a new one
- Use `BottomPanelState.forMaintenanceTab()` factory
- Don't change the MSSQL maintenance UX — it already works correctly
- The Postgres maintenance health/tables/indexes views stay as-is (they're diagnostics, not operations)
- Build and verify with XcodeBuildMCP (`build_macos`)
