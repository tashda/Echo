# Echo Visual Design Guidelines

This document defines the visual standards for every UI element in Echo. All new code and all modifications to existing code **must** follow these guidelines. CLAUDE.md references this file — treat it as mandatory.

Each section names a **golden standard** — an existing implementation that is the reference for that pattern. When in doubt, match the golden standard exactly.

---

## 1. Grouped Forms

**Golden standard:** Settings Window (`Echo/Sources/Features/Preferences/`)

### Structure

```swift
Form {
    Section("Title") {
        PropertyRow(title: "Label") {
            // control
        }
    }
}
.formStyle(.grouped)
.scrollContentBackground(.hidden)
```

### Rules

| Rule | Detail |
|------|--------|
| Form style | Always `.formStyle(.grouped)` |
| Scroll background | Always `.scrollContentBackground(.hidden)` |
| Row component | Always `PropertyRow` — never raw `LabeledContent` or manual HStack |
| Toggle style | `.toggleStyle(.switch)` + `.labelsHidden()` |
| Picker style | `.pickerStyle(.menu)` + `.labelsHidden()` |
| TextField | Always has `prompt:` parameter, `.textFieldStyle(.plain)`, `.multilineTextAlignment(.trailing)` |
| Section titles | Plain string: `Section("Title")` |
| Section footers | `Text(...)` in `footer:` for help/description |
| Info button | Use PropertyRow's `info:` parameter — renders `info.circle` at `.imageScale(.large)` with 280pt popover |

### PropertyRow Anatomy

```
┌─────────────────────────────────────────────────────┐
│  Title (13pt formLabel)              [Control] (ⓘ)  │
│  Subtitle (11pt formDescription, secondary)         │
└─────────────────────────────────────────────────────┘
Min row height: 32pt
Label-subtitle spacing: 2pt
Info popover width: 280pt
```

### Design Tokens Used

- **Typography:** `TypographyTokens.formLabel` (title), `.formDescription` (subtitle), `.standard` (popover text)
- **Colors:** `ColorTokens.Text.primary` (title), `.Text.secondary` (subtitle, info icon, read-only values)
- **Spacing:** `LayoutTokens.Form.*` for all form-specific measurements

---

## 2. Data Tables

**Golden standard:** MSSQL Maintenance Indexes table (`Echo/Sources/Features/Maintenance/Views/MSSQL/MSSQLMaintenanceIndexesView.swift`)

### Structure

```swift
Table(data, selection: $selection, sortOrder: $sortOrder) {
    TableColumn("Name") { item in
        Text(item.name)
            .font(TypographyTokens.Table.name)
    }
    // ...
}
.tableStyle(.inset(alternatesRowBackgrounds: true))
```

### Column Role Taxonomy

Every column in a non-query-result table must use the semantic token that matches its **role** — what the column represents, not just its data type.

| Role | Token | Font | Color | Width | Example Content |
|------|-------|------|-------|-------|-----------------|
| **Primary identifier** | `Table.name` | 13pt regular | `.primary` | Flexible | Index name, table name, database name |
| **Supporting identifier** | `Table.secondaryName` | 13pt regular | `.secondary` or `.tertiary` | Flexible | Owner, schema, app name, client address |
| **Type / category** | `Table.category` | 12pt medium | `.secondary` | 80–100pt | "clustered", "heap", lock mode |
| **Kind badge** | `Table.kindBadge` | 9pt bold | Semantic color | 35–40pt | PK, UQ, IX |
| **Metric** | `Table.numeric` | 13pt monospaced | `.primary` | 60–80pt | Row count, byte size, duration |
| **Percentage** | `Table.percentage` | 12pt medium | `.secondary` | 50pt | Fragmentation %, cache hit ratio |
| **Timestamp** | `Table.date` | 11pt regular | `.secondary` | 130pt | Last backup, stats updated |
| **Status** | `Table.status` | 12pt medium | Semantic color | 100pt | Healthy, Fragmented, Running |
| **File path / technical** | `Table.path` | 11pt monospaced | `.secondary` | Flexible | Device path, LSN, file location |
| **SQL preview** | `Table.sql` | 11pt monospaced | `.primary` | Flexible | Inline query text |

### Null Handling

Empty or null values display an em-dash `"—"` (U+2014) in `ColorTokens.Text.tertiary`. Never show an empty cell.

