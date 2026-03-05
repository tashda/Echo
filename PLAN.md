# Rebase 2026 — Fix Plan

## Phase 1: Remove Theme Engine, Fix Hardcoded Styles, Extract Shared Functions

### Step 1.1: Delete AppColorTheme (the custom theme engine)

**Delete these files entirely:**
- `Features/Preferences/Domain/AppColorTheme.swift`
- `Features/Preferences/Domain/AppColorTheme+BuiltIn.swift`
- `Shared/CommonUI/Components/PaletteEditorView.swift`
- `Shared/CommonUI/Components/PalettePreview.swift`

**Modify `GlobalSettings.swift` — remove theme fields:**
- Remove properties: `customThemes`, `activeThemeIDLight`, `activeThemeIDDark`, `themeTabs`, `themeResultsGrid`, `defaultEditorTheme`
- Remove methods: `activeThemeID(for:)`, `theme(withID:tone:)`
- Remove corresponding CodingKeys, init(from:), encode(to:) lines
- Keep decoding graceful (just stop writing/reading those keys)

**Modify `SQLEditorThemeResolver.swift` — bypass AppColorTheme:**
- Replace `resolveApplicationTheme()` to derive surface colors directly from the resolved `SQLEditorPalette` instead of `AppColorTheme`
- The palette already has `background`, `text`, `gutterBackground`, `gutterText`, `selection`, `currentLine` — use those directly

**Modify `SQLEditorTheme.swift` — fix fallback():**
- Replace `AppColorTheme.builtInThemes(for:)` call with direct `SQLEditorPalette` lookup
- Use `SQLEditorPalette.midnight` / `.aurora` directly for surface colors

**Modify `AppState.swift` — remove `themeTabs`:**
- Remove `@Published var themeTabs`

**Modify `AppCoordinator.swift` — remove theme wiring:**
- Remove `appState.themeTabs = global.themeTabs` line
- Simplify `applyEditorAppearance` — no more `themeTabs`

**Modify `QueryTabStrip.swift` — remove themeTabs guard:**
- Remove `guard appState.themeTabs` conditional; always use default tab chrome

**Modify `QueryInputSection.swift` — remove diagnostic function:**
- Remove `logEditorThemeDiagnostics(resolved:chrome:)` that takes `AppColorTheme` parameter

### Step 1.2: Simplify ThemeManager (remove legacy stubs)

**Replace legacy stub usages across the codebase with direct ColorToken calls:**

| Legacy Stub | Replacement | Files to Update |
|---|---|---|
| `themeManager.windowBackgroundColor` | `ColorTokens.Background.primary` | WorkspaceView, WorkspaceView+Subviews, IdentityEditorSheet, FolderEditorSheet, ManageConnectionsWindowController |
| `themeManager.surfaceBackgroundColor` | `ColorTokens.Background.secondary` | ConnectionsTableView, ManageConnectionsView (+Sidebar, +Details), ColumnEditorSheet, BulkColumnEditorSheet, StreamingTestHarnessView+Components, ResultGridPalette |
| `themeManager.surfaceForegroundColor` | `ColorTokens.Text.primary` | InspectorComponents, JsonInspectorPanelView, ColumnEditorSheet, BulkColumnEditorSheet, ManageConnectionsView+Support |
| `themeManager.useAppThemeForResultsGrid` | Remove guard (always `true`) | ResultGridPalette |
| `themeManager.resultsAlternateRowShading` | `GlobalSettings.resultsAlternateRowShading` (or remove if dead) | ManageConnectionsView+Support, ResultGridPalette |
| `themeManager.activePaletteTone` | `themeManager.effectiveColorScheme == .dark ? .dark : .light` inline | AppCoordinator, InspectorComponents, JsonInspectorPanelView, ManageConnectionsWindowController, ManageConnectionsView+Support, ResultTableHeaderView |

**Then remove all legacy stubs from `ThemeManager.swift`** — keeping only `effectiveColorScheme`, `accentColor`, `applyAppearanceMode()`, `setAccentColor()`.

**Remove `@EnvironmentObject var themeManager` from files that only pass-through** and don't use any property (ApplicationCacheSettingsView, QueryResultsSettingsView, EchoSenseSettingsView, DiagramSettingsView, WorkspaceContentView, etc.)

**Move `ThemeManager.swift` from `Preferences/Views/` to `Preferences/Domain/`** — it's domain logic, not a view.

### Step 1.3: Expand Design Token System

