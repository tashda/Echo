# Build plan: canvas and cards

The plan for building the decided design into Echo. Work top to bottom; each phase leaves the app working. Before a task, read the rules it names; after it, update its status here.

**Status:** ☐ not started · ◐ in progress · ☑ done (add the commit) · ⏸ blocked (say on what)
**Owner check:** tasks marked 👁 need the owner to look at them on a Mac before they count as done.

Branch: `claude/ecstatic-fermi-u1jxr6`, based on `dev`. See `current-state.md` for where things live today.

---

## Phase 0 · Foundations

Nothing visible changes. Everything later builds on this.

Notes from building it:
- Views read animations from `@Environment(\.echoMotion)` (`motion.standard`, `.hover`, `.press`, `.liquidLead`, `.liquidTrail`, `allowsLoopingEffects`). Only the main window publishes it (`providesEchoMotion()` in `EchoApp`); other windows get the defaults.
- New settings bind with `projectStore.globalSettingBinding(\.key)` (`Features/Preferences/Views/GlobalSettingBinding.swift`).
- `Color.adaptive(light:dark:highContrastLight:highContrastDark:)` is for fills that can't be a system colour. The tab strip's active and hover gradients still switch on the colour scheme; move them over when working on B1.
- Not built or run yet: the first CI or Mac build of this phase should confirm it compiles.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| F1 | **Motion helper.** One `EchoMotion` API: the house spring (`.bouncy(duration: 0.45, extraBounce: 0.08)`), hover and press eases, liquid-stretch springs, and the pulse. Scaled by the speed setting; fades with Reduce Motion. Exposed as an environment value. | `Shared/DesignSystem/MotionToken.swift` (new) | Views can call `.animation(.echo, …)` / `withAnimation(.echo)`; Reduce Motion gives a 0.18s fade | ☑ 2610636 |
| F2 | **Layout tokens** for the shell: card corner 12, card shadow, gutter 4/6/8, rail sizes (28/34/40), pill padding, floating-surface sizes. | `Shared/DesignSystem/LayoutToken.swift` | Every value in `06-tokens.md` has a token | ☑ 2610636 |
| F3 | **Colour tokens.** Replace literal `Color(white:)`, `Color.white` and `Color.black` in the tab strip and tree fills with adaptive tokens. | `ColorToken.swift`, tab strip, `SidebarRow` | No literal greys in those files; Increase Contrast looks right 👁 | ☑ 2610636, 👁 pending |
| F4 | **New settings** in `GlobalSettings` (decodeIfPresent pattern), each with a control in Preferences: `interfaceMotionSpeed` (default / fast), `workspaceGutter` (4/6/8, default 6), `railItemSize` (small/medium/large), `collapsedServerClick` (peek + ⌘-click reopens / always peek / always reopen), `sidebarMonochromeVariant` (accent on open / pure), `editorGutterStyle` (subtle / tinted), `resultsMonospacedCells` (off). | `Features/Preferences/…` | Old settings files still decode; each control changes its setting | ☑ 2610636 |

## Phase 1 · The shell

The canvas-and-cards window replaces the system sidebar. Rules: `02-layout`, `03-materials`, `04-motion`, `05-components` › Server rail.