```swift
if let date = item.lastUpdate {
    Text(date.formatted(date: .abbreviated, time: .shortened))
        .font(TypographyTokens.Table.date)
        .foregroundStyle(ColorTokens.Text.secondary)
} else {
    Text("—")
        .foregroundStyle(ColorTokens.Text.tertiary)
}
```

### Conditional Color Logic

Use color to highlight **anomalies only** — not to decorate normal values.

| Condition | Color | Example |
|-----------|-------|---------|
| Healthy / success | `ColorTokens.Status.success` | "Healthy" status, high cache hit |
| Warning / attention | `ColorTokens.Status.warning` or `.orange` | Zero scans, high unused space |
| Error / critical | `ColorTokens.Status.error` | "Fragmented" status, blocking |
| Informational | `ColorTokens.Status.info` or `.blue` | Unique index badge |

### Table Conventions

- **Style:** `.inset(alternatesRowBackgrounds: true)` — always
- **Default sort:** On a meaningful column (usually descending for metrics)
- **Re-sort after refresh:** Apply current `sortOrder` when data reloads
- **Single-click:** Opens inspector (toggle: false)
- **Double-click row:** Toggles inspector visibility (toggle: true)
- **Double-click column divider:** Auto-resizes the column to fit its longest content. This is standard macOS table behavior and must work on every table in the app. SwiftUI `Table` does not expose this natively — use the `.tableColumnAutoResize()` modifier (in `DesignSystem/Components/`) which introspects the underlying `NSTableView` and implements the delegate method
- **Context menu:** Grouped by concern, dividers between groups

---

## 3. Sheets & Dialogs

### Simple Sheets

**Golden standard:** ColumnEditorSheet (`Echo/Sources/Features/QueryWorkspace/Views/TableStructure/Sheets/ColumnEditorSheet.swift`)

#### Structure

```swift
VStack(spacing: 0) {
    Form {
        // Sections with PropertyRow
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)

    Divider()

    // Footer toolbar
    HStack(spacing: SpacingTokens.sm) {
        if draft.isEditingExisting {
            Button("Delete [Thing]", role: .destructive) { ... }
                .buttonStyle(.bordered)
                .tint(ColorTokens.Status.error)
        }

        Spacer()

        Button("Cancel") { ... }
            .keyboardShortcut(.cancelAction)

        Button("Save") { ... }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal, SpacingTokens.md2)
    .padding(.vertical, SpacingTokens.sm2)
    .background(.bar)
}
.frame(minWidth: 420, idealWidth: 460, minHeight: 340)
.navigationTitle("Edit [Thing]")
```

#### Footer Button Layout

```
┌──────────────────────────────────────────────────────┐
│  [Delete (destructive)]          [Cancel]  [Save]    │
│  ← left                              right →         │
└──────────────────────────────────────────────────────┘
```

#### Rules

| Rule | Detail |
|------|--------|
| Root layout | `VStack(spacing: 0)` — tight control |
| Content | `Form { ... }.formStyle(.grouped).scrollContentBackground(.hidden)` |
| Footer separator | `Divider()` between content and toolbar |
| Footer background | `.background(.bar)` (Liquid Glass) |
| Footer padding | `.horizontal: SpacingTokens.md2`, `.vertical: SpacingTokens.sm2` |
| Destructive button | Left side, `.bordered` + `.tint(ColorTokens.Status.error)`, `role: .destructive` |
| Cancel button | Right side, no explicit `.buttonStyle` (system default), `.keyboardShortcut(.cancelAction)` |
| Primary button | Rightmost, `.borderedProminent`, `.keyboardShortcut(.defaultAction)`, `.disabled(...)` |
| Navigation title | Present — describes the action ("Edit Column", "New Foreign Key") |

### Multi-Pane Sheets

**Golden standard:** MSSQL Database Properties (`Echo/Sources/Features/ObjectBrowser/Views/ObjectBrowserSidebar/Sheets/Database/DatabasePropertiesSheet.swift`)

#### Structure