**Update `SpacingToken.swift` — add missing mid-point values:**
- Add `xxxs2 = 3` (or skip)
- Add `xxs2 = 6` (50 usages in codebase)
- Add `xs2 = 10` (34 usages)
- Add `sm2 = 14` (21 usages)
- Add `md2 = 20` (23 usages)
- Add `lg2 = 30` (3 usages)
- Add `xl2 = 40` (6 usages)

**Update `TypographyToken.swift` — add fixed-size variants for macOS:**
The current semantic styles (`.headline`, `.caption`) don't map reliably to the specific pt sizes this macOS app needs. Add explicit size tokens:
- `compact` = size 9 (toolbar badges)
- `label` = size 10 (sidebar counts)
- `detail` = size 11 (table cells, footnotes)
- `caption2` = size 12 (secondary labels)
- `standard` = size 13 (body/primary UI)
- `prominent` = size 14 (section headers)
- `display` = size 16-18 (large headers)
- `hero` = size 20+ (hero text, icons)

### Step 1.4: Migrate Hardcoded Styles to Design Tokens

This is the largest step. **342 font violations + 66 padding violations + 12 Color(white:) violations across ~80 files.**

Strategy: Work feature-by-feature:
1. `Features/ObjectBrowser/` (zero token adoption currently — worst area)
2. `Features/AppHost/Views/Tabs/` (QueryTabButton, QueryTabStrip, TabChromeSupport have Color(white:) + heavy font/padding violations)
3. `Features/QueryWorkspace/Views/` (Results, Query, TableStructure)
4. `Features/ConnectionVault/Views/`
5. `Features/Preferences/Views/`
6. `Features/SchemaDiagram/Views/`
7. `UI/Diagnostics/` and `UI/Modals/`
8. `Shared/CommonUI/Components/` and `Shared/DesignSystem/Components/`

For each file: replace `.font(.system(size: N))` with `TypographyTokens.X`, replace `.padding(N)` with `SpacingTokens.X`, replace `Color(white: N)` with `ColorTokens.X` or a named semantic color.

### Step 1.5: Extract Shared Formatter Utilities

**Create `Echo/Sources/Shared/CommonUI/Formatters.swift`** with:

```swift
enum EchoFormatters {
    // Duration: ms < 1s, seconds < 60s, Xm Ys >= 60s
    static func duration(_ interval: TimeInterval?) -> String
    static func duration(_ seconds: Int) -> String  // integer overload

    // Bytes: IEC units (B/KB/MB/GB/TB), %.1f precision
    static func bytes(_ count: Int) -> String
    static func byteCount(_ count: UInt64, style: ByteCountFormatter.CountStyle = .memory) -> String

    // Compact number: 1.2M, 350K, or 12,345
    static func compactNumber(_ value: Int) -> String

    // SQL type abbreviation
    static func abbreviatedSQLType(_ dataType: String) -> String
}
```

Use `private static let` cached formatters (`NumberFormatter`, `ByteCountFormatter`).

**Update call sites (17 files):**
- Duration: PerformanceMonitorWindow, QueryEditorState+Performance, ExecutionConsoleView, StreamingTestHarnessModels, StreamingTestHarnessView+Logic, QueryResultsSection+Logic
- Bytes: PerformanceMonitorWindow, QueryEditorState+Performance, StreamingTestHarnessModels, DiagramSettingsView, ApplicationCacheSettingsView+Components, ClipboardHistoryStore
- CompactNumber: TabPreviewCard+Metadata (remove duplicate), TabOverviewHero, QueryResultsSection+Logic
- SQLType: DatabaseObjectColumnRow, AutoCompletionDetailView

### Step 1.6: Extract Shared UI Components

**Create `Shared/DesignSystem/Components/CountBadge.swift`:**
Capsule pill showing a count. Replace 5 copy-pasted instances (SidebarStickySectionHeader, DatabaseObjectBrowserView, TabOverviewDatabaseGroup, TabOverviewServerGroup, TableStructureEditorView+Indexes).

**Create `Shared/DesignSystem/Components/TintedIcon.swift`:**
Icon + tint + 32pt box + rounded background. Replace instances in BookmarkSidebarRow, ClipboardHistoryView.

**Create `Shared/DesignSystem/Components/EmptyStatePlaceholder.swift`:**
VStack with icon, title, subtitle, optional action button. Replace hand-rolled placeholders in ClipboardHistoryView (2 instances), align with existing SearchPlaceholderView pattern.

**Cache `RelativeDateTimeFormatter` instances:**
Fix 3 files (TabOverviewHero, TabPreviewCard+Metadata, SchemaDiagramView) to use `static let` instead of creating new instances per call.

