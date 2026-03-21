# Task: Detached Operation Windows (Non-Modal Backup/Restore)

## Problem

Backup and restore operations can take minutes for large databases. Currently they run inside a `.sheet()` which is modal on macOS — it blocks the entire parent window. Users can't browse schema, run queries, or do anything else while a backup is running.

SSMS and pgAdmin4 both use separate windows for backup/restore, allowing the user to continue working.

## Proposed Solution

Replace `.sheet()` with a **floating NSPanel** (or SwiftUI Window) for long-running operations. The panel:
- Is non-modal — user can interact with the main window
- Floats above the main window (stays visible)
- Shows the form initially, then switches to progress view during execution
- Can be minimized to a small progress indicator
- Auto-closes on success (with notification), stays open on failure

## Architecture Options

### Option A: NSPanel (AppKit)
Use `NSPanel` with `NSHostingView` for the SwiftUI content.

**Pros:** Full control over window behavior (floating, non-modal, utility style). This is how SSMS does it.

**Cons:** Requires bridging between SwiftUI and AppKit. Need to manage window lifecycle manually.

```swift
class OperationPanelController: NSWindowController {
    convenience init<Content: View>(content: Content, title: String) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 520),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isFloatingPanel = true
        panel.contentView = NSHostingView(rootView: content)
        self.init(window: panel)
    }
}
```

### Option B: SwiftUI Window (macOS 13+)
Use `@Environment(\.openWindow)` with a `WindowGroup` for operation windows.

**Pros:** Pure SwiftUI. Uses the system window management.

**Cons:** Each window type needs a `WindowGroup` registered in the App scene. Window identity management is more complex. Can't control floating behavior easily.

### Option C: SwiftUI `.windowStyle(.plain)` panel
Use a dedicated `Window` scene with utility style.

**Pros:** Clean SwiftUI approach.

**Cons:** Limited control over window placement and floating behavior.

## Recommendation

**Option A (NSPanel)** for maximum control. It's the standard macOS pattern for utility windows. The NSPanel can:
- Float above the main window
- Not appear in the Window menu
- Auto-hide when the app is deactivated (`.hidesOnDeactivate`)
- Be sized appropriately for the operation form

## Scope

This applies to ALL long-running operations, not just backup/restore:
- PostgreSQL backup (pg_dump)
- PostgreSQL restore (pg_restore)
- MSSQL backup
- MSSQL restore
- Bulk import (BCP)
- Future: index rebuild, vacuum full, etc.

The operation panel should be a shared component that any feature can use:

```swift
OperationPanel.show(title: "Back Up Database") {
    PostgresBackupSheet(viewModel: vm, ...)
}
```

## Key Files
- Current sheet containers: `PgBackupRestoreSheetContainers.swift`
- MSSQL backup sheets: `MSSQLMaintenanceBackupsView+BackupForm.swift`
- Bulk import: `BulkImportSheet.swift`
- Existing NSPanel usage in Echo: search for `NSPanel` to find patterns