```swift
VStack(spacing: 0) {
    HStack(spacing: 0) {
        // Sidebar navigation
        List(pages, id: \.self, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.icon)
                .tag(page)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(width: 170)

        Divider()

        // Detail pane
        Form {
            pageContent
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    Divider()

    // Footer
    HStack {
        // Error text (left)
        if let error = statusMessage {
            Text(error)
                .font(TypographyTokens.formDescription)
                .foregroundStyle(ColorTokens.Status.error)
                .lineLimit(1)
        }
        Spacer()
        // Spinner (optional)
        if isSaving { ProgressView().controlSize(.small) }
        Button("Cancel") { ... }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        Button("Done") { ... }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
    }
    .padding(SpacingTokens.md)
}
.frame(minWidth: 640, minHeight: 480)
.frame(idealWidth: 680, idealHeight: 520)
```

#### Rules

| Rule | Detail |
|------|--------|
| Sidebar width | Fixed 170pt |
| Sidebar style | `.listStyle(.sidebar)` + `.scrollContentBackground(.hidden)` |
| Sidebar insets | `.contentMargins(SpacingTokens.xs)` — selection highlight must have padding on all sides from container edges. Matches Apple System Settings / Xcode Settings spacing |
| Detail pane | `Form { ... }.formStyle(.grouped).scrollContentBackground(.hidden)` |
| Footer padding | `.padding(SpacingTokens.md)` |
| Footer layout | `[error text] [Spacer] [spinner] [Cancel .bordered] [Done .borderedProminent]` |
| Min size | 640 x 480 |

### Confirmation Dialogs

**Golden standard:** Drop Table alert (`Echo/Sources/Features/ObjectBrowser/Views/Components/DatabaseObjectRow/DatabaseObjectRow.swift`)

#### Structure

```swift
.alert("Drop Table?", isPresented: $showDropAlert) {
    Button("Cancel", role: .cancel) {}
    Button("Drop", role: .destructive) { performDrop() }
} message: {
    Text("Are you sure you want to drop the table mydb.users? This action cannot be undone.")
}
```

#### Rules

| Rule | Detail |
|------|--------|
| Dialog type | `.alert()` — not `.confirmationDialog()` unless offering multiple non-destructive choices |
| Title | Verb + object type + `?` (e.g., "Drop Table?", "Delete Project?") |
| Message | Explains consequences. Ends with "This action cannot be undone." for irreversible operations |
| Cancel button | `role: .cancel`, always present |
| Action button | Label matches the title verb (Drop → "Drop", Delete → "Delete", Truncate → "Truncate") |
| Destructive actions | `role: .destructive` on the action button |
| Non-destructive confirmations | No role on action button (e.g., "Switch Project") |

---

## 4. Context Menus

**Golden standard:** Explorer Sidebar object context menu (`Echo/Sources/Features/ObjectBrowser/Views/Components/DatabaseObjectRow/DatabaseObjectRow+ContextMenu.swift`)

### Item Format Rules

| Rule | Detail |
|------|--------|
| Item format | Always `Label("Action", systemImage: "icon")` — never plain `Button("Text")` |
| Trailing punctuation | **No** trailing dots, ellipsis, or periods in menu item labels |
| Destructive items | Use `role: .destructive` — system renders in red |
| Dividers | Separate logical groups with `Divider()` |
| Submenus | Use `Menu("Group Name", systemImage: "icon") { ... }` |
| Icons | Every item has an SF Symbol — pick the most semantically relevant icon |

### Canonical Action Group Order

All context menus follow this fixed group order. Not every group appears in every menu — omit groups that don't apply, but never reorder.

```
 1. Refresh                          (arrow.clockwise)
 2. New [Thing]                      (contextual icon — NOT "plus")
    ── Divider ──
 3. Open / Connect / View actions    (arrow.up.right.square, eye, etc.)
 4. Edit / Rename                    (pencil, character.cursor.ibeam)
 5. Copy / Duplicate                 (doc.on.doc)
    ── Divider ──
 6. Script as submenu                (scroll)
    ── Divider ──
 7. Maintenance actions              (hammer, arrow.triangle.2.circlepath, chart.bar)
 8. Enable / Disable                 (checkmark.circle, nosign)
    ── Divider ──
 9. Destructive actions              (trash) — role: .destructive
    ── Divider ──
10. Properties                       (info.circle) — ALWAYS last if present
```

### Divider Rules

A `Divider()` appears between groups from the canonical order, but **only if both adjacent groups have at least one visible item**. Empty groups don't produce orphan dividers.