---

## Phase 2: Enforce File Line Limits

### Step 2.1: Split View files exceeding 200 lines

66 files need splitting. Priority by overage (largest first):

**Critical (>400 lines, needs splitting into 2-3 files):**
1. `ClipboardHistoryView.swift` (482) → extract list sections, detail views
2. `QueryTabButton.swift` (468) → extract subviews, state logic
3. `TableStructureEditorView+Layout.swift` (465) → extract section builders
4. `SQLEditorView+Suppression.swift` (455) → extract rule evaluation from view code
5. `QueryTabStrip.swift` (451) → extract tab strip subviews
6. `ResultGridUIKitView.swift` (447) → extract configuration, delegate methods
7. `QueryResultsSettingsView.swift` (441) → extract settings sections
8. `EchoSenseSettingsView.swift` (433) → extract settings sections
9. `ManageConnectionsView.swift` (430) → extract form sections
10. `QueryResultsTableCoordinator+SelectionEvents.swift` (420) → split event handlers
11. `ExecutionConsoleView.swift` (417) → extract console row views
12. `SQLTextView+CompletionFiltering.swift` (414) → extract filter strategies
13. `ManageConnectionsView+Actions.swift` (414) → split action groups
14. `RefreshToolbarButton.swift` (413) → extract subviews, animations
15. `SQLTextView+CompletionUI.swift` (405) → extract window/panel management

**High (300-400 lines, needs splitting into 2 files):**
16-40. ~25 more files in the 300-400 range

**Medium (200-300 lines, minor splits):**
41-66. ~26 files in the 200-300 range — many of these can be brought under 200 by extracting one or two subviews or moving a helper struct to its own file.

### Step 2.2: Split ViewModel files exceeding 300 lines

1. `SearchSidebarViewModel.swift` (314) → extract search execution logic
2. `JobManagementViewModel.swift` (306) → extract job polling/refresh logic

---

## Phase 3: Remaining Issues

### Step 3.1: Fix Naming Violations

**Rename classes (5 files + all references):**
- `TabManager` → `TabCoordinator` (file + class + protocol `TabManagerDelegate` → `TabCoordinatorDelegate`)
- `ThemeManager` → `AppearanceStore` (file + class + all 50+ `@EnvironmentObject` references)
- `ResultSpoolManager` → `ResultSpoolCoordinator` (file + class)
- `DiagramCacheManager` → `DiagramCacheStore` (file + class)
- `DragDropManager` → `DragDropCoordinator` (file + class)

**Rename files:**
- `QueryResultsTableCoordinator+Helpers.swift` → `QueryResultsTableCoordinator+CellInteraction.swift`

**Rename types:**
- `TableStructureSheetHelpers` → `TableStructureSheetComponents`
- `AutocompleteManagementView` → `AutocompleteInspectorView`
- `AutocompleteManagementWindow` → `AutocompleteInspectorWindow`
- `JobManagementView/ViewModel` → `JobQueueView/ViewModel`

**Fix property mismatch:**
- `EnvironmentState.sessionManager` → `EnvironmentState.sessionCoordinator`

**Fix `// MARK: - Helpers` labels** in 7 files → use descriptive labels.

### Step 3.2: Fix File Placement

- Move `EchoApp.swift` from `AppHost/Domain/` to `AppHost/` root
- Move `ProjectDiskStore.swift` from `ConnectionVault/Persistence/` to `AppHost/Persistence/`
- Consolidate clipboard feature: move `ClipboardHistoryModels/Persistence/Store` from `ConnectionVault/Persistence/` to `ObjectBrowser/`
- Move `Bookmark.swift` + `BookmarkRepository.swift` from `AppHost/Domain/` to `ObjectBrowser/Domain/`
- Move `Bundle+Icon.swift` from `AppHost/Views/Navigation/` to `Shared/PlatformBridge/`
- Move `AutocompleteManagementView.swift` from `AppHost/Views/Navigation/` to `Preferences/Views/`
- Move project modal sheets from `UI/Modals/` to their proper feature slices
- Delete empty `Shared/PlatformBridge/ConnectionState.swift`

### Step 3.3: Add Missing Protocols

Define protocols for:
- `TabCoordinator` (after rename)
- `AppearanceStore` (after rename)
- `SQLFormatterService`
- `QueryEditorState` (at minimum, the public interface consumed by views)
- `TableStructureEditorViewModel`
- `SchemaDiagramViewModel`
- `AppCoordinator`

### Step 3.4: Verify Build

After all changes, build the project to ensure no regressions. Run existing tests.
