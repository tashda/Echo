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
| T1 | **Tree on the canvas:** no background of its own, 12pt indent, server header flush left. | `SidebarRow`, row view | Matches the lab 👁 | ☐ |
| T2 | **Sticky server header with breadcrumb.** The bold 13pt header pins at the top over a soft fade (no band) and shows "› database" for the database you're in. Either `floatsGroupRows` with group rows, or an overlay driven by the existing top-visible tracking. Replaces `ExplorerPinnedPathBar`. | Outline view, row view | Pins and updates while scrolling, with no rebuild of the tree on scroll 👁 | ☐ |
| T3 | **Icon modes.** Colourful uses today's colours softened, keyed by an enum rather than title strings. Monochrome has two variants: accent on open folders (default) and pure. | `ExplorerRowModels.swift`, `ColorToken.swift` | All three look right in light and dark 👁 | ☐ |
| T4 | **Loading:** shimmer rows at the child indent, crossfading into the real rows. Replaces "Expand to load objects…". | Snapshot + row view | Shows while loading, and stops with Reduce Motion | ☐ |
| T5 | **Expand motion:** the native slide and fade, with duration from the motion helper. | Outline view | Speed setting changes it | ☐ |
| T6 | Remove the sidebar Search tool page (search moves to the toolbar in Phase 6). | `SidebarMenuView+Content.swift` | Gone; nothing links to it | ☐ |

## Phase 3 · Tabs

Rules: `05-components` › Tabs. Safari is the reference.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| B1 | **Strip on the canvas** above the cards; keep the grey plate and white active tab, using the tokens from F3. | `WorkspaceTabContainerView`, TabStrip | Sits on the canvas with the gutter 👁 | ☐ |
| B2 | **Running tab:** a spinner at the leading edge and the timer in place of the subtitle. | `QueryTabButton` | Shows while running and clears when done | ☐ |
| B3 | **Overflow:** a minimum width, then inactive tabs collapse to their icon while the active tab keeps its title. | `QueryTabStrip` | 20+ tabs stay usable | ☐ |
| B4 | **New tab grows out of +** (+ and the plate share a glass container). Switching tabs stays instant. | Strip | 👁 | ☐ |
| B5 | Make tabs real buttons (accessibility, focus). Fix the O(n²) separator pass and read the hairline width from `displayScale`. | Strip | VoiceOver reads the tabs | ☐ |

## Phase 4 · Editor and results cards

Rules: `05-components` › Editor card, Results card.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| E1 | **Two cards** (12pt corners, floating shadow) with the gutter between them. One split kept alive; the results card collapses instead of the view tree switching, so the editor keeps its scroll position, undo and focus. | `QueryEditorContainer`, `NativeSplitView` | Toggling results doesn't reset the editor | ☐ |
| E2 | **Results card rises** after the first run while the editor card shrinks (house spring). | Same | Matches the lab 👁 | ☐ |
| E3 | **Resize** by dragging the canvas gap between the cards, with a grab capsule on hover. **Double-click the gap to maximise the results** (the editor becomes a one-line card), and double-click again to restore. Add a menu item and shortcut. | Same | Drag and maximise work; the ratio is saved | ☐ |
| E4 | **Gutter:** subtle or tinted (setting), current-line emphasis, red validation markers, one number per logical line, width that grows with digit count, theme colours. | `LineNumberRulerView`, `SQLTextView` | 10 000-line script numbered correctly 👁 | ☐ |

## Phase 5 · Results grid

Rules: `05-components` › Results card.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| R1 | **Cells:** numbers and dates right-aligned with tabular digits, booleans as ✓/✗, monospaced setting. NULL stays italic text. | `ResultTableDataCellView`, bridge | Matches the lab 👁 | ☐ |
| R2 | **Header:** name + type line; a sort arrow on hover that sorts; clicking elsewhere selects the column. SF chevrons replace the Touch Bar images. | `ResultTableHeaderCell/View` | Matches the lab 👁 | ☐ |
| R3 | **Selection:** one outline per range, a ring on the active cell, row numbers in accent. | `ResultTableRowView`, `ResultTableView` | No seams in multi-row selections | ☐ |
| R4 | **Row hover:** a faint rounded tint, and the row number turns accent. | Table + row number view | Smooth while scrolling | ☐ |
| R5 | **One footer in the results card.** Left: the server › database picker (colour dot, chevron, search field in the picker) and the pane switcher. Right: rows loaded of total (`RowProgress.materialized` of `totalReported`), the selection summary, the duration and the status. Remove the window-wide status bar. The editor card shows a slim footer (picker + status) while there are no results. | `QueryPanelStatusBar`, `BottomPanelStatusBar` | Only one footer on screen; the picker is clearly clickable 👁 | ☐ |
| R6 | Feed extra result sets through the main grid and retire `AdditionalResultSetTableView`. | Results section | All result sets look and behave the same | ☐ |