**Use a Divider when:**
- Switching between action categories (the numbered groups in the canonical order)
- The next item has a fundamentally different consequence than the previous (e.g., read-only → write, safe → destructive)

**Don't use a Divider when:**
- Items are in the same logical group (e.g., Rebuild Index and Reorganize Index are both maintenance — no divider between them)
- There's only one item in a group — a divider around a single orphaned item looks wrong
- Between a submenu and the next group if only one item follows

### Cross-Dialect Consistency

The same semantic action must appear in the **same position** regardless of database dialect. Postgres "Drop Function" and MSSQL "Drop Procedure" both appear in group 10. Postgres "VACUUM" and MSSQL "Rebuild Index" both appear in group 7. The action labels differ by dialect, but the group placement is always the same.

### Script as Submenu Order

The Script as submenu has a fixed order based on what the script does — reads before writes, creates before drops:

```
── Read ──
SELECT TOP 1000 / SELECT ... LIMIT
SELECT COUNT(*)
── Divider ──
── Create / Modify ──
CREATE
CREATE OR REPLACE          (Postgres only)
ALTER
── Divider ──
── Write ──
INSERT
UPDATE
DELETE
── Divider ──
── Execute ──
EXECUTE                    (procedures only)
── Divider ──
── Destroy ──
DROP
DROP IF EXISTS
```

### Icon Rules

| Action | Icon | Notes |
|--------|------|-------|
| Refresh | `arrow.clockwise` | Always wired to ActivityEngine |
| New Table | `tablecells` | Contextual icon matching what is being created |
| New Index | `list.number` | Never use generic `"plus"` for New actions |
| New View | `eye` | |
| New Function | `function` | |
| New Query | `doc.text` | |
| Open / View | `arrow.up.right.square` | |
| Edit | `pencil` | |
| Rename | `character.cursor.ibeam` | |
| Copy | `doc.on.doc` | |
| Script as | `scroll` | Submenu |
| Rebuild | `hammer` | |
| Reorganize | `arrow.triangle.2.circlepath` | |
| Update Statistics | `chart.bar` | |
| Enable | `checkmark.circle` | |
| Disable | `nosign` | |
| Properties | `info.circle` | **Always absolute last** if present |
| Drop / Delete | `trash` | Always `role: .destructive` |
| Truncate | `xmark.bin` | Always `role: .destructive` |
| Kill Process | `xmark.octagon` | Always `role: .destructive` |

### Verb Conventions

| Verb | Use for | Example |
|------|---------|---------|
| **Drop** | Database objects (matches SQL terminology) | Drop Table, Drop Index, Drop Function |
| **Delete** | App-level entities (connections, projects, folders, files) | Delete Connection, Delete Project |
| **Truncate** | Removing all rows from a table | Truncate Table |
| **Kill** | Terminating a running process/session | Kill Process |
| **Remove** | Detaching or unlinking (non-destructive) | Remove from Folder, Detach Schedule |

### Behavioral Rules

| Rule | Detail |
|------|--------|
| **New icon** | Always a contextual SF Symbol matching the object type — **never** `"plus"` |
| **Refresh + ActivityEngine** | Every Refresh action must report progress via `activityEngine?.begin()` |
| **Confirmation required** | Every destructive action (Drop, Truncate, Kill) must trigger a confirmation `.alert()` before executing — no silent destruction |
| **Disabled vs hidden** | If an action exists for this object type but isn't currently available (e.g., "Stop Job" when not running), show it **disabled**. If the action never applies to this type, **hide** it |
| **Multi-selection** | Only show actions that apply to all selected items. Reflect plurality in labels: "Drop 3 Tables", "Rebuild 5 Indexes" |
| **Empty-space menu** | Right-clicking empty space in a list/sidebar shows only creation actions ("New Table", "Refresh") — never item-specific actions |

### Known Deviations (To Fix)

- ~15 files use plain `Button("Text")` without Label/icon
- Several submenus have items without icons
- 2 files use trailing ellipsis in labels
- 4 files have empty `.contextMenu()` blocks
- "New" actions use `"plus"` icon instead of contextual icons
- Some Refresh actions not wired to ActivityEngine

---

## 5. Buttons