Notes from building it:
- `WorkspaceShell` (`AppHost/Views/Navigation/WorkspaceShell.swift`) is the window: rail · tree · content on `ColorTokens.Workspace.canvas`, with `.inspector` and the toolbar attached outside it in `WorkspaceView`. `AppState.isWorkspaceTreeVisible` replaces the split view's column visibility; ⌃⌘S toggles it when the workspace is key (the menu title stays "Toggle Sidebar" for the UI tests).
- The tree stays alive while hidden: it collapses to zero width and fades, so the table keeps its rows, scroll and expansion. Focus and search requests (⇧⌘F, "reveal in Explorer" from search) show it again; rail clicks show it until S6 adds peek.
- Tree width is saved in `@AppStorage("workspace.treeWidth")`, 200–480pt. The gutter between tree and cards is the resize handle (8pt grab area, column-resize pointer, double-click resets to 260pt).
- All tab content sits on one `workspaceCard()` below the strip until E1 splits editor and results. The strip's side padding is 0 so it lines up with the card; check it in B1.
- The translucent canvas isn't a setting yet; `ColorTokens.Workspace.canvas` is the one place to switch it.
- `FloatingServerRail` and `SidebarSplitViewObserver` went with S1; the glance panel, status ring, connect picker, ⌥⌘G and the old `ServerRail`/`QueryGlance` tokens went with S7.
- The rail (`ObjectBrowser/Views/Components/ServerRail.swift`) takes its item size from the `railItemSize` setting and reports clicks as `ServerRailClick` (plain, ⌘, double) from `NSApp.currentEvent`, ready for S6. The tooltip text is `ServerRailEntry.tooltip(runningQueryCount:)`.
- The rail's tool pill is Bookmarks, Snippets, History, Clipboard. Picking the showing tool again goes back to the tree. Search is still reachable with ⇧⌘F until T6 and Phase 6.
- Peek (S6) reuses the live tree: with the tree hidden and `AppState.peekedServerID` set, the tree shows at full size on regular glass (18pt corners) over the cards while its layout space stays collapsed. A click on the cards, Esc, a tab change or showing the tree puts it away. It doesn't list running queries yet (05-components says the peek lists them); only the tooltip does. Pick that up with the floating card primitive (N1, Phase 7).
- After the owner's first build (decisions 2026-09-29): the + is back as the last item of the server pill and opens `ConnectionsMenuContent` (the toolbar's Connections button is gone); the selection disc is inset 3pt; the tool pill has the server pill's width; the start page shows the 5 latest connections; the card's content has a zero minimum size so it can't push the window; the rail, tree and tab plate sit one gutter below the toolbar and the plate and + line up with the card's edges; the pinned path blur is tinted to the canvas and fades at every edge. The Design Lab rail doesn't have the + yet.
- Empty window (decisions 2026-09-29): `WorkspaceTreeAvailability.hasContent` (in `WorkspaceShell.swift`) keeps the tree hidden with no servers and no tool page; the shell, ⌃⌘S and the new toolbar `SidebarToggleToolbarButton` all use it. ⌃⌘S failed before because the system sidebar menu item took it; `ViewMenuCommands` now uses `CommandGroup(replacing: .sidebar)`. The welcome is `WorkspaceWelcomeView` on the canvas (no card); the old `RecentConnectionsPlaceholder` is gone. UI tests that expect `workspace-sidebar` at launch with no servers may now fail, because the tree is hidden from accessibility until a server connects; update them rather than the rule.
- Tree cards and server page (review round 4): `ObjectBrowserTableView` (in `ObjectBrowserOutlineView.swift`) draws one opaque card per server behind the rows in `drawBackground(inClipRect:)`, from `cardRowRanges`, and lifts the card at the top of the view (`liftedCardIndex`, set from the top-visible tracking). Server gap spacers are `treeCardSpacing` and the top spacer is 1pt so the first card lines up with the rail. The pinned path blur is now tinted to the card colour; T2 replaces it. The server page (`ConnectionDashboardView` and its extensions) sits on the canvas like the welcome, with glass tool buttons (menus for per-database tools) and small `DashboardCard`s with `DashboardCardRow`s.
- Tree scrolling (review rounds 5–7): `ObjectBrowserOutlineView` now returns `ObjectBrowserTreeContainerView`, which holds `ObjectBrowserCardLayerView` (draws each server card with the editor card's tokens, cut to the visible area with rounded corners, a shadow outset around the tree) behind the scroll view (layer-masked to the card corner radius). The table itself draws nothing. `ExplorerPinnedPathBar` is now the glass card header. The snapshot puts pending servers last and spaces cards by the gutter setting. The sidebar toolbar button has its own glass. This covers most of T2 (sticky header with breadcrumb); what remains there is the next header pushing the pinned one up.
- **The Explorer tree is SwiftUI now** (round 8; see `swiftui-tree.md`). `ExplorerTreeLayout` flattens the visible rows with a fixed height per row kind and computes card positions, reveal offsets and the top-visible row. `ObjectBrowserOutlineView` is a flat `LazyVStack` in a `ScrollView` clipped to the card radius, with `ExplorerTreeCardsLayer` behind it drawing one `.workspaceCard()` per server, cut to the visible area. Only that layer reads the scroll offset (`ExplorerTreeScrollState`), so scrolling doesn't re-render rows. The AppKit table, container and card layer are gone. The existing glass header overlay (`ExplorerPinnedPathBar`) now blurs real SwiftUI rows. Still to do: the stress fixture of about 25,000 rows, measured with Instruments.
- S5 was built as part of S1 (the tree shrinks toward the rail and fades while the cards grow, one house-spring animation on `isWorkspaceTreeVisible`).

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| S1 | **Workspace shell.** Replace `NavigationSplitView` with rail · tree · content on a grey canvas (translucent as an option), using the gutter setting. Keep `.inspector`, the toolbar and the sidebar shortcut (⌃⌘S). Add a drag handle to resize the tree. | `WorkspaceView.swift`, new `WorkspaceShell` | Window opens with rail, tree and cards; ⌃⌘S hides and shows the tree; the tree resizes; the inspector still works | ☑ 14e2310, 👁 pending |
| S2 | **Rail, two glass pills.** Servers on top (hug, scroll when full), tools at the bottom (Bookmarks, Snippets, History, Clipboard). The pill grows and shrinks with the spring. Monogram in secondary grey; selected monogram bold, in its server colour. Tooltip on hover. The highlight follows the tree's scroll (reuse `ServerRailBridge.topVisibleConnectionID`). | `ObjectBrowser/Views/Components/ServerRail*.swift` | Matches the Design Lab rail 👁 | ☑ eab78b7, 👁 pending |
| S3 | **Liquid-stretch selection** exactly as in `LabRail.swift`: separate springs for the leading and trailing edges. | Rail | Matches the lab at both speeds 👁 | ☑ eab78b7, 👁 pending |
| S4 | **Rail status.** Connecting servers breathe (strength per `06-tokens`). A lost connection dims the monogram to 40% and its tooltip gives the reason. Running queries show nothing in the rail. | Rail | Pulse stops on connect; a lost server dims; Reduce Motion shows a still, dimmed monogram | ☑ eab78b7, 👁 pending |
| S5 | **Hide tree.** The tree shrinks into the rail and fades while the cards grow, with the house spring. | Shell | Matches the lab 👁 | ☑ 14e2310, 👁 pending |
| S6 | **Peek.** With the tree hidden, a click on a server slides that server's tree out over the cards; a click outside or Esc closes it; ⌘-click or double-click reopens the tree. Behaviour follows the `collapsedServerClick` setting. | Shell + rail | All three setting values work | ☑ dc3524b, 👁 pending |
| S7 | **Remove the old placement.** Delete `FloatingServerRail`, `QueryGlancePanel` and its toggle, the in-sidebar rail layout, and the ⌥⌘G menu item. Keep the reusable logic. | ObjectBrowser components | No dead code left; builds | ☑ eab78b7 |

## Phase 2 · Explorer tree

Rules: `05-components` › Explorer tree.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| T1 | **Tree on server cards:** one opaque card per server (built early, see Phase 1 notes), 12pt indent, server header flush left inside its card. | `SidebarRow`, row view, `ObjectBrowserTableView` | Matches review round 4, option B 👁 | ☑ 938efea (12pt indent; cards, glass header and rounded end earlier), 👁 pending. Stress fixture not built, see notes |
| T2 | ~~**Sticky server header with breadcrumb.**~~ Removed in round 10 (P1). The bold 13pt header pins at the top over a soft fade (no band) and shows "› database" for the database you're in. Either `floatsGroupRows` with group rows, or an overlay driven by the existing top-visible tracking. Replaces `ExplorerPinnedPathBar`. | Outline view, row view | Pins and updates while scrolling, with no rebuild of the tree on scroll 👁 | ☑ b74ac43 (pinned header, as changed by rounds 6–9: soft real blur instead of glass), 👁 pending |
| T3 | **Icon modes.** Colourful uses today's colours softened, keyed by an enum rather than title strings. Monochrome has two variants: accent on open folders (default) and pure. | `ExplorerRowModels.swift`, `ColorToken.swift` | All three look right in light and dark 👁 | ☑ 938efea, 👁 pending. Colours still keyed by title strings, see notes |
| T4 | **Loading:** shimmer rows at the child indent, crossfading into the real rows. Replaces "Expand to load objects…". | Snapshot + row view | Shows while loading, and stops with Reduce Motion | ☑ 08bc0c74, 👁 pending |
| T5 | **Expand motion:** the native slide and fade, with duration from the motion helper. | Outline view | Speed setting changes it | ☑ d5faf78 (built with the SwiftUI tree: `motion.expand`, scaled by the speed setting) |
| T7 | **Row style S4 Quiet** (revised tree card choice): 28pt rows in a 29pt slot, 13pt light symbols, icon replaced by chevron on folder hover, 16pt indent, 8pt corners, grey selection; bold 13pt server name with product and version. | `SidebarRow`, `ExplorerRowModels.swift`, `ObjectBrowserOutlineView.swift` | Matches the lab's S4 👁 | ☑ built, 👁 pending |
| T8 | **Server folders:** server-level groups are folder rows whose children are indented; MySQL and SQLite tools remain under Management. | `ExplorerTreeLayout`, `ExplorerBlueprintWalker.swift` | Folders disclose on hover and counts appear on hover 👁 | ☑ built, 👁 pending |
| T6 | Remove the sidebar Search tool page (search moves to the toolbar in Phase 6). | `SidebarMenuView+Content.swift` | Gone; nothing links to it | ☑ with K4: the page, its views and its cache are gone; View › Search (⌥⌘F) opens the toolbar search |

### Notes from building it (Phase 2 and round 9)

- **Blur under the pinned header** (round 9, after "grey" then "solid"): on macOS, SwiftUI materials and in-window `NSVisualEffectView`s over the tree's SwiftUI rows only tint or fade them, and Core Image background filters don't see SwiftUI content at all. `ExplorerTreeEdgeBlur` draws the rows and card fills under the band again, in four copies blurred at radius 1 to 10 (`LayoutTokens.Workspace.pinnedHeaderBlurRadii`), stronger towards the top, with a light card tint. It reads the scroll offset like the cards layer, so the list never re-renders on scroll.
- **Blur over AppKit content** (the results grid, the editor) is `BackdropEdgeBlur`: stacked Core Image Gaussian background filters. A background filter only sees its own superview, so its views go into the same container as the AppKit view, above it. The Design Lab's footer stage uses it; FB1 would use it in the app.
- **Database switcher** (round 9, DB1, a50abbb): `DatabaseSwitcherCard` grows out of the footer chip with a matched geometry effect. It can't use a `GlassEffectContainer` morph: a text field inside a glass container sent AppKit's key-view walk (the password autofill check) into an endless loop that hung the app.
- **T1 stress fixture:** not built. Real rows need a `ConnectionSession`, which needs a `DatabaseSession`; the app target has no stub for one (the tests' `MockDatabaseSession` lives in EchoTests). The owner's `dkloosql10-d` (about 65 databases) is a real stress case to profile with Instruments' SwiftUI and Hitches templates.
- **T3 gap (closed by BP1):** icon colours now come from each node kind's `ExplorerIconRole`; `ExplorerSidebarPalette` and its title strings are gone. The mode logic is still in one place: `ObjectBrowserRowView.explorerIconColor(_:)`.
- **T4:** a loading row is three shimmer rows high (`LayoutTokens.Shimmer`), and the failed-refresh state is a warning message row instead of a loading row. Loading labels lost their trailing dots and are only read by VoiceOver now.
- **Design Lab:** the first page, "Round 9 · open questions", holds the footer (FB, FP), tree scroll bar (SB) and tab bar (TB) questions. Older lab questions are retired; their pages stay as a reference.

## Phase 2b · Tree blueprints

Accepted in the tree card round (explainer: https://claude.ai/artifact/N7UL1qHMGicpthQmSKVa89). Each database type's tree is an ordered blueprint; the builder, rows and menus are generic. Rules: `05-components` › Explorer tree › How a tree is described.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| BP1 | **Node kind catalogue and roles:** `ExplorerNodeKind` (title, symbol, role, ID component) and `ExplorerIconRole`; the four `*Kind` enums, `objectIconName` and `ExplorerSidebarPalette` go. | `ObjectBrowser/Blueprint/` | Colours never depend on titles; a test checks every symbol exists | ☑ e7d467ed |
| BP2 | **Style as a value:** the S1 metrics live in `SidebarRowConstants` and tokens only. An environment style value waits until there is a second style to switch to. | `ExplorerRowModels.swift`, `SidebarRow` | No raw sizes in `SidebarRow` except the large-density label | ☑ b3f2f25b |
| BP3 | **Generic child sources:** the 35 per-feature dictionaries become `childSources: [ExplorerSourceKey: ExplorerSourceState]`; loaders write `ExplorerItem`s. | View model, loaders, `+ChildSources.swift` | Folders load on expand and when restored open | ☑ e7d467ed |
| BP4 | **Blueprints:** SQL Server, PostgreSQL, MySQL, SQLite, and `ExplorerBlueprintWalker`; the per-type snapshot builders are deleted. | `ObjectBrowser/Blueprint/` | Tests pin each type's order, the object folder order and saved node IDs | ☑ e7d467ed |
| BP5 | **Generic rows:** `ObjectBrowserNode.Row` goes from 25 cases to 13; `ObjectBrowserRowView` from 557 lines to 130 plus two small extensions. | Node, row view | Builds; every row kind renders 👁 | ☑ e7d467ed, 👁 pending |
| BP6 | **Menus by area:** the 1,383-line menu file splits into a dispatcher by node kind plus `+ServerMenus`, `+DatabaseMenus`, `+ObjectMenus`, `+ScriptActions`. | `ObjectBrowserSidebarView+*Menus.swift` | Each file under 500 lines; every menu still opens 👁 | ☑ e7d467ed, 👁 pending |

### Notes from building it (Phase 2b)

- **Adding a database type:** add its case to `ExplorerBlueprint.blueprint(for:)`, write `ExplorerBlueprint+<Type>.swift`, add any new kinds to `ExplorerNodeKind` (title, symbol, role), any new sources to `ExplorerChildSource` with a loader in `+ChildSources.swift`, and menus for new kinds in the matching `+*Menus.swift`. Add its order to `ExplorerBlueprintTests`.
- **Saved expansion state survives:** server folders, database folders, object folders, databases and objects keep their node IDs (`ExplorerNodeKind.idComponent`). Folders nested inside Security (Logins, Server Roles…) got new IDs, so they start collapsed once.
- **Loading is generic:** a folder with a source loads when it's expanded, and folders restored as open load when the tree syncs (`loadSourcesOfOpenFolders`). A folder shows a shimmer while its source loads with nothing yet, "No …" when it's empty, and keeps showing old items while refreshing.
- **Small behaviour changes:** empty-folder lines now read "No logins", "No agent jobs" and so on; disabled agent jobs and linked servers without data access are dimmed; a disabled login's detail reads "SQL · Disabled".
- **Fixed on the way:** the Certificate Logins symbol (`doc.badge.lock`) doesn't exist, so it drew nothing; it's `checkmark.seal` now. `ExplorerBlueprintTests` checks every symbol.
- **Not run in the app:** another Echo instance was running during this work, so the change was verified by build and tests only. Check the menus and loaders on a Mac (👁 on BP5 and BP6).

## Phase 3 · Tabs

Rules: `05-components` › Tabs. Safari is the reference.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| B1 | **Strip on the canvas** above the cards; keep the grey plate and white active tab, using the tokens from F3. | `WorkspaceTabContainerView`, TabStrip | Sits on the canvas with the gutter 👁 | ☐ Superseded by Phase 14 (one-line Round 9 strip, 2026-09-30) |
| B2 | **Running tab:** a spinner at the leading edge and the timer in place of the subtitle. | `QueryTabButton` | Shows while running and clears when done | ☑ 461d69ee, 👁 pending |
| B3 | **Overflow:** a minimum width, then inactive tabs collapse to their icon while the active tab keeps its title. | `QueryTabStrip` | 20+ tabs stay usable | ☐ Superseded by Phase 14 (one-line Round 9 strip, 2026-09-30) |
| B4 | **New tab grows out of +** (+ and the plate share a glass container). Switching tabs stays instant. | Strip | 👁 | ☐ Superseded by Phase 14 (one-line Round 9 strip, 2026-09-30) |
| B5 | Make tabs real buttons (accessibility, focus): a click selects at once, dragging still reorders. **Keep the editors of recently used tabs alive** so switching back keeps scroll, undo and cursor (round 9, TFIX). Fix the O(n²) separator pass and read the hairline width from `displayScale`. | Strip | VoiceOver reads the tabs | ◐ TFIX part done (select on press, three most recent tabs kept alive, focus follows the active tab), 👁 pending; separator pass, hairline width and VoiceOver check still to do |

## Phase 4 · Editor and results cards

Rules: `05-components` › Editor card, Results card.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| E1 | **Two cards** (12pt corners, floating shadow) with the gutter between them. One split kept alive; the results card collapses instead of the view tree switching, so the editor keeps its scroll position, undo and focus. | `QueryEditorContainer`, `NativeSplitView` | Toggling results doesn't reset the editor | ☑ 3249a82a, 👁 pending |
| E2 | **Results card rises** after the first run while the editor card shrinks (house spring). | Same | Matches the lab 👁 | ☑ 3249a82a, 👁 pending |
| E3 | **Resize** by dragging the canvas gap between the cards, with a grab capsule on hover. **Double-click the gap to maximise the results** (the editor becomes a one-line card), and double-click again to restore. Add a menu item and shortcut. | Same | Drag and maximise work; the ratio is saved | ☑ 3249a82a, 👁 pending |
| E4 | **Gutter:** subtle or tinted (setting), current-line emphasis, red validation markers, one number per logical line, width that grows with digit count, theme colours. | `LineNumberRulerView`, `SQLTextView` | 10 000-line script numbered correctly 👁 | ☑ 8367cbad, 👁 pending |

### Notes from building it (Phase 4)

- **Two cards** (`EditorResultsCards`, used by `QueryEditorContainer`): query tabs draw their own editor and results cards (`WorkspaceTab.drawsOwnCards`); every other tab kind still sits on one card, now applied per tab in `WorkspaceTabContainerView.tabContent`. `WorkspaceContentView` draws no fill behind query tabs so the canvas shows in the gap.
- The results card is a SwiftUI split, not `NativeSplitView`: the gap is the handle (`EditorResultsCardGap`, row-resize pointer, grab capsule on hover, double-click to maximise). `BottomPanelState.isResultsMaximized` holds the maximised state; View › Maximize Results is ⌥⇧⌘Y. `splitRatio` (the editor's share) is kept per tab, as before; it isn't remembered across tabs or launches.
- The footer moves between the cards: in the results card when results show, in the editor card otherwise. Where it sits within the card and what's behind it (FP, FB) wait for the Design Lab.
- `resultsSection(isResizingResults:)` still always gets `false`; the grid could pause work while the gap is dragged if resizing turns out slow.
- **Gutter (E4):** `LineNumberRulerView` numbers only logical line starts, counts lines once per draw instead of once per fragment, widens with the digit count (`LayoutTokens.EditorGutter`), draws the current line in the theme's gutter accent, a red dot on lines with validation errors (`errorLines`, from `updateValidationOverlays`), and the tinted style (theme gutter colour plus an edge) from the existing Settings picker, now passed through `SQLEditorDisplayOptions.gutterStyle`.

## Phase 5 · Results grid

Rules: `05-components` › Results card.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| R1 | **Cells:** numbers and dates right-aligned with tabular digits, booleans as ✓/✗, monospaced setting. NULL stays italic text. | `ResultTableDataCellView`, bridge | Matches the lab 👁 | ☑ f4e19a5, 👁 pending |
| R2 | **Header:** name + type line; a sort arrow on hover that sorts; clicking elsewhere selects the column. SF chevrons replace the Touch Bar images. | `ResultTableHeaderCell/View` | Matches the lab 👁 | ☑ 1bf5a72, 👁 pending |
| R3 | **Selection:** one outline per range, a ring on the active cell, row numbers in accent. | `ResultTableRowView`, `ResultTableView` | No seams in multi-row selections | ☑ c9f823e, 👁 pending |
| R4 | **Row hover:** a faint rounded tint, and the row number turns accent. | Table + row number view | Smooth while scrolling | ☑ c9f823e, 👁 pending |
| R5 | **One footer in the results card.** Left: the server › database picker (colour dot, chevron, search field in the picker) and the pane switcher. Right: rows loaded of total (`RowProgress.materialized` of `totalReported`), the selection summary, the duration and the status. Remove the window-wide status bar. The editor card shows a slim footer (picker + status) while there are no results. | `QueryPanelStatusBar`, `BottomPanelStatusBar` | Only one footer on screen; the picker is clearly clickable 👁 | ☑ c8f4808, 👁 pending |
| R6 | Feed extra result sets through the main grid and retire `AdditionalResultSetTableView`. | Results section | All result sets look and behave the same | ☑ e4efb70 |

### Notes from building it (Phase 5)

- **Cells (R1):** `ResultCellPresentation` holds the rules; only the display changes, copy and export read raw values. The "Monospaced cells" setting reaches the grid through `QueryResultsTableView.monospacedCells` and is part of the palette signature, so toggling it refreshes the cells.
- **Header (R2):** `ResultTableHeaderCell` draws the name, the type line and the SF chevron itself; `ResultTableHeaderView` tracks hover and turns a click on the arrow into `Coordinator.cycleSort` (ascending, descending, none). The header is `ResultsGridMetrics.headerHeight` (36) tall.
- **Selection and hover (R3, R4):** rows stroke an open outline so ranges have no seams; the anchor cell gets a ring when the range has more than one cell. Hover uses the tree's hover fill; selected and hovered row numbers turn accent through `ResultTableContainerView.setAccentRows`.
- **Footer (R5):** "12K of 1.2M" while streaming, and a selection summary (`GridSelectionSummary`, capped at 50,000 cells). There was no window-wide status bar left to remove.
- **Extra result sets (R6):** `QueryEditorState.additionalResultState(at:)` and `AdditionalResultSetGrid`; each set sorts on its own.

## Phase 6 · Toolbar and search

Rules: `05-components` › Toolbar, Search.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| K1 | **Run:** accent glass (`glassProminent`), red with a timer while running. A chevron menu offers Run statement at cursor, Run selection, Explain and Explain analyze. | Add a "Query" menu (Run ⌘↩, Cancel ⌘.). | `ToolbarRunButton`, commands | ⌘. cancels; every mode works 👁 | ☑ built, 👁 pending. Cancel is ⌥⌘. (owner, 2026-09-29); ⌘. stays EchoSense |
| K2 | **Grouping by task:** [Project] [Recents · Connections · Quick Connect] … [Run] [Format · Validate · Help · Plan] [MSSQL toggles] [Refresh · Bell · Inspector]. Tab-specific tools go in one contextual capsule next to Run that melts in and out per tab. Remove the per-item `.sharedBackgroundVisibility(.hidden)` + `.glassEffect`. | `WorkspaceToolbarItems` | Groups match; no toolbar jumping when switching tabs 👁 | ☑ built, 👁 pending. The bell joins with N3 |
| K3 | **Shortcut fixes:** Find off ⇧⌘F, Validate off ⇧⌘V. EchoSense stays on ⌘. (owner, 2026-09-29) and can be rebound. | Commands, settings | No conflicts | ☑ built |
| K4 | **Minimised toolbar search** with results in a glass card, and a **⌘K palette** (objects, tabs, actions, history, snippets, and "Switch database" for the current server, round 9 DB3) built on `SearchSidebarViewModel`. | New `CommandPalette` | Both open and find a table across servers | ☑ built, 👁 pending |
| K5 | Delete the dead `Toolbar/Breadcrumbs/*` and `Toolbar/Popovers/*`. | Toolbar | Builds | ☑ built |

### Notes from building it (Phase 6)

- **Query menu** (`EchoApp+QueryMenu.swift`) owns every query shortcut; the toolbar buttons bind none. Run ⌘↩ (the selection, or the whole script), Run Statement at Cursor ⇧⌘↩, Explain ⌥⌘E, Explain Analyze ⌥⇧⌘E, Cancel Query ⌥⌘., Show EchoSense Suggestions ⌘., Format Query ⇧⌘F, Validate Query ⇧⌘B (⇧⌘V is Paste and Match Style; ⇧⌘B is Analyze in Xcode). Find in Sidebar is ⌥⌘F. Every item's shortcut can be rebound in Settings › Keyboard Shortcuts, which now lists them all. Esc also shows EchoSense, through NSTextView's `complete(_:)`.
- **Run modes** (`QueryRunMode`, `WorkspaceTab+RunModes.swift`) are shared by the toolbar chevron and the menu. Statement at cursor (`SQLStatementAtCaret`) ends a statement at `;`, a blank line or a `GO` line, never inside quotes, `[…]`, `$tag$` bodies or comments. Explain is the estimated plan; Explain Analyze runs the query through `getActualExecutionPlan` and shows its rows and the plan.
- **Run** (`QueryRunToolbarControl`) is a `glassProminent` button, accent when idle and red with the elapsed time while running, beside a chevron in the same capsule.
- **Search and ⌘K** (`Features/CommandPalette`): one `CommandPaletteModel` each for the palette and the toolbar search, filled when they open by `CommandPaletteSources`: actions (run modes, Switch Database to …, New Query in …, Connect to …), open tabs, query history (clipboard entries from the editor, 50 newest), snippets for the active dialect, and objects from the global search engine as it finds them. `CommandPaletteMatcher` ranks prefix > word start > substring > letters in order; six rows per section; with nothing typed, only actions and tabs show. The palette is a centred glass card (`CommandPaletteCard`, 560pt, arrows, Return, Esc, click outside); the toolbar search is `.searchable(placement: .toolbar)` with the same rows in a glass card below it (Return performs the top row). macOS has no `.minimize` search behaviour, so the field collapses to a magnifier only when the toolbar runs out of room. View › Command Palette is ⌘K. Opening a result goes through `SearchResultOpener` (moved out of the old sidebar). Database switching is one method now, `EnvironmentState.switchDatabase(_:for:)`, used by the footer chip, the tab strip and the palette.
- **Groups** (`WorkspaceToolbarItems`, `WorkspaceToolbarContext`): [Sidebar] [Project] [Recents · Quick Connect] … [tab tools] [Run ⌄] [Format · Validate · Help · Plan] [SQLCMD · Statistics] [Refresh · Inspector], each a system glass capsule separated by fixed spacers and hidden with `ToolbarContent.hidden(_:)` when the tab has no use for it. The toolbar content reads only the active tab's kind and database type. No item draws its own glass any more except the sidebar button.

## Phase 7 · Notifications and floating cards

Rules: `03-materials`, `05-components` › Notifications, Floating cards.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| N1 | **Floating card primitive:** in-window glass card, no arrow, grows out of its anchor (shared glass container), closes on outside click or Esc, with the floating-surface tokens. | `Shared/DesignSystem/Components/FloatingCard.swift` | Used by N3, the connect picker and the database picker | ☑ built, 👁 pending. Used by the history card and the toolbar search; the database picker is a system popover by decision, and the connect picker is the rail's + menu |
| N2 | **Toasts:** up to three stack and melt; pause on hover; expand into a card with actions; "×N" for repeats; errors stay until dismissed; positioned from the chrome, not a magic number; VoiceOver announcement. | `StatusToastPresenter`, `StatusToastView` | Matches the lab 👁 | ☑ built, 👁 pending |
| N3 | **History under a toolbar bell** with an unread badge: grouped by server, filters, kept across launches, every event recorded even when its toast is muted, items link to their tab or server. Remove the inspector notification tab. | `NotificationEngine`, new `NotificationHistoryCard` | Badge clears on open; history survives relaunch | ☑ built, 👁 pending |
| N4 | **Query errors** in the results card (message, line, "Show in editor", Messages one click away), a toast when the failing tab isn't in front, and a record in history. | Results section, engine | Error in a background tab raises a toast | ☑ built, 👁 pending |
| N5 | Unify the remaining popovers on N1 or on the shared tokens. Autocomplete keeps its system popover. | Various | One width scale, one padding, one row style | ☑ built. Every remaining popover points at its control, so they keep the arrow and use the shared padding and width scale |

### Notes from building it (Phase 7)

- **Floating card (N1):** `FloatingCard` (glass, floating-surface padding and corners, small/medium/large widths) and `.floatingCard(isPresented:alignment:)`, which lays a clear layer behind it so a click outside closes it, and Esc closes it too. System popovers that stay use `.floatingSurfaceContent(_:)` for the same padding and widths.
- **Toasts (N2):** `StatusToastPresenter` keeps up to three, newest on top; a repeat counts up ("×3") and moves to the top; errors stay until dismissed; the hovered toast doesn't time out. `StatusToastStack` draws them in one `GlassEffectContainer` so they melt, expands the hovered one to the medium width with the full message and Open Tab / Show Server, Show All and ×, and posts a VoiceOver announcement. It sits in the content's top-trailing corner, one gutter inside the safe area, so no toolbar height is hard-coded.
- **History (N3):** `NotificationEngine` records every event in `NotificationHistory` (newest first, 500 kept, saved to `notification-history.json` in Application Support) before checking whether its toast is muted. Each record keeps its server, connection and tab (`NotificationContext`, from the active server and tab unless the caller says). The bell sits in [Refresh · Bell · Inspector] with an unread badge; its card has All, Errors, Connection, Queries and Jobs filters, groups by server, and a row links back through `EnvironmentState.reveal(_:)`. Opening it marks everything read. `post` can be called from any isolation; delivery hops to the main actor. The linked-server and server-trigger results that called the toast presenter directly now go through the engine.
- **Query errors (N4):** a failure shows in the Results pane (`QueryFailureView`): the message, "Query Failed on Line N" when the error names a line (`QueryErrorLocation`: SQL Server "Line 3", Postgres "LINE 3:", MySQL "at line 3"), Show in Editor (puts the caret on that line through `QueryEditorState.editorLineRequest`) and Show Messages. It no longer jumps to Messages on its own. Every failure is recorded under the new `queryFailed` category; the toast appears only when the failing tab isn't in front.

## Phase 8 · Tab overview

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| O1 | Toolbar button and trackpad pinch to open. | Toolbar, container | Both open it | ☑ built, 👁 pending |
| O2 | Slim header; stable server order (active server first); grouped by the active database; live running timer and stop; implement or remove "Move to". | `TabOverview/*` | 👁 | ☑ built, 👁 pending. "Move to" became Switch Database on the tab's own server; a tab can't change server |
| O3 | Zoom: the active tab shrinks into its card, and picking a card zooms back in. | Container | 👁 | ☑ built, 👁 pending. A scale-and-fade approximation, not a matched zoom into the card |

### Notes from building it (Phase 8)

- **Opening (O1):** `TabOverviewToolbarButton` leads the [Overview · Refresh · Bell · Inspector] capsule (the rule's toolbar groups didn't place it; log if it should move). A trackpad pinch in (below 0.8) opens the overview and a pinch out (above 1.25) closes it (`WorkspaceTabContainerView+OverviewPinch`). ⇧⌘O is unchanged.
- **Look (O2):** the gradient hero and the capsule controls are gone; `TabOverviewHeader` is one line: "Open Tabs", "12 tabs · 2 running", Collapse All, Expand All. Servers are ordered active first, then by name. Tabs group by `activeDatabaseName`, falling back to the connection's database. A running query tab shows its live time and a red stop button instead of its status badge. The unimplemented "Move to" is now Switch Database, through `EnvironmentState.switchDatabase(_:for:)`.
- **Motion (O3):** the tab scales down and fades as the overview scales in, on the house spring; picking a card reverses it. A true zoom into the card's frame would need the card's position from inside the scroll view; left for the owner to judge.

## Phase 9 · Inspector

Rules: `05-components` › Inspector. Round 10 chose IN1: the inspector becomes a column of cards on the canvas, mirroring the tree, instead of the native inspector column. Notifications leave it first (N-tasks).

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| I1 | **Canvas column.** Replace `.inspector(isPresented:)` with a trailing column in `WorkspaceShell`: same gutter as the tree, its own resize edge (the tree's handle mirrored), and the tree's show/hide motion. ⌥⌘I and the toolbar button keep working. | `WorkspaceShell`, `WorkspaceView` | No native inspector chrome left; width is kept 👁 | ☑ built, 👁 pending |
| I2 | **Section cards.** One card component for every section: a header (icon, title, actions) and rows with the label left and a selectable value right; long values wrap; one 12pt padding. Port object details, foreign-key records (nested related records as their own cards), cell value, JSON, job history and SQL help onto it. | `InfoSidebar/*` → new `InspectorCard` | Every content kind renders on cards 👁 | ☑ built, 👁 pending |
| I3 | **Width.** JSON widens the column with one smooth spring instead of `InspectorSplitViewConfigurator`'s stepped calls, and returns to the chosen width after. | Shell | No visible stepping | ☑ built, 👁 pending |
| I4 | **Row detail.** Selecting a result row shows all its columns as a card. | Inspector + grid selection | Selecting a row fills it | ☑ built, 👁 pending. Fills from the selected cell's row |
| I5 | Remove the notifications tab and `InspectorTabSelector` once N-tasks move history to the bell; delete the native inspector plumbing. | `InfoSidebar/*`, `WorkspaceView` | Nothing links to them | ☑ built |

### Notes from building it (Phase 9)

- **Column (I1):** `WorkspaceInspectorColumn` sits after the cards in `WorkspaceShell`: the gutter before it is its resize edge (`WorkspaceColumnResizeHandle`, shared with the tree and mirrored), its width is `@AppStorage("workspace.inspectorWidth")` (260–640, default 300, double-click resets), and hiding slides it out past the trailing edge as it fades, like the tree. `.inspector(isPresented:)`, `InspectorSplitViewConfigurator`, `WorkspaceLayoutMetrics` and `NavigationStore.inspectorWidth` are gone. ⌥⌘I and the toolbar button still toggle `showInfoSidebar`. The Job Queue window and the login editor keep their own system inspectors.
- **Cards (I2):** `InspectorCard` (header with icon, title, subtitle and actions; 12pt padding; a workspace card) and `InspectorCardRow` (label left, selectable value right, wrapping; NULL italic and faint; copy in the context menu). Object details and foreign-key records are a card each, with related records as their own cards after them; job history, SQL help, cell values and JSON are cards too. Cards stack one gutter apart; with nothing selected a "No Selection" card shows. The uppercase-label boxed rows, the disclosure groups and the doubled 18pt padding are gone.
- **Width (I3):** JSON widens the column to at least 520pt with one house spring and returns to the chosen width after; the chosen width isn't changed by it.
- **Row detail (I4):** the grid's cell inspection now carries the whole row (`CellValueInspectorContent.rowFields`), so the inspector shows the cell's card and a "Row N" card with every column, with Copy Row.
- **Clean-up (I5):** the notifications tab and `InspectorTabSelector` went with N3; the native inspector plumbing went with I1.

## Phase 11 · Editor type and gutter

Rules: `05-components` › Editor card. Decided on the design board (2026-09-30).

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| E5 | **Fonts.** Bundle JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Monaspace (Neon, Argon, Xenon, Radon, Krypton) and Commit Mono (all OFL, licences in `Resources/Fonts/Licenses`). Remove the other eleven; a saved font that no longer exists falls back to the default. | `Resources/Fonts`, `MonospacedFontPicker`, `SQLEditorTheme` | Every font renders in the editor and the picker; old settings decode | ☐ |
| E6 | **Size and spacing.** Default 13pt; line spacing is a setting (default 1.55). | `GlobalSettings`, `SQLEditorTheme`, `SQLTextView`, Preferences › Editor | Changing either updates open editors | ☐ |
| E7 | **Gutter styles:** Subtle, Tinted column (GT1: full height, cut by the card's corners, hairline edge) and Tinted lane (GT2: inset, rounded, no edge). Existing "tinted" settings become Tinted column. | `LineNumberRulerView`, `EditorGutterStyle` | All three look right in light and dark 👁 | ☐ |
| E8 | **Numbers stop at the last line** (GL1), while the tinted gutter runs the card's full height. | `LineNumberRulerView` | Short scripts show no extra numbers | ☐ |

## Phase 12 · EchoSense popup

Rules: `05-components` › EchoSense. Ranking and the 78 scenarios in `AUTOCOMPLETE_SPEC.md` do not change.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| P1 | **Rows (ES1):** kind badge, name in the editor font with the typed letters in bold accent (ESR1, ESR2), the alias or table for columns and always for same-named ones (ESR3), the type on the right. | `AutoCompletionListView` | Matches Round 14 · EchoSense 👁 | ☐ |
| P2 | **Details footer (ES4):** replaces the side panel and its 1 s delay (ESR6): full name, type, source and detail, key hints; an inset rounded panel, concentric with the popup. | `AutoCompletionDetailView` → footer | No timer; footer follows the selection | ☐ |
| P3 | **Tint, then solid (ESR4):** tinted while typing, solid once the selection moves with ↑/↓. | Controller + list | Typing resets to tint | ☐ |
| P4 | **Material and corners (ESR5):** card fill, card edge, floating shadow; the corner follows Card Corners, capped at 14pt; rows use it minus the padding. | List view | No hard-coded white | ☐ |
| P5 | **Ghost text (ES3)** as a setting, off by default: the top match inline in grey, Tab accepts. | Controller, EchoSense settings | Setting toggles it | ☐ |

## Phase 13 · Connections

Rules: `05-components` › Connections.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| C1 | **Short sheet (CN2)** for Quick Connect and New Connection: engine, server and port on one line, database, sign in, Keychain; Security and timeouts in one disclosure with a summary (CR7); name, folder and colour only while "Save to Connections" is on (CR5). Quick Connect saves its password in the Keychain too. | `ConnectionEditor/*` | Quick Connect needs only server and sign-in | ☐ |
| C2 | **Rules:** the default button is never silently disabled; missing fields show inline messages and take focus (CR1); the port placeholder follows the engine (CR2); pasting a URL or connection string fills the form (CR3); the test result sits by the buttons (CR4). | Same | Each rule works | ☐ |
| C3 | **Edit inside Manage Connections (CN5):** the detail pane is the editable form; + adds a new connection with the same form; Save and Revert; unsaved changes are marked. | `ManageConnections/*` | Editing never opens a sheet | ☐ |

## Phase 14 · Tab bar, one line

Rules: `05-components` › Tabs. Replaces the glass capsule with two-line tabs (rounds 11–12).

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| B6 | **Round 9's strip as the only style:** the grey plate and white active tab, one line, the kind's icon (a spinner while running), the database in the tooltip. The bar returns to the Classic height. Remove the glass capsule and the Tab Bar setting. | `QueryTabStrip`, `QueryTabButton*`, `TabStripGlassTabs`, Appearance settings | One line everywhere 👁 | ☐ |
| B7 | **Tool pages unfold in the tab (ST2):** a tool with pages (Activity Monitor first) shows them as small chips inside its active tab; the other tabs make room with the house spring. The tool's own segmented control goes. | Strip + tool tabs | Matches Round 14 · tab bar and pages 👁 | ☐ |

## Phase 15 · Tool tabs

Rules: `05-components` › Tool tabs.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| TL1 | **Tool header (TT2):** one component with the tool's icon, title, server and freshness, and its actions on the right. | New `ToolTabHeader` | Used by every tool tab | ☐ |
| TL2 | **Panes become cards (TT1):** every pane of a tool tab is its own card on the canvas, a gutter apart. Agent Jobs first (Jobs, Details, History), then the rest. | Tool tab views | No unframed panes left 👁 | ☐ |
| TL3 | **Dashboard tiles (TT3)** for monitoring tools: Activity Monitor's figures as cards with sparklines. | `ActivityMonitor/*` | 👁 | ☐ |

## Phase 16 · Section dock

Rules: `05-components` › Explorer tree.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| D1 | **Dock (TC1):** each server card gets an icon row (Databases, Security, Agent, Management, More) under its name; the tree shows one section at a time; the row stays pinned with only a soft blur; each section keeps its scroll position and open folders. The server's section is remembered per connection. | Blueprints, outline view, row headers | Matches Round 14 · section dock 👁 | ☐ |
| D2 | **Duotone icons (IC2)** as the default, mono line (IC1) as the setting. | `SidebarRow`, `ExplorerIconRole` | Both modes in light and dark 👁 | ☐ |

## Phase 17 · Editor ideas

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| Q1 | **Statement focus (QE1):** a faint band on the statement at the caret and a Run arrow in the gutter that runs it. | `SQLTextView`, gutter | Runs only that statement | ☐ |
| Q2 | **Results inline (QE2):** rows and time (or the error) at the end of the statement after a run, fading when it is edited. | Editor | 👁 | ☐ |
| Q3 | **Errors on the line (QE3):** short red text at the end of the line beside the dot. | Validation overlays | 👁 | ☐ |
| Q4 | **Room to breathe (QE4):** wider gutter padding and a rounded current-line band inside the card. | Editor | 👁 | ☐ |
| Q5 | **Outline edge (QE5)** as a setting: statement ticks, errors and the visible area on the right edge. | Editor | Toggles in Settings | ☐ |
| Q6 | **Helpful empty tab (QE6):** recent tables and snippets as faint starting points that vanish on typing. | Editor | 👁 | ☐ |

## Phase 10 · Finish

| ID | Task | Done when | Status |
|---|---|---|---|
| X1 | Accessibility pass: Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver on the rail, tabs and grid. | 👁 | ☐ |
| X2 | Dark mode (graphite) pass across every screen. | 👁 | ☐ |
| X3 | Walk through every rule in `01`–`06` against the app; fix or log exceptions. | Rules checklist all ticked | ☐ |

---

## Still open

Every design question is decided. Only implementation details remain *Leaning*: the floating-card sizes in `06-tokens.md` and the tree resize handle. Settle them while building, and log any change. New questions go through `process.md`.

## Handover notes

- Keep frequently changing state out of `ObjectBrowserSidebarView`'s body; read it in small child views instead.
- The Design Lab playgrounds are the visual reference for every 👁 task; build to match them.
- Four pre-existing unit test failures on `dev` are unrelated; don't chase them in this work.
- The owner builds and checks on their Mac. Say what couldn't be verified.