## Phase 6 · Toolbar and search

Rules: `05-components` › Toolbar, Search.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| K1 | **Run:** accent glass (`glassProminent`), red with a timer while running. A chevron menu offers Run statement at cursor, Run selection, Explain and Explain analyze. Add a "Query" menu (Run ⌘↩, Cancel ⌘.). | `ToolbarRunButton`, commands | ⌘. cancels; every mode works 👁 | ☐ |
| K2 | **Grouping by task:** [Project] [Recents · Connections · Quick Connect] … [Run] [Format · Validate · Help · Plan] [MSSQL toggles] [Refresh · Bell · Inspector]. Tab-specific tools go in one contextual capsule next to Run that melts in and out per tab. Remove the per-item `.sharedBackgroundVisibility(.hidden)` + `.glassEffect`. | `WorkspaceToolbarItems` | Groups match; no toolbar jumping when switching tabs 👁 | ☐ |
| K3 | **Shortcut fixes:** Find off ⇧⌘F, Validate off ⇧⌘V; EchoSense off ⌘. | Commands, settings | No conflicts | ☐ |
| K4 | **Minimised toolbar search** with results in a glass card, and a **⌘K palette** (objects, tabs, actions, history, snippets) built on `SearchSidebarViewModel`. | New `CommandPalette` | Both open and find a table across servers | ☐ |
| K5 | Delete the dead `Toolbar/Breadcrumbs/*` and `Toolbar/Popovers/*`. | Toolbar | Builds | ☐ |

## Phase 7 · Notifications and floating cards

Rules: `03-materials`, `05-components` › Notifications, Floating cards.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| N1 | **Floating card primitive:** in-window glass card, no arrow, grows out of its anchor (shared glass container), closes on outside click or Esc, with the floating-surface tokens. | `Shared/DesignSystem/Components/FloatingCard.swift` | Used by N3, the connect picker and the database picker | ☐ |
| N2 | **Toasts:** up to three stack and melt; pause on hover; expand into a card with actions; "×N" for repeats; errors stay until dismissed; positioned from the chrome, not a magic number; VoiceOver announcement. | `StatusToastPresenter`, `StatusToastView` | Matches the lab 👁 | ☐ |
| N3 | **History under a toolbar bell** with an unread badge: grouped by server, filters, kept across launches, every event recorded even when its toast is muted, items link to their tab or server. Remove the inspector notification tab. | `NotificationEngine`, new `NotificationHistoryCard` | Badge clears on open; history survives relaunch | ☐ |
| N4 | **Query errors** in the results card (message, line, "Show in editor", Messages one click away), a toast when the failing tab isn't in front, and a record in history. | Results section, engine | Error in a background tab raises a toast | ☐ |
| N5 | Unify the remaining popovers on N1 or on the shared tokens. Autocomplete keeps its system popover. | Various | One width scale, one padding, one row style | ☐ |

## Phase 8 · Tab overview

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| O1 | Toolbar button and trackpad pinch to open. | Toolbar, container | Both open it | ☐ |
| O2 | Slim header; stable server order (active server first); grouped by the active database; live running timer and stop; implement or remove "Move to". | `TabOverview/*` | 👁 | ☐ |
| O3 | Zoom: the active tab shrinks into its card, and picking a card zooms back in. | Container | 👁 | ☐ |

## Phase 9 · Inspector

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| I1 | One section style and a single 12pt padding across all panels (as in `LabInspector.swift`). | `InfoSidebar/*` | 👁 | ☐ |
| I2 | Row-detail mode: every column of the selected result row. | Inspector + grid selection | Selecting a row fills it | ☐ |
| I3 | One smooth width change instead of `InspectorSplitViewConfigurator`'s stepped calls; keep the chosen tab. | `WorkspaceView+SplitView.swift` | No visible stepping | ☐ |

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