**Reference:** Apple HIG — [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

### Style Hierarchy

Use style to communicate importance. Limit `.borderedProminent` to one or two buttons per view — more than that increases cognitive load.

| Style | Purpose | When to Use |
|-------|---------|-------------|
| `.borderedProminent` | Primary action | The single most likely action: Save, Create, Done, Add. Accent-colored background. |
| `.bordered` | Secondary action | Alternatives alongside a primary button, or standalone actions: Cancel (in multi-pane sheets), Browse, destructive buttons. |
| No explicit style | Tertiary action | Cancel in simple sheet footers. Uses system default appearance. |
| `.plain` | Inline / icon-only | Icon-only buttons in forms, sidebars, table rows. No background or border. |
| `.borderless` | Menu trigger | Inline menu triggers in forms (e.g., "Add Mapping" menu button). |

### Button Roles

| Role | Visual Effect | When to Use |
|------|---------------|-------------|
| None (default) | Standard appearance | Normal actions |
| `.destructive` | System red text | Actions that destroy data (Drop, Delete, Truncate). **Never** combine with `.borderedProminent` — even if the destructive action is the most likely choice |
| `.cancel` | Standard appearance, responds to Escape | Cancel/dismiss buttons in alerts |

**Rule:** Never assign `.borderedProminent` (primary) to a destructive button. People sometimes click the prominent button without reading it first.

### Button Labels

**Use a verb or verb phrase.** Start with the action: "Save Changes", "Add to Cart", "Create Database". Use title-style capitalization.

| Label | When to Use |
|-------|-------------|
| **Save** | Persisting changes to an existing entity |
| **Create** | Making a new entity that didn't exist before |
| **Add** | Appending to a collection (Add Column, Add Mapping) |
| **Done** | Completing a view/task with no specific save action, or closing an informational sheet |
| **Cancel** | Dismissing without applying changes. Always use exactly "Cancel" — not "Dismiss", "Close", or "Never Mind" |
| **Delete** | Removing app-level entities (connections, projects) |
| **Drop** | Removing database objects (matches SQL terminology) |
| **OK** | **Only** for purely informational alerts with no action. Avoid in all other contexts |

**Avoid:** "Yes", "No", "Agree", "Understood", "Complete", "Confirm". These are vague — use a specific verb that describes what the button actually does.

### Trailing Ellipsis on Buttons

**Never use trailing ellipsis (`…` or `...`) in button labels.** While Apple HIG suggests ellipsis for buttons that open another view, Echo does not follow this convention — it adds visual noise without meaningful benefit. Button labels should be clean and direct.

```swift
// CORRECT
Button("Browse") { ... }
Button("New Backup") { ... }

// WRONG — no trailing dots
Button("Browse…") { ... }
Button("New Backup...") { ... }
```

### Icons in Buttons

| Context | Icon? | Position |
|---------|-------|----------|
| **Toolbar buttons** | Icon only (no text). Use `.labelStyle(.iconOnly)` | N/A |
| **Sheet footer buttons** | Text only (no icon) | N/A |
| **Context menu items** | Icon + text via `Label(title, systemImage:)` | Icon on leading side (default) |
| **Sidebar action buttons** | Icon only, `.plain` style | N/A |
| **Form inline buttons** | Icon only or icon + text | Icon on leading side |
| **Disclosure / navigation** | Chevron on trailing side | Always trailing |

**Chevron rules:**
- **Never use chevrons in toolbar action buttons** — action buttons trigger operations, not navigation
- **Exception:** Back/Forward navigation buttons (`ToolbarNavigationButtons`) use `chevron.left`/`chevron.right` with `.controlGroupStyle(.navigation)` — this is the standard macOS pattern
- `chevron.right` — sidebar/list rows to indicate expandable content
- `chevron.down` / `chevron.up` — disclosure triangles in tree views
- When chevrons are used (sidebar/navigation only), they appear on the **trailing side**

### Control Size

| Context | Size |
|---------|------|
| Sheet footer buttons | Default (no `.controlSize`) |
| Toolbar secondary buttons | `.controlSize(.small)` |
| Inline form buttons (Browse, Clear) | `.controlSize(.small)` |
| Alert buttons | Default (system-managed) |

### Keyboard Shortcuts

| Shortcut | Modifier | Assign To |
|----------|----------|-----------|
| `.defaultAction` | Return / Enter | Primary button (Save, Create, Done). **Never** on a destructive button |
| `.cancelAction` | Escape / Cmd+. | Cancel button. Always present in sheets |

### Tooltip / Help Text

Every toolbar button must have a `.help("description")` modifier. The tooltip should describe what the button does, not repeat its label.

```swift
Button { ... } label: {
    Label("New Tab", systemImage: "plus")
}
.help("Open a new query tab")
.labelStyle(.iconOnly)
```

### Accessibility

Every icon-only button must have an `.accessibilityLabel()` that describes its action.

```swift
Button { ... } label: {
    Image(systemName: "trash")
}
.buttonStyle(.plain)
.accessibilityLabel("Delete item")
```

### Button Placement Summary

| Location | Leading Side | Trailing Side |
|----------|-------------|---------------|
| **Simple sheet footer** | Destructive action (if any) | Cancel, then Primary (rightmost) |
| **Multi-pane sheet footer** | Error text | Spinner, Cancel (.bordered), Done (.borderedProminent) |
| **Alert** | Cancel (.cancel role) | Action verb (.destructive if applicable) |
| **Toolbar** | Navigation (back/forward) | Actions, then primary (.prominent) rightmost |

## 6. Empty & Loading States

### Empty States

**Standard:** Apple's native `ContentUnavailableView` — ensures Echo looks like a native macOS app.

```swift
ContentUnavailableView {
    Label("No Table Statistics", systemImage: "tablecells")
} description: {
    Text("No user tables found in the selected database.")
} actions: {
    Button("Refresh") { await refresh() }
}
```

#### Rules

| Rule | Detail |
|------|--------|
| Component | `ContentUnavailableView` — Apple's native empty state component |
| Icon | SF Symbol via `Label("Title", systemImage: "icon")` in the label closure |
| Title | Short, descriptive — what's missing ("No Indexes", "No Active Replication") |
| Description | One sentence explaining why or what to do. In `description:` closure |
| Action button | Optional. Use `actions:` closure with a `.bordered` button for the primary recovery action |
| Centering | Automatic — `ContentUnavailableView` centers itself |

#### Migration

`EmptyStatePlaceholder` is the legacy component. New code must use `ContentUnavailableView`. Existing `EmptyStatePlaceholder` usages should be migrated when the file is touched for other reasons.

### Loading States

**Golden standard:** `TabInitializingPlaceholder` (`Echo/Sources/Shared/DesignSystem/Components/TabInitializingPlaceholder.swift`)

```swift
TabInitializingPlaceholder(
    icon: "wrench.and.screwdriver",
    title: "Initializing Maintenance",
    subtitle: "Loading database health data…"
)
```

#### Rules

| Rule | Detail |
|------|--------|
| Component | `TabInitializingPlaceholder` — shared loading visual. Never build custom ProgressView+Text combinations |
| Icon | SF Symbol matching the feature area |
| Title | "Initializing [Feature]" or "Loading [Data]" |
| Subtitle | Describes what's happening: "Loading database health data…", "Waiting for first snapshot…" |
| ActivityEngine | **Every** loading operation must also report to `ActivityEngine` via `activityEngine?.begin()` → `succeed()`/`fail()` |

#### The Two Responsibilities of Every Loading State

1. **Visual** — show `TabInitializingPlaceholder` in the content area so the user sees local feedback
2. **Global** — report to `ActivityEngine` so the toolbar refresh button shows progress and result

```swift
// CORRECT — both visual and global
var body: some View {
    if isLoading {
        TabInitializingPlaceholder(
            icon: "tablecells",
            title: "Loading Tables",
            subtitle: "Fetching table statistics…"
        )
    } else { ... }
}

func loadData() async {
    let handle = activityEngine?.begin("Loading tables", connectionSessionID: connectionSessionID)
    do {
        tableStats = try await session.getTableStats()
        handle?.succeed()
    } catch {
        handle?.fail(error.localizedDescription)
    }
}
```

### Known Deviations (To Fix)

- 5 files use custom ProgressView+Text instead of `TabInitializingPlaceholder`
- ~24 files use legacy `EmptyStatePlaceholder` instead of `ContentUnavailableView`
- Several loading operations not wired to `ActivityEngine`

## 7. Sidebar

**Golden standard:** macOS Finder sidebar. All sidebar items use `SidebarRow`, all section headers use `SidebarSectionHeader`.

### Components

| Component | Purpose |
|-----------|---------|
| `SidebarRow` | Every tree item — databases, tables, folders, jobs, security principals |
| `SidebarSectionHeader` | Top-level group headers — server names, category labels |
| `SidebarConnectionHeader` | Connection root nodes — two-line with name, version, status dot |

### SidebarRow Rules

| Property | Rule |
|----------|------|
| `depth` | Controls indentation — 14pt per level |
| `icon` | `.system("sf.symbol")` or `.asset("name")` — never omit |
| `iconColor` | `ColorTokens.Sidebar.symbol` by default. Turns accent color when selected |
| `label` | 11pt regular (`SidebarRowConstants.labelFont`). Single line, never wraps |
| `subtitle` | Optional, 11pt detail, tertiary color. For metadata (row count, type) |
| `trailing` | Optional trailing content — `CountBadge`, status indicator, action button |
| `isExpanded` | Disclosure chevron shown when bound. Always reserves chevron column space even if not expandable (for alignment) |

### Selection & Hover

| State | Visual |
|-------|--------|
| Rest | No background |
| Hover | `ColorTokens.Sidebar.hoverFill` (5% opacity), 120ms ease-in-out |
| Context menu visible | `ColorTokens.Sidebar.contextFill` (7% opacity) |
| Selected | `ColorTokens.Sidebar.selectedFill` (11% opacity), icon turns accent color |

### Sidebar Metrics (from `SidebarRowConstants`)

| Metric | Value |
|--------|-------|
| Chevron font | 9pt semibold |
| Chevron column width | 12pt |
| Icon font | 14pt regular |
| Icon frame | 18 x 16pt |
| Icon-to-label spacing | 6pt |
| Label font | 11pt regular |
| Indent per depth level | 14pt |
| Row leading padding | 6pt |
| Row trailing padding | 8pt |
| Row vertical padding | 4pt (adjusts with density) |
| Outer horizontal padding | 6pt |
| Hover corner radius | 6pt |

### Section Headers

`SidebarSectionHeader` uses:
- Font: 11pt bold
- Color: `ColorTokens.Text.secondary`
- Optional disclosure chevron (9pt semibold, quaternary color)
- Padding: 12pt top, 2pt bottom

**No uppercase headers in the tree.** Section headers use their natural casing — "Tables", not "TABLES".

### Icon Colors (Explorer Palette)

Database objects use semantic colors from `ExplorerSidebarPalette`:

| Object Type | Color |
|-------------|-------|
| Tables | Cyan |
| Views | Teal |
| Materialized Views | Indigo |
| Functions | Orange |
| Procedures | Red |
| Triggers | Gold |
| Extensions | Mint |
| Jobs | Blue |
| Security | Purple |
| Query Store | Indigo |
| Users/Roles/Logins | Pink |
| Management | Brown |
| Extended Events | Teal |
| Database Mail | Blue |
| Activity Monitor | Orange |

### Density

Sidebar responds to `sidebarDensity` environment value. Row vertical padding adjusts accordingly. Never hardcode row heights — let the density system control spacing.

## 8. Status & Badges

### Status Colors

Use `ColorTokens.Status.*` for all status indication. Never hardcode status colors.

| Status | Token | Use Case |
|--------|-------|----------|
| Success / Healthy | `ColorTokens.Status.success` | Completed operations, healthy indexes, granted locks |
| Warning / Attention | `ColorTokens.Status.warning` | Unused indexes, high space waste, long-running queries |
| Error / Critical | `ColorTokens.Status.error` | Failed operations, fragmented indexes, blocked sessions |
| Info | `ColorTokens.Status.info` | Informational badges, unique index markers |

### Components

**CountBadge** — numeric count in a capsule pill:
- Font: 10pt semibold
- Background: `ColorTokens.Text.primary` at low opacity, capsule shape
- Usage: Sidebar trailing counts, result set row counts

**PulsingStatusDot** — 6pt animated circle:
- Solid when idle, pulses (0.8s breathe) when active
- Usage: Connection status, real-time activity indicators

**StatusToastView** — transient notification in Liquid Glass capsule:
- Icon (13pt semibold) + message (11pt medium)
- Styles: `.success` (green), `.info` (secondary), `.warning` (orange), `.error` (red)
- Background: `.glassEffect(.regular.interactive(), in: .capsule)`
- Usage: Connection state changes, operation results

**StatusWaveOverlay** — ambient glow inside Liquid Glass cards:
- One-shot pulse: fade in 0.3s → hold 0.3s → fade out 1.0s
- Continuous breathe: 1.6s in/out loop
- Usage: Connection card success/failure indication

### Status Badge Pattern for Tables

Status text in data tables uses `TypographyTokens.Table.status` (12pt medium) with semantic colors:

```swift
Text(status)
    .font(TypographyTokens.Table.status)
    .foregroundStyle(statusColor(for: status))

func statusColor(for status: String) -> Color {
    switch status {
    case "Healthy", "Succeeded", "Granted": ColorTokens.Status.success
    case "Warning", "In Progress", "Unused": ColorTokens.Status.warning
    case "Error", "Failed", "Fragmented", "Blocked": ColorTokens.Status.error
    default: ColorTokens.Text.tertiary
    }
}
```

---

## 9. Animation Timings

Use consistent animation durations across the app. Never use arbitrary timing values.

| Animation | Duration | Curve | Usage |
|-----------|----------|-------|-------|
| Hover in | 0.12s | easeInOut | SidebarRow, custom buttons, menu items |
| Hover out | 0.12s | easeInOut | Same as hover in |
| Context menu appear | 0.10s | easeInOut | SidebarRow context fill |
| Context menu disappear | 0.15s | easeInOut | SidebarRow context fill fade |
| Status dot pulse | 0.8s | easeInOut, repeats | PulsingStatusDot breathing |
| Status dot stop | 0.2s | easeInOut | PulsingStatusDot return to solid |
| Toast wave (one-shot) | 0.3s in, 0.3s hold, 1.0s out | easeInOut | StatusWaveOverlay pulse |
| Toast wave (continuous) | 0.6s initial, 1.6s breathe | easeInOut, repeats | StatusWaveOverlay continuous |
| Content transition | `.identity` | instant | Toolbar button label swaps (no cross-fade) |
| Toggle/switch | system default | — | Let the system animate toggles |

### Rules

- **Never use `withAnimation` without specifying duration and curve** — the default 0.35s is often too slow for UI state changes
- **Use `.contentTransition(.identity)` for toolbar buttons** that swap between two states (e.g., show/hide) — prevents distracting cross-fade
- **Let system controls animate themselves** — toggles, pickers, disclosure triangles use system animation. Don't override

---

## Design Token Reference

All visual values must come from design tokens. Never hardcode colors, spacing, fonts, or corner radii.

| Category | Location | Examples |
|----------|----------|---------|
| **Colors** | `ColorTokens` in `ColorToken.swift` | `.Text.primary`, `.Status.error`, `.Sidebar.selectedFill` |
| **Typography** | `TypographyTokens` in `TypographyToken.swift` | `.formLabel`, `.Table.numeric`, `.detail` |
| **Spacing** | `SpacingTokens` in `SpacingToken.swift` | `.xs` (8pt), `.sm` (12pt), `.md` (16pt), `.lg` (24pt) |
| **Layout** | `LayoutTokens` in `LayoutToken.swift` | `.Form.rowMinHeight`, `.Form.infoPopoverWidth` |
| **Shapes** | `ShapeTokens` in `ShapeToken.swift` | `.CornerRadius.small` (6pt), `.medium` (8pt) |
| **Shadows** | `ShadowTokens` in `ShadowToken.swift` | `.cardRest`, `.cardSelected`, `.elevated` |

### Reusable Components

Before building any UI element, check if a component exists in `Echo/Sources/Shared/DesignSystem/Components/`:

| Component | Purpose |
|-----------|---------|
| `PropertyRow` | Form rows with label + control + optional info |
| `SidebarRow` | All sidebar tree items |
| `SidebarSectionHeader` | Sidebar group headers |
| `SidebarConnectionHeader` | Connection root nodes |
| `CountBadge` | Numeric count badges |
| `EmptyStatePlaceholder` | Empty state with icon + title + subtitle + optional action |
| `TabInitializingPlaceholder` | Loading state with spinner + title + subtitle |
| `StatusToastView` | Transient toast notification (Liquid Glass) |
| `PulsingStatusDot` | Animated status indicator |
| `TintedIcon` | Colorful icon in tinted rounded box |
| `ToolbarAddButton` | Circular plus button for toolbars |
| `NativeSplitView` | Native NSSplitView wrapper |
