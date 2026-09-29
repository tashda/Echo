# Current state of the code (September 2026)

> Snapshot from before the build started. Phase 1 has since replaced the window (`WorkspaceShell`) and the rail; `plan.md` notes say what changed.

What Echo's code looked like when the redesign was planned, from a read of the source. Use it to find where things live and what to keep. Paths are relative to `Echo/Sources/`. Line numbers will drift; search for the names.

## Window and navigation

- `Features/AppHost/Views/Navigation/WorkspaceView.swift` builds the window. It is a `NavigationSplitView`:
  - the sidebar is `SidebarColumn`, which holds `SidebarMenu`: the server rail and `ObjectBrowserSidebarView`;
  - the detail is `WorkspaceMainContent`;
  - it has an `.inspector`.
- The toolbar lives in `WorkspaceToolbarItems`, attached from a thin wrapper so it doesn't rebuild.
- **Branch work already done** (`claude/ecstatic-fermi-u1jxr6`). This was an earlier step toward the redesign; the canvas-and-cards shell replaces its placement, but its logic is reusable:
  - a server rail inside the system sidebar (`ServerRail.swift`, `FloatingServerRail.swift`, `ServerRailBridge.swift`, `ServerRailMonogram.swift`, `ServerRailStatusRing.swift`, `ServerRailConnectPicker.swift`, `QueryGlancePanel.swift`, `ExplorerPinnedPathBar.swift`);
  - the old connection dock and icon bar were removed.

  Reusable pieces:
  - the top-visible-row tracking (`ObjectBrowserOutlineView.onTopVisibleContextChanged`, `ObjectBrowserTopVisibleContext`);
  - the monogram rules;
  - the animated reveal scroll;
  - rail entries keyed by connection.

## Explorer tree

- It is an AppKit `NSTableView` (`ObjectBrowserOutlineView.swift`) with one `NSHostingView` per row (`ObjectBrowserRowView.swift`). Snapshots come from `ObjectBrowserSnapshot*.swift`.
- Keep state that changes often out of `ObjectBrowserSidebarView`'s body: every body run rebuilds the whole tree.
- Row look lives in `Shared/DesignSystem/Components/SidebarRow.swift`:
  - four density levels (compact, small, default, large);
  - a 14pt indent and 7pt corners.
- Colours come from `ExplorerSidebarPalette` in `ExplorerRowModels.swift`, which is keyed on folder title strings. Some Postgres colours bypass the tokens.
- `ColorTokens.Sidebar.symbol` and the fills are black-based and don't adapt to appearance.
- Selection is drawn by SwiftUI; the table's own selection is off (`selectionHighlightStyle = .none`).

## Tabs and tab overview

- The strip is `Features/AppHost/Views/Tabs/TabStrip/`, with one style (`.floating`):
  - a 28pt capsule plate in a hard-coded grey (`ColorToken.swift`);
  - a white-gradient active tab, with the database as its subtitle;
  - a glass + button.
- Weak spots in the strip:
  - tabs keep shrinking with no minimum width;
  - a running query isn't shown on its tab;
  - switching tabs isn't animated;
  - tabs are tap gestures, not buttons;
  - the separator drag logic is O(n²).
- The overview is `Views/Tabs/TabOverview/`, opened with ⇧⌘O. It groups tabs by server, then database, then kind.
- Overview bugs:
  - server order is unstable (it iterates a dictionary);
  - tabs are grouped by the connection's default database instead of the active one;
  - "Move to" is an empty stub;
  - running state is a static orange label.

## Toolbar and Run

- `WorkspaceToolbarItems.swift`: most items opt out of shared glass and paint their own (`.sharedBackgroundVisibility(.hidden)` + `.glassEffect`).
- Run is `Shared/DesignSystem/Components/ToolbarRunButton.swift` plus `QueryEditorExecutionToolbarControls.swift`:
  - a neutral play icon, accent when there is a selection, and a red stop while running;
  - ⌘↩ both runs and cancels.
- Shortcut problems:
  - ⌘. isn't bound, although the tooltip says it cancels;
  - ⇧⌘F is bound to both Format SQL and Find in Sidebar;
  - ⇧⌘V (Validate) takes over Paste and Match Style.
- There is no ⌘K palette and no toolbar search. The search engine is `ObjectBrowser/Search/SearchSidebarViewModel*`, which covers objects across servers plus query tabs.
- About 1,500 lines of dead breadcrumb and popover code: `Toolbar/Breadcrumbs/*`, `Toolbar/Popovers/*`.

## Editor

- `Features/QueryWorkspace/Views/Query/SQLTextView/` is a TextKit 1 `NSTextView`. The gutter is `LineNumberRulerView.swift`, fixed at 32pt.
- Gutter problems:
  - wrapped lines repeat their number;
  - 5-digit numbers get clipped;
  - the theme's `gutterBackground`, `gutterAccent` and `currentLine` colours are never drawn.
- Editor and results layout is `AppHost/Views/Tabs/EditorContainer/QueryEditorContainer.swift` with `NativeSplitView`. Opening or closing the results rebuilds the editor (losing its scroll position, undo and focus), with no animation.

## Results grid

- `Features/QueryWorkspace/Views/Results/NativeTable/` is an AppKit `NSTableView` with spreadsheet-style range selection, per-type colours and a row-number gutter.
- Cells are 12pt proportional and left-aligned. NULL is shown as italic text.
- Selection has seams: each row draws its own outline (`ResultTableRowView.swift`).
- The header shows the name only.
- Extra result sets use a second, simpler grid (`AdditionalResultSetTableView.swift`).
- Status bar: `SEC/QueryPanelStatusBar.swift` + `Shared/DesignSystem/Components/BottomPanelStatusBar.swift`, with its database picker in `DatabasePickerPopover`.
- Row counts come from `QueryWorkspace/Domain/RowProgress.swift`: `materialized` vs `totalReported`.

## Notifications and popovers

- `Shared/Notifications/NotificationEngine.swift` routes events (34 categories) to a single toast (`StatusToastPresenter`, `StatusToastView`) and history in the inspector (`NotificationInspectorView`).
- Notification weak spots:
  - a new toast replaces the one showing;
  - text is cut to one line;
  - disabled categories skip history;
  - history isn't kept across launches;
  - query errors bypass the engine.
- There are 13 workspace popovers with mixed widths, paddings and arrow edges. Autocomplete is an `NSPopover` (`SQLAutoCompletionController.swift`).

## Inspector

- `.inspector` in `WorkspaceView`, with content in `AppHost/Views/Inspector/InfoSidebar/`.
- Weak spots:
  - side padding is doubled (18 + 12);
  - panels use three different section styles;
  - width is set by `InspectorSplitViewConfigurator`, which calls `setPosition` seven times, so the width visibly jumps;
  - the chosen tab resets.

## Settings

- `Features/Preferences/Domain/GlobalSettings.swift`. To add a setting: add a property with a default, a `CodingKeys` case, a `decodeIfPresent ?? default` line and an `encode` line.
- Views update settings through `projectStore.updateGlobalSettings`.
- There is no motion setting. Reduce Motion is only honoured by the rail status ring.

## Tests

- CI (Light) runs `.github/workflows/ci-light.yml` via workflow dispatch.
- Four unit tests were already failing on dev (autocomplete ×2, login editor pages, object browser cache migration). They are unrelated to the redesign; a separate task was suggested for them.
