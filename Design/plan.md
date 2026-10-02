# Build plan: canvas and cards

The plan for building the decided design into Echo. Work top to bottom; each phase leaves the app working. Before a task, read the rules it names; after it, update its status here.

**Status:** ☐ not started · ◐ in progress · ☑ done (add the commit) · ⏸ blocked (say on what)
**Owner check:** tasks marked 👁 need the owner to look at them on a Mac before they count as done.

Branch: `claude/ecstatic-fermi-u1jxr6`, based on `dev`. See `current-state.md` for where things live today.

---

## Round 53 · The title banner header

| # | Task | Files | Check | Status |
|---|---|---|---|---|
| H1 | The title banner (F5): eyebrow over a 22pt name, hairline edge, banner dock with no capsule, header slot grown to fit, the default Server Header style. | `ServerHeaderPaint`, `ServerHeaderTokens`, `ServerHeaderTitle`, `ServerTitleBannerFill`, `ExplorerBannerDockRow`, `ObjectBrowserRowView+ServerHeader`, `ExplorerTreeLayout` | Open and close a card; switch sections; eyebrow says the engine when closed | ☑ built, 👁 pending |
| H2 | Customization at LV2 in Settings › Appearance (typeface, size, line above, edge, automatic text colour). | `ServerHeaderLook`, `ServerHeaderLookRows`, `GlobalSettings+ServerHeader` | Old settings decode; a saved Wash moves once; `ServerHeaderSettingsTests` | ☑ built, 👁 pending |
| H3 | The collapse chevron turns a quarter on `motion.standard` (CH1, CV0, MO0). | `ObjectBrowserRowView+Headers` | Hover an open card, close it | ☑ built, 👁 pending |
| H4 | Thirty server colours with dark variants plus a colour well (PC3); saved as the light hex. | `ServerColorPalette`, `ServerColorSwatches`, `SavedConnection.color` | Pick a colour, switch appearance; old colours still draw; `ServerColorPaletteTests` | ☑ built, 👁 pending |

## Round 51 · Telling servers apart in the trail

| # | Task | Files | Check | Status |
|---|---|---|---|---|
| S1 | A server's own symbol or emoji (`railSymbol`, `railEmoji`, backward compatible and synced), shown in the trail, the Manage Connections list and the connection sheet (TI0, CU2, WS0). | `SavedConnection`, `ServerRailGlyph`, `SyncAdapter`, `ServerRailMark`, `ServerRailItem`, `ConnectionsTableView` | Old data decodes as automatic; `ServerRailGlyphTests` | ☑ built, 👁 pending |
| S2 | The glass name bubble at once beside a hovered trail item (NM1). | `ServerRailNameBubble`, `ServerRail+Appearance`, `ServerRailEntry` | Hover a server: bubble, no clicks lost | ☑ built, 👁 pending |
| S3 | Customize Appearance: the item's menu opens a popover; the sheet shows the same controls (WH2). | `ServerAppearanceControls`, `ServerAppearancePopover`, `ConnectionEditorView+Detail` | Pick a symbol and an emoji; both places agree | ☑ built, 👁 pending |
| S4 | Minimised cards as dashed rings in the trail, their card leaving the list (SH5). | | | ⏸ contradicts CC0 (header-only closed card) and one-at-a-time; owner to decide |

## Round 52 · The + button

- 👁 #52: built (PR4, MP2, CT1, OP1, CX1, KB1, SM1): `ServerRail+ConnectTrail`, `ConnectTrail/`, File › Connect To and ⇧⌘K. Compiles; 7 `ConnectTrailListingTests` pass. Owner check pending in Echo (opening and closing motion, Return and Escape).

## Round 39 · Rail tools (Codex)

- 👁 #39.1 / #39.4 / #39.5: built and run; 37 focused tests pass. Live history recording and opening verified, screenshot captured, no assertion/fatal runtime logs. Owner check pending in Echo Labs.
- 👁 #39.3: owner requested removal, also accepted in #39.1; panel and palette snippets removed. Owner check pending.
- 👁 #39.2 revision 2: BL3 native inline SQL preview (recommended) and BL4 fixed detail pane. Keep the old choices; owner must judge before the bookmark redesign ships.

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
- After the owner's first build (decisions 2026-09-29): the + is back as the last item of the server pill and opens `ConnectionsMenuContent` (the toolbar's Connections button is gone); the selection disc is inset 3pt; the tool pill has the server pill's width; the start page shows the 5 latest connections; the card's content has a zero minimum size so it can't push the window; the rail, tree and tab plate sit one gutter below the toolbar and the plate and + line up with the card's edges; the pinned path blur is tinted to the canvas and fades at every edge. The Echo Labs rail doesn't have the + yet.
- Empty window (decisions 2026-09-29): `WorkspaceTreeAvailability.hasContent` (in `WorkspaceShell.swift`) keeps the tree hidden with no servers and no tool page; the shell, ⌃⌘S and the new toolbar `SidebarToggleToolbarButton` all use it. ⌃⌘S failed before because the system sidebar menu item took it; `ViewMenuCommands` now uses `CommandGroup(replacing: .sidebar)`. The welcome is `WorkspaceWelcomeView` on the canvas (no card); the old `RecentConnectionsPlaceholder` is gone. UI tests that expect `workspace-sidebar` at launch with no servers may now fail, because the tree is hidden from accessibility until a server connects; update them rather than the rule.
- Tree cards and server page (review round 4): `ObjectBrowserTableView` (in `ObjectBrowserOutlineView.swift`) draws one opaque card per server behind the rows in `drawBackground(inClipRect:)`, from `cardRowRanges`, and lifts the card at the top of the view (`liftedCardIndex`, set from the top-visible tracking). Server gap spacers are `treeCardSpacing` and the top spacer is 1pt so the first card lines up with the rail. The pinned path blur is now tinted to the card colour; T2 replaces it. The server page (`ConnectionDashboardView` and its extensions) sits on the canvas like the welcome, with glass tool buttons (menus for per-database tools) and small `DashboardCard`s with `DashboardCardRow`s.
- Tree scrolling (review rounds 5–7): `ObjectBrowserOutlineView` now returns `ObjectBrowserTreeContainerView`, which holds `ObjectBrowserCardLayerView` (draws each server card with the editor card's tokens, cut to the visible area with rounded corners, a shadow outset around the tree) behind the scroll view (layer-masked to the card corner radius). The table itself draws nothing. `ExplorerPinnedPathBar` is now the glass card header. The snapshot puts pending servers last and spaces cards by the gutter setting. The sidebar toolbar button has its own glass. This covers most of T2 (sticky header with breadcrumb); what remains there is the next header pushing the pinned one up.
- **The Explorer tree is SwiftUI now** (round 8; see `swiftui-tree.md`). `ExplorerTreeLayout` flattens the visible rows with a fixed height per row kind and computes card positions, reveal offsets and the top-visible row. `ObjectBrowserOutlineView` is a flat `LazyVStack` in a `ScrollView` clipped to the card radius, with `ExplorerTreeCardsLayer` behind it drawing one `.workspaceCard()` per server, cut to the visible area. Only that layer reads the scroll offset (`ExplorerTreeScrollState`), so scrolling doesn't re-render rows. The AppKit table, container and card layer are gone. The existing glass header overlay (`ExplorerPinnedPathBar`) now blurs real SwiftUI rows. Still to do: the stress fixture of about 25,000 rows, measured with Instruments.
- S5 was built as part of S1 (the tree shrinks toward the rail and fades while the cards grow, one house-spring animation on `isWorkspaceTreeVisible`).

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| S1 | **Workspace shell.** Replace `NavigationSplitView` with rail · tree · content on a grey canvas (translucent as an option), using the gutter setting. Keep `.inspector`, the toolbar and the sidebar shortcut (⌃⌘S). Add a drag handle to resize the tree. | `WorkspaceView.swift`, new `WorkspaceShell` | Window opens with rail, tree and cards; ⌃⌘S hides and shows the tree; the tree resizes; the inspector still works | ☑ 14e2310, 👁 pending |
| S2 | **Rail, two glass pills.** Servers on top (hug, scroll when full), tools at the bottom (Bookmarks, Snippets, History, Clipboard). The pill grows and shrinks with the spring. Monogram in secondary grey; selected monogram bold, in its server colour. Tooltip on hover. The highlight follows the tree's scroll (reuse `ServerRailBridge.topVisibleConnectionID`). | `ObjectBrowser/Views/Components/ServerRail*.swift` | Matches the Echo Labs rail 👁 | ☑ eab78b7, 👁 pending |
| S3 | **Liquid-stretch selection** exactly as in `LabRail.swift`: separate springs for the leading and trailing edges. | Rail | Matches the lab at both speeds 👁 | ☑ eab78b7, 👁 pending |
| S4 | **Rail status.** Connecting servers breathe (strength per `06-tokens`). A lost connection dims the monogram to 40% and its tooltip gives the reason. Running queries show nothing in the rail. | Rail | Pulse stops on connect; a lost server dims; Reduce Motion shows a still, dimmed monogram | ☑ eab78b7, 👁 pending |
| S5 | **Hide tree.** The tree shrinks into the rail and fades while the cards grow, with the house spring. | Shell | Matches the lab 👁 | ☑ 14e2310, 👁 pending |
| S6 | **Peek.** With the tree hidden, a click on a server slides that server's tree out over the cards; a click outside or Esc closes it; ⌘-click or double-click reopens the tree. Behaviour follows the `collapsedServerClick` setting. | Shell + rail | All three setting values work | ☑ dc3524b, 👁 pending |
| S7 | **Remove the old placement.** Delete `FloatingServerRail`, `QueryGlancePanel` and its toggle, the in-sidebar rail layout, and the ⌥⌘G menu item. Keep the reusable logic. | ObjectBrowser components | No dead code left; builds | ☑ eab78b7 |
| S8 | **Round 40, a server click with the tree hidden:** the tree opens, sliding in while it scrolls to the server (RC1, OM0); nothing more on arrival (SM1). The peek (S6), `AppState.peekedServerID`, `ServerRailClick` and the `collapsedServerClick` setting are removed (owner, after the round). | `WorkspaceShell`, `ServerRail`, `GlobalSettings`, `SidebarSettingsView` | A click with the tree hidden opens it on that server 👁 | ☑ 3416c997, 👁 pending |
| S9 | **Round 48, opening and closing the session:** the welcome loses its name and its mark echoes in (WM2) with the buttons and recents rising after it (WR1); connecting makes the pills echo out (LV2), then the server grows into the rail and the tree follows 0.12 s later (CO1), and the server page builds up (AR2); closing the last tab keeps the server active (CW1) and the card lifts off the page underneath (CH1). | `WelcomeMark`, `WelcomeMarkMotion`, `WorkspaceWelcomeView`, `WorkspaceShell+WelcomeDeparture`, `WorkspaceTabContainerView`, `ConnectionDashboardView`, `AppDirector+TabDelegate` | Echo matches round 48's picks 👁 | ☑ built, 👁 pending |

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
| T10 | **Round 30.3, empty folders:** Tables, Views, Functions and Procedures always show (EF1); an empty one is dimmed with no count (EL1) and opens to a grey “No views” row (OE0); Settings › Sidebar › Show empty folders removed (ST1). | `ExplorerBlueprintWalker.objectFolderNodes`, `ObjectBrowserRowView+Components.folderRow`, `GlobalSettings`, `SidebarSettingsView` | A database without views shows Views 👁 | ☑ 5be677fc, 👁 pending |
| T11 | **Round 30.1, the server header's colour:** HD4 wash by default; Plain, Bar, Glass Plate, Banner in Settings › Appearance › Server Header; Server Header Color (server, accent, none); Current Dock Icon; the rail's monogram, a dot on tabs and the footer pill; Color in the header's menu. | `ServerHeaderPaint`, `ServerHeaderBackdrop`, `ObjectBrowserRowView+ServerHeader`, `ServerRail`, `QueryTabButton+Title`, `BottomPanelStatusBar`, `ObjectBrowserSidebarView+ServerColor` | Matches the lab's Proposal 👁 | ☑ 5be677fc, 👁 pending |
| T12 | **Round 38, rows that open a tab:** Security Overview first in every SQL Server Security (server and database); a grey ↗ on every tool row, always. | `ExplorerBlueprint+SQLServer`, `ExplorerNodeKind.securityOverview`, `ObjectBrowserRowView+Components.actionRow`, `ObjectBrowserNode.Row.action` (now with its database) | Security Overview opens the Security tab 👁 | ☑ 9498ca2b, 👁 pending |
| T13 | **Round 46, opening and closing a server card:** the dock grows out of the header without fading (DA2); rows under the section switch's veil (RA1); closing covers, then folds (CL2); a fold keeps the list's animation. | `ObjectBrowserSidebarView+Fold`, `ExplorerTreeFoldTransition.Style.grow`, `ObjectBrowserOutlineView.dockSwitchKey`, `ExplorerTreeCardsLayer` | Matches the lab's Proposal, no hard line under the header 👁 | ☑ 9aaec7e9, 👁 pending |
| T14 | **The tree places its rows (owner's bugs, 2026-10-02):** cards overlapping after a server connected, and the tree vanishing after collapsing the bottom server. Rows on `ExplorerTreeCanvasLayout` at their exact layout places instead of a `LazyVStack`'s estimates; the hold stored; the closing card's header anchored, then the view settles with the fold. | `ExplorerTreeCanvas`, `ObjectBrowserOutlineView+Rows`, `+Fold`, `ExplorerTreeScrollState`, `ExplorerPinnedHeaderWash` | No card or row out of place after connecting, scrolling, switching or folding 👁 | ☑ 38e19682, 👁 pending |
| T9 | **Round 30.2, folding a server card:** chevron centred on the two lines (CP1); the card's edge glides while its rows fade and are cut by it (CM2); a closed card centres its header and chevron (CC0 + note). | `ObjectBrowserSidebarView+Fold`, `ObjectBrowserOutlineView+Fold`, `ExplorerTreeFoldTransition`, `ExplorerTreeCardsLayer`, `ObjectBrowserRowView+Headers` | Matches the lab's Proposal 👁 | ☑ 7503bb42, 👁 pending |

### Notes from building it (Phase 2 and round 9)

- **Blur under the pinned header** (round 9, after "grey" then "solid"): on macOS, SwiftUI materials and in-window `NSVisualEffectView`s over the tree's SwiftUI rows only tint or fade them, and Core Image background filters don't see SwiftUI content at all. `ExplorerTreeEdgeBlur` draws the rows and card fills under the band again, in four copies blurred at radius 1 to 10 (`LayoutTokens.Workspace.pinnedHeaderBlurRadii`), stronger towards the top, with a light card tint. It reads the scroll offset like the cards layer, so the list never re-renders on scroll.
- **Blur over AppKit content** (the results grid, the editor) is `BackdropEdgeBlur`: stacked Core Image Gaussian background filters. A background filter only sees its own superview, so its views go into the same container as the AppKit view, above it. The Echo Labs's footer stage uses it; FB1 would use it in the app.
- **Database switcher** (round 9, DB1, a50abbb): `DatabaseSwitcherCard` grows out of the footer chip with a matched geometry effect. It can't use a `GlassEffectContainer` morph: a text field inside a glass container sent AppKit's key-view walk (the password autofill check) into an endless loop that hung the app.
- **T1 stress fixture:** not built. Real rows need a `ConnectionSession`, which needs a `DatabaseSession`; the app target has no stub for one (the tests' `MockDatabaseSession` lives in EchoTests). The owner's `dkloosql10-d` (about 65 databases) is a real stress case to profile with Instruments' SwiftUI and Hitches templates.
- **T3 gap (closed by BP1):** icon colours now come from each node kind's `ExplorerIconRole`; `ExplorerSidebarPalette` and its title strings are gone. The mode logic is still in one place: `ObjectBrowserRowView.explorerIconColor(_:)`.
- **T4:** a loading row is three shimmer rows high (`LayoutTokens.Shimmer`), and the failed-refresh state is a warning message row instead of a loading row. Loading labels lost their trailing dots and are only read by VoiceOver now.
- **Echo Labs:** the first page, "Round 9 · open questions", holds the footer (FB, FP), tree scroll bar (SB) and tab bar (TB) questions. Older lab questions are retired; their pages stay as a reference.

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

- **Two cards** (`ContentPanelCards`, used by `QueryEditorContainer`): query tabs draw their own editor and results cards (`WorkspaceTab.drawsOwnCards`); every other tab kind still sits on one card, now applied per tab in `WorkspaceTabContainerView.tabContent`. `WorkspaceContentView` draws no fill behind query tabs so the canvas shows in the gap.
- The results card is a SwiftUI split, not `NativeSplitView`: the gap is the handle (`ContentPanelCardGap`, row-resize pointer, grab capsule on hover, double-click to maximise). `BottomPanelState.isResultsMaximized` holds the maximised state; View › Maximize Results is ⌥⇧⌘Y. `splitRatio` (the editor's share) is kept per tab, as before; it isn't remembered across tabs or launches.
- The footer moves between the cards: in the results card when results show, in the editor card otherwise. Where it sits within the card and what's behind it (FP, FB) wait for the Echo Labs.
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
| R7 | **Values in the grid (round 21):** array count and items, JSON summary, binary kind and size, decimal-point alignment, Copy as Shown. | `ResultCellValueForm`, bridge `+ValueForms` | Matches the lab 👁 | ☑ e18f2087, 👁 pending |
| R8 | **PostgreSQL script results (round 21):** statement list at the left (first words, command entries, status), one Messages line per statement, the selected result lights its statement, stop on a failed statement (setting to continue), Run as One Transaction. | `ScriptResultEntry`, `QueryResultsSection+Script`, `PostgresDatabase+Batches`, `+PostgresScript` | Matches the lab 👁 | ☑ 9974342b, 👁 pending |
| R9 | **Cancelling a query (round 21):** footer Cancelling, rows kept and marked partial, Force Stop after 5 s, run note and Messages "Cancelled after …", ROLLBACK note inside a transaction. | `QueryCancelPhase`, `QueryRunNote`, `+Execution` cancel, `QueryResultsSection+Cancel` | Matches the lab 👁 | ☑ 6349d640, 👁 pending |
| R10 | **Transaction state (round 21):** the status pill shows Transaction (orange, time after a minute) or Failed — roll back (red); its menu commits or rolls back; a notification after 15 minutes idle in a transaction; state from the statements. | `QueryTransactionState`, `QueryPanelStatusBar`, `BottomPanelStatusBar` status menu, `EnvironmentState+PostgresTransaction` | Matches the lab 👁 | ☑ 8c7c72b9, 👁 pending |
| R11 | **An open transaction on close (round 21):** alert before closing a tab, switching database, disconnecting and quitting; Commit default; time and statement count; failed offers Roll Back only; quitting lists the tabs (Review, Roll Back All, Cancel). | `EnvironmentState+OpenTransactionGuard`, `TabStore.closeGuard`, `EchoAppDelegate`, `PostgresPinnedSessionStore.openTransactions` | Closing a tab after BEGIN asks 👁 | ☑ 34e8150a, 👁 pending |
| R12 | **Query time limits (round 21):** Settings default + connection override (the old 60 s reset, told once); PostgreSQL statement_timeout per tab session, set only when it changes; footer 0:12 / 0:30; stop explained with Run Without Limit and the setting; server limit named; Waiting for lock with the holder on hover. SQL Server: every run sets `QueryEditorState.timeLimit` for either engine, ready to be its request deadline (TO1). | `EnvironmentState+QueryTimeLimit`, `+TimeLimit`, `QueryTimeLimit`, `PostgresPinnedSessionStore.setStatementTimeout`, `QueryTimeLimitStopView` | Stopping `SELECT pg_sleep(60)` under a 5 s limit 👁 | ☑ 05c3f309, 👁 pending |
| R13 | **Scroll bars over the footer (round 27):** the bar's thumb 9pt above the footer's pills (E), the system's bar shown while scrolling, the vertical bar down to it, ~~soft side edges where more columns wait~~ (removed after round 47); the blur moves into the clip view under the bars. Same placement for the editor, the Messages console and Extended Events data. | `FooterScrollOverlay`, `ScrollSideFades`, `BackdropEdgeBlur`, `footerScrollRoom`, `LayoutTokens.Footer.scrollBarBottom` | Matches the lab 👁 | ☑, 👁 pending |
| R14 | **Round 27 refined, everywhere:** the bar as wide as the footer (L2); the blur rises past it while it shows and settles after, animated on its masks, with finer steps and an S-curve fade (U5); the same blur behind every overlay horizontal bar in Echo. | `ScrollBarBlur`, `ScrollBarBlurHook`, `BackdropEdgeBlur`, `FooterScrollOverlay`, `LayoutTokens.EdgeBlur` | Matches the lab 👁 | ☑, 👁 pending |
| R15 | **Header line (round 41.1):** one hairline at the header's true bottom: the header paints its full height and draws it, over the system's pocket that stops 4pt short; the column dividers stay. | `ResultTableHeaderView` | One line under the header 👁 | ☑, 👁 pending |
| R16 | **Selection pill (round 41.2):** the count, plus the sum and/or average by Settings › Results › Selection summary; a popover with the exact figures, Copy per line and Copy All. | `GridSelectionSummary` (EchoSense `pillText`), `SelectionPillFigures`, `SelectionSummaryPopover`, `QueryResultsSettingsView`, bridge `+SelectionLogic` | Matches the lab 👁 | ☑, 👁 pending |
| R17 | **Error banner (round 41.3):** a banner at the top of the card with chips and Copy Error; Running, No rows, Cancelled the same. | `ResultsStateBanner`, `QueryFailureView`, `QueryResultsSection+Views` | Matches the lab 👁 | ☑, 👁 pending |
| R18 | **Messages (round 41.4):** grouped by statement, quiet errors, counts that filter and a ⋯ menu; no Echo lines or metrics; the symbol of a server message opens what the server returned. | `ExecutionConsoleView` (+Counts, +Messages), `ServerMessagePopover`, `QueryMessageStatement`, `QueryEditorState+Execution` | Matches the lab 👁 | ☑, 👁 pending |
| R19 | **A popover per pill (round 41.5):** selection, rows, time and status each open their own; no Export, Copy All, Messages or Run Again in them (the grid's right-click menu has the export and copy). Server CPU and SPID wait for the drivers. | `BottomPanelStatusBar+Metrics`, `FooterPopovers/`, `QueryRunRecord`, `QueryRunTimeline` | Matches the lab 👁 | ☑, 👁 pending |
| R20 | **Row numbers (round 47):** their own setting, Settings › Results › Row Number Style (default Hairline; the editor's gutter stays Subtle); fit the digits (3 at least); the Hairline's edge below the header; the `#` selects all; selected rows tinted; one header line (the header cell no longer draws the system's). | `ResultTableRowNumberView`, `ResultTableContainerView`, `ResultsGridMetrics`, `ResultTableHeaderCell`, `GlobalSettings.resultsGutterStyle` | Matches the lab 👁 | ☑, 👁 pending |
| R21 | **Sorting and edges (after round 47):** a column sort makes each row's key once and sorts a big result off the main thread; the grid has room after the last column (the soft side edges were then removed). | `ResultRowSorter`, `QueryResultsSection+Logic`, `ScrollSideFades`, `QueryResultsTableBridge+Scrolling` | Sorting 121K rows keeps Echo responsive 👁 | ☑, 👁 pending |

### Notes from building it (Phase 5)

- **Cells (R1):** `ResultCellPresentation` holds the rules; only the display changes, copy and export read raw values. The "Monospaced cells" setting reaches the grid through `QueryResultsTableView.monospacedCells` and is part of the palette signature, so toggling it refreshes the cells.
- **Header (R2):** `ResultTableHeaderCell` draws the name, the type line and the SF chevron itself; `ResultTableHeaderView` tracks hover and turns a click on the arrow into `Coordinator.cycleSort` (ascending, descending, none). The header is `ResultsGridMetrics.headerHeight` (36) tall.
- **Selection and hover (R3, R4):** rows stroke an open outline so ranges have no seams; the anchor cell gets a ring when the range has more than one cell. Hover uses the tree's hover fill; selected and hovered row numbers turn accent through `ResultTableContainerView.setAccentRows`.
- **Footer (R5):** "12K of 1.2M" while streaming, and a selection summary (`GridSelectionSummary`, capped at 50,000 cells). There was no window-wide status bar left to remove.
- **Extra result sets (R6):** `QueryEditorState.additionalResultState(at:)` and `AdditionalResultSetGrid`; each set sorts on its own.
- **Values (R7):** `ResultCellValueForm` holds the rules and is chosen per column (`cachedColumnForms`). It runs only when a visible cell is configured. A decimal with more fraction digits than the column has shown so far widens the column's fraction (capped at 6) and reloads the visible rows once. Array counts are drawn by `ResultTableDataCellView.applyCountEmphasis`. Column auto-width measures the drawn text.

## Phase 6 · Toolbar and search

Rules: `05-components` › Toolbar, Search.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| K1 | **Run:** accent glass (`glassProminent`), red with a timer while running. A chevron menu offers Run statement at cursor, Run selection, Explain and Explain analyze. | Add a "Query" menu (Run ⌘↩, Cancel ⌘.). | `ToolbarRunButton`, commands | ⌘. cancels; every mode works 👁 | ☑ built, 👁 pending. Cancel is ⌥⌘. (owner, 2026-09-29); ⌘. stays EchoSense |
| K2 | **Grouping by task:** [Project] [Recents · Connections · Quick Connect] … [Run] [Format · Validate · Help · Plan] [MSSQL toggles] [Refresh · Bell · Inspector]. Tab-specific tools go in one contextual capsule next to Run that melts in and out per tab. Remove the per-item `.sharedBackgroundVisibility(.hidden)` + `.glassEffect`. | `WorkspaceToolbarItems` | Groups match; no toolbar jumping when switching tabs 👁 | ☑ built, 👁 pending. The bell joins with N3 |
| K3 | **Shortcut fixes:** Find off ⇧⌘F, Validate off ⇧⌘V. EchoSense stays on ⌘. (owner, 2026-09-29) and can be rebound. | Commands, settings | No conflicts | ☑ built |
| K4 | **Minimised toolbar search** with results in a glass card, and a **⌘K palette** (objects, tabs, actions, history, snippets, and "Switch database" for the current server, round 9 DB3) built on `SearchSidebarViewModel`. | New `CommandPalette` | Both open and find a table across servers | ☑ built, 👁 pending |
| K5 | Delete the dead `Toolbar/Breadcrumbs/*` and `Toolbar/Popovers/*`. | Toolbar | Builds | ☑ built |
| K6 | **Refresh and the activity signal (round 34):** Refresh only while the front tab can reload, showing only its own reload (`TabReloader`); ⌘R reloads the front tool tab; the bell spins for long operations; query runs off the bell. | `RefreshToolbarButton/*`, bell, `ActivityEngine`, View menu | Run alone shows ✓ after a query 👁 | ☑ built, 👁 pending |

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
| N2 | **Toasts:** up to three stack and melt; pause on hover; expand into a card with actions; "×N" for repeats; errors stay until dismissed; positioned from the chrome, not a magic number; VoiceOver announcement. | `StatusToastPresenter`, `StatusToastView` | Matches the lab 👁 | ☑ built; round 18 (title and detail, small buttons, swipe to dismiss) built, 👁 pending |
| N3 | **History under a toolbar bell** with an unread badge: grouped by server, filters, kept across launches, every event recorded even when its toast is muted, items link to their tab or server. Remove the inspector notification tab. | `NotificationEngine`, new `NotificationHistoryCard` | Badge clears on open; history survives relaunch | ☑ built; round 17 (compact cards by day, H3 header, A2 buttons) built, 👁 pending |
| N4 | **Query errors** in the results card (message, line, "Show in editor", Messages one click away), a toast when the failing tab isn't in front, and a record in history. | Results section, engine | Error in a background tab raises a toast | ☑ built, 👁 pending |
| N5 | Unify the remaining popovers on N1 or on the shared tokens. Autocomplete keeps its system popover. | Various | One width scale, one padding, one row style | ☑ built. Every remaining popover points at its control, so they keep the arrow and use the shared padding and width scale |
| N6 | **A PostgreSQL connection lost (round 21):** told at once in Messages and a notification with Reconnect; footer Disconnected; runs refused until Reconnect; idle drops quiet. | `PostgresPinnedSessionStore`, `EnvironmentState+PostgresConnectionLoss`, `NotificationAction` | Killing the tab's backend shows it before any run 👁 | ☑ a55e0328, 👁 pending |

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
| O4 | **Round 35.1 (TO6, OR1, OS0):** the overview becomes a scope of the ⌘K palette: a "Tab Overview" row, ⇧⌘O, the toolbar button and a pinch open it on this window's tabs, grouped by server with a live status; ⌫ / ⌘⌫ close, ⌘D duplicates, ⌥⌫ closes the others. The grid (`TabOverview/*`, `TabOverviewStyle`) is removed; O1 to O3 are superseded. | `CommandPalette/*` (`TabOverviewPaletteList`, `+TabOverview`, `TabOverviewEntry`, `TabOverviewStatus`), `AppState.toggleTabOverview` | Tabs and their states show; the keys act on the selected tab 👁 | ☑ built (`TabOverviewPaletteTests`), 👁 pending |
| O5 | **Unsaved query tabs (owner, 2026-10-01):** `QueryEditorState.savedSQL`; the tab store's unsaved guard and several-tabs guard; Save to a bookmark, Save As a .sql file; File › Save ⌘S, Save As ⇧⌘S; quit and project switch ask; ⌘D duplicates (was a stub). | `EnvironmentState+UnsavedChanges`, `WindowAlert`, `TabStore`, `EchoAppDelegate`, `EnvironmentState+ProjectSwitch` | Closing a changed tab asks 👁 | ☑ built (`UnsavedChangesTests`), 👁 pending |

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
| E5 | **Fonts.** Bundle JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Monaspace (Neon, Argon, Xenon, Radon, Krypton) and Commit Mono regular and bold (its italics report another family name), all OFL, licences in `Resources/Fonts/Licenses`. Remove the other eleven; a saved font that no longer exists falls back to the default. | `Resources/Fonts`, `MonospacedFontPicker`, `SQLEditorTheme` | Every font renders in the editor and the picker; old settings decode | ☑ built, 👁 pending |
| E6 | **Size and spacing.** Default 13pt; line spacing is a setting (default 1.55). | `GlobalSettings`, `SQLEditorTheme`, `SQLTextView`, Preferences › Editor | Changing either updates open editors | ☑ built, 👁 pending |
| E7 | **Gutter styles:** Subtle, Tinted column (GT1: full height, cut by the card's corners, hairline edge) and Tinted lane (GT2: inset, rounded, no edge). Existing "tinted" settings become Tinted column. | `LineNumberRulerView`, `EditorGutterStyle` | All three look right in light and dark 👁 | ☑ built, 👁 pending |
| E8 | **Numbers stop at the last line** (GL1), while the tinted gutter runs the card's full height. | `LineNumberRulerView` | Short scripts show no extra numbers | ☑ already true: the ruler numbers only existing lines |

## Phase 12 · EchoSense popup

Rules: `05-components` › EchoSense. Ranking and the 78 scenarios in `AUTOCOMPLETE_SPEC.md` do not change.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| P1 | **Rows (ES1):** kind badge, name in the editor font with the typed letters in bold accent (ESR1, ESR2), the alias or table for columns and always for same-named ones (ESR3), the type on the right. | `AutoCompletionListView` | Matches Round 14 · EchoSense 👁 | ☑ built, 👁 pending |
| P2 | **Details footer (ES4):** replaces the side panel and its 1 s delay (ESR6): full name, type, source, nullability and keys (EchoSense `columnFacts`, e10f0ee), key hints; an inset rounded panel, concentric with the popup. | `AutoCompletionDetailView` → footer | No timer; footer follows the selection | ☑ built, 👁 pending |
| P3 | **Tint, then solid (ESR4):** tinted while typing, solid once the selection moves with ↑/↓. | Controller + list | Typing resets to tint | ☑ built, 👁 pending |
| P4 | **Material and corners (ESR5):** card fill, card edge, floating shadow; the corner follows Card Corners, capped at 14pt; rows use it minus the padding. | List view | No hard-coded white | ☑ built, 👁 pending |
| P5 | **Ghost text (ES3)** as a setting, off by default: the top match inline in grey, Tab accepts. | Controller, EchoSense settings | Setting toggles it | ☑ built, 👁 pending: Settings › EchoSense › Ghost text instead of the list, off by default |

## Phase 13 · Connections

Rules: `05-components` › Connections.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| C1 | **Short sheet (CN2)** for Quick Connect and New Connection: engine, server and port on one line, database, sign in, Keychain; Security and timeouts in one disclosure with a summary (CR7); name, folder and colour only while "Save to Connections" is on (CR5). Quick Connect saves its password in the Keychain too. | `ConnectionEditor/*` | Quick Connect needs only server and sign-in | ☑ built, 👁 pending |
| C2 | **Rules:** the default button is never silently disabled; missing fields show inline messages and take focus (CR1); the port placeholder follows the engine (CR2); pasting a URL or connection string fills the form (CR3); the test result sits by the buttons (CR4). | Same | Each rule works | ☑ built, 👁 pending |
| C3 | **Edit inside Manage Connections (CN5):** the detail pane is the editable form; + adds a new connection with the same form; Save and Revert; unsaved changes are marked. | `ManageConnections/*` | Editing never opens a sheet | ☑ built, 👁 pending |
| C4 | **SQL Server encryption (round 22):** Mandatory default for new connections (ED1); menu and info words that say what is checked (EW1); Trust dims under Strict (ST1); per-connection Allow TLS 1.0 (LT2); Test names the failed certificate check and offers Trust this certificate or Host Name In Certificate (TE1). | `ConnectionEditorView+SecuritySection`, `+Testing`, `ConnectionConfiguration`, `MSSQLNIOFactory` | Matches the lab; a TLS 1.0-only server connects only with the switch 👁 | ☑ 057a797b, 👁 pending |
| C5 | **Kerberos (round 23):** Mechanism Password or Kerberos (KP1, KN1); ticket line with Open Ticket Viewer (KT1); Kerberos Service in the disclosure (KS1); user name from the ticket (KU1); Test fixes Open Ticket Viewer (NT1) and Use Password (KF1); Password keeps the ticket (PK1). | `ConnectionEditorView+Postgres`, `PostgresNIOFactory+SavedConnection`, `PostgresConnectionTest`, `PostgresSignInFiles` | Signs in with a ticket; no ticket offers Ticket Viewer 👁 | ☑ built, 👁 pending |
| C6 | **Client certificates (round 23):** labelled rows (KR1); Key Password only for encrypted keys (KW1), kept in the Keychain (KK1, `ConnectionKeyPasswordStore`); wrong password under the row (KE1); .p12/.pfx for both rows (PF2). | `ConnectionEditorView+Postgres`, `ConnectionKeyPasswordStore`, `IdentityRepository` | An encrypted key and a .p12 sign in 👁 | ☑ built, 👁 pending |
| C7 | **Several servers (round 23):** + Add Server rows (FH1); Connect To under them (FT1, FW1); Test checks each (TS1); pasted multi-server URLs (PU1); footer chip and notification after a failover (FS1); tabs follow Connection lost (FR1). | `ConnectionEditorView+Postgres`, `ConnectionStringParser`, `ConnectionSession+ServerWatch`, `QueryPanelStatusBar` | Stopping the first server moves Echo to the second and says so 👁 | ☑ built, 👁 pending |

## Phase 14 · Tab bar, one line

Rules: `05-components` › Tabs. Replaces the glass capsule with two-line tabs (rounds 11–12).

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| B6 | **Round 9's strip as the only style:** the grey plate and white active tab, one line, the kind's icon (a spinner while running), the database in the tooltip. The bar returns to the Classic height. Remove the glass capsule and the Tab Bar setting. | `QueryTabStrip`, `QueryTabButton*`, `TabStripGlassTabs`, Appearance settings | One line everywhere 👁 | ☑ built, 👁 pending |
| B7 | **Tool pages unfold in the tab (ST2):** a tool with pages (Activity Monitor for SQL Server, Postgres and MySQL) shows them as small chips inside its active tab, scrolling sideways past 62% of the strip; the other tabs make room with the house spring. The tool's own segmented control goes. | Strip + tool tabs | Matches Round 14 · tab bar and pages 👁 | ☑ built, 👁 pending |
| B7b | **Tool pages refined (round 36.1):** title, hairline, pages at 11pt on the tab (no track), the shown one on a soft pill; the tab exactly as wide as that, a lone one at its own width; house spring, pages fading first. | `TabPageChips`, `QueryTabStrip+Unfold`, `QueryTabButton+Title` | Owner checks it in Echo 👁 | ☑ built, 👁 pending |

## Phase 15 · Tool tabs

Rules: `05-components` › Tool tabs.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| TL1 | **Tool header (TT2):** one component with the tool's icon, title, server and freshness, and its actions on the right. | New `ToolTabHeader` | Used by every tool tab | ☑ built, 👁 pending: Activity Monitor draws it itself; every other tool tab gets it from `ToolTabContainer` (icon, title, server · database) |
| TL2 | **Panes become cards (TT1):** every pane of a tool tab is its own card on the canvas, a gutter apart. Agent Jobs first (Jobs, Details, History), then the rest. | Tool tab views | No unframed panes left 👁 | ☑ built, 👁 pending: Agent Jobs, Extended Events, Schema Diff, Query Builder, Resource Governor, Tuning Advisor, MySQL configuration, MySQL and Postgres advanced objects, and the bottom panel of every tool that has one (Maintenance, security, server properties) all use `CardSplitView`; a pane's card turns itself off when the pane holds cards (`adaptiveWorkspaceCard`); the toolbar row moves onto the canvas under the header; the bottom panel uses the query tab's `ContentPanelCards` (grow and fold with the status bar, resize, double-click or ⌥⇧⌘Y to maximise to a one-line content card) |
| TL4 | **Agent Jobs finished (round 33):** one `PaneHeader` per pane; Jobs full height beside Details over History; columns Status, Name, Last Run, Next Run; a running job spins and counts up; New Job and Start/Stop on the header; no stripes. | `JobManagement/*`, `PaneHeader` | Owner checks it in Echo 👁 | ☑ built, 👁 pending |
| TL5 | **New Step and Edit Step (round 33.2):** command at the left in the SQL editor with Parse, settings sidebar with On success / On failure / retries, last run on Edit Step; `SheetLayout` one surface with a prominent default button. | `JobManagement/Sheets/AgentJobStepEditorSheet*`, `SheetLayout`, sqlserver-nio `scripts.parse` | Owner checks it in Echo 👁 | ☑ built, 👁 pending |
| TL3 | **Dashboard tiles (TT3)** for monitoring tools: Activity Monitor's figures as cards with sparklines. | `ActivityMonitor/*` | 👁 | ☑ built, 👁 pending |
| TL6 | **Pages for every tool (round 36.2):** the nine tools whose sections are separate views get pages in the tab instead of their segmented control; More menu for pages that don't fit; reopen on the last page used on that server. | `WorkspaceTab+ToolPages`, `TabPageChips`, the nine tools | Owner checks it in Echo 👁 | ☑ built (bb01362f), 👁 pending |
| TL7 | **Families and one theme (round 37.1):** every tool tab knows its family; one header, pane cards, tables and empty states for all. The header's layout follows round 37.2. | `ToolTabContainer`, tool views | No tool tab drawn its own way 👁 | ☑ built (bb01362f), 👁 pending: the header on one line (37.2) everywhere |
| TL8 | **Controls (round 37.3):** glass capsule main action, one glass capsule of other actions, glass picker pill, Stop with a pulsing dot, glass search capsule, all 28pt. Where the main action lives follows round 45. | `DesignSystem/Components`, tool toolbars | Every tool's row uses them 👁 | ☑ built (bb01362f), 👁 pending; the main action stays in the tab (round 45) |
| TL9 | **A theme per family (round 37.4):** tiles for Monitor, a details card beside the list for Manage, a fix per finding for Health, an Apply bar with the count for Properties, a floating glass bar for Canvas. | Tool views by family | Owner checks it in Echo 👁 | ☑ built (bb01362f, 6e27bab7), 👁 pending: the other Manage tools keep their layouts |
| TL10 | **Tool actions in the tab (round 45):** the window toolbar's tool group removed; each action moved into its tab's header line or Apply bar. | `WorkspaceToolbarItems`, tool views | 👁 | replaced by TL11 (round 37.5) |
| TL11 | **Every tab's own buttons in the toolbar (round 37.5):** the tab's symbol, its special button and one capsule of its buttons before the window's icons, from data each tab sets; query editor's groups in one capsule. | `TabToolbar/*`, `WorkspaceToolbarItems`, every tool view | Owner checks it in Echo 👁 | ☑ built (bb8a6bee), 👁 pending |
| TL12 | **Every page in the tab, calmer switching, new icons, no server dot (round 49):** FP4 page layout (shortened names, icon-only neighbours, a row under the strip when needed), the gliding plate and still icon layer (MO9), one icon per tool, the dots removed, Advanced Objects (PostgreSQL) as four tools. | `Views/Tabs/TabStrip/*`, `WorkspaceTab+KindLabels`, `PostgresAdvancedObjectsViewModel.Group`, `ExplorerBlueprint+PostgreSQL` | Owner checks it in Echo 👁 | ☑ built, 👁 pending |

## Phase 16 · Section dock

Rules: `05-components` › Explorer tree.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| D1 | **Dock (TC1):** each server card gets an icon row (Databases, Security, Agent, Management, More) under its name; the tree shows one section at a time; the row stays pinned with only a soft blur; each section keeps its scroll position and open folders. The server's section is remembered per connection. | Blueprints, outline view, row headers | Matches Round 14 · section dock 👁 | ☑ built, 👁 pending. Pinning uses LazyVStack section headers; the blur is `.ultraThinMaterial` faded out below the dock, shown only while pinned |
| D2 | **Duotone icons (IC2)** as the default, mono line (IC1) as the setting. | `SidebarRow`, `ExplorerIconRole` | Both modes in light and dark 👁 | ☑ built, 👁 pending (the setting reads Duotone / Mono) |
| D3 | **Round 16 · capsule dock (H5):** Xcode's navigator icons across a glass capsule as wide as the card, current icon accent, sized by the sidebar size; dock icon style (mono default) as its own setting; More (») for sections left out. | `ExplorerDockRow`, `ExplorerDock` | Matches the lab's Proposal 👁 | ☑ built, 👁 pending. The dock icon style is also in Settings › Appearance (Section Dock Icons) |
| D4 | **Header:** bold name sized by the sidebar size, product and release under it ("SQL Server 2022"), full build in the tooltip. | `ObjectBrowserRowView+Headers` | 👁 | ☑ built, 👁 pending |
| D5 | **Blur rows:** the pinned header is see-through with a light wash of the card colour; rows under it blur and fade towards the top. The grey material goes. | `ExplorerPinnedHeaderBlur`, outline rows | Matches the lab's Proposal beside System edge 👁 | ☑ built, 👁 pending. `ExplorerPinnedHeaderWash` + `ExplorerRowEdgeBlur` (visualEffect per row); the material is gone |
| D6 | **Switching:** crossfade with the card height settling (`settle`), no rows dropping in from the top. | `ObjectBrowserOutlineView`, `+Dock` | No bounce at the card's bottom 👁 | ☑ built, 👁 pending. Rows fade (no drop from the top); a dock switch animates with `settle`, folders with `expand` |
| D7 | **Initial load, folders first:** while a section's source loads, its folders and tools show with spinners in their count slots; item-only levels show one spinner row. Dock icon still. | `ExplorerBlueprintWalker`, rows | 👁 | ☑ built, 👁 pending. A connecting server shows its sections at once, with "Loading databases" as a spinner row |
| D8 | **Opening a folder:** quiet skeleton after 250ms instead of the shimmer. | Loading rows | Fast servers never flash it 👁 | ☑ built, 👁 pending. `SkeletonPlaceholderRows` replaces the shimmer |
| D9 | **Counts always** in the whole tree; a spinner takes the count's slot while loading (fixes the blinking count). | `SidebarRow` | 👁 | ☑ built, 👁 pending |
| D10 | **Symmetric selection:** remove the 8pt leading pull. | `ObjectBrowserRowView` | Equal insets 👁 | ☑ built, 👁 pending |
| D11 | **Dock menus and customising:** right-click an icon for its section's menu plus Dock; Customize Dock for the type (Settings › Sidebar, synced) or one server (on the connection). | Dock, `GlobalSettings`, `SavedConnection` | Tests for the dock order and overrides | ☑ built, 👁 pending. Per type in `GlobalSettings.sidebarDockSections`, per server in `SavedConnection.explorerDockSections` (synced); tests in `ExplorerDockTests`, `ExplorerDockPersistenceTests` |
| D12 | **PostgreSQL sections:** Activity (Activity Monitor pages), Management (Maintenance, Back Up Server, Back Up Globals, Restore, PSQL Console), Tablespaces. | `ExplorerBlueprint+PostgreSQL`, node kinds, child sources | `ExplorerBlueprintTests` pin the order | ☑ built, 👁 pending. Restore is left out: Echo's restore always targets one database, so it stays on each database's menu. Back Up Server and Back Up Globals get their first entry point |
| D13 | **Round 19 · switching (S3 + jump):** fade the card's rows out, swap with the edge settling, fade in; jump to the section's saved place while faded; no glide. | `ObjectBrowserSidebarView+Dock`, `ObjectBrowserOutlineView` | Nothing slides in 👁 | ☑ built, 👁 pending. Fade out 80ms, swap, fade in 180ms (scaled by speed); the jump is an unanimated reveal to the saved row |
| D14 | **The other cards (N2):** cards animate only on their own change; a hold spacer keeps the view from scrolling back when the list shrinks. | `ExplorerTreeCardsLayer`, outline | The card above never moves 👁 | ☑ built, 👁 pending. `ExplorerTreeHoldSpacer` keeps the bottom where it was; the layer-wide card animation stays, since the clamped scroll was the only thing moving cards you didn't touch |
| D15 | **Capsule C5:** hairline edge and soft shadow on the glass, medium icons, icons grow on hover. | `ExplorerDockRow` | Matches the lab 👁 | ☑ built, 👁 pending |
| D16 | **Section name under the server's name** ("SQL Server 2022 · Security"). | Headers | 👁 | ☑ built, 👁 pending |
| D17 | **SQL Server in five (G1):** Server Objects (Linked Servers, Server Triggers), Database Snapshots at the end of Databases, Integration Services under Management; a test that no blueprint has more than five sections. | Blueprints, walker, node kinds | `ExplorerBlueprintTests` | ☑ built, 👁 pending. `Databases { … }` takes folders after the databases; `serverObjects` node kind |
| D18 | **Five at most, More as a section (M2):** the capsule shows up to five; » is a section listing the rest as folders. | `ExplorerDock`, `ExplorerDockRow` | `ExplorerDockTests` | ☑ built, 👁 pending. `ExplorerDock.capsuleLimit`, `moreItemID` |

## Phase 17 · Editor ideas

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| Q1 | **Statement focus (QE1):** a faint band on the statement at the caret and a Run arrow in the gutter that runs it. | `SQLTextView`, gutter | Runs only that statement | ☑ built, 👁 pending (Settings › Appearance › Editor › Statement Focus, on by default) |
| Q2 | **Results inline (QE2):** rows and time (or the error) at the end of the statement after a run, fading when it is edited. | Editor | 👁 | ☑ built, 👁 pending: after Run, Run Selection or the Run arrow; runs started elsewhere (for example the results pane) show no note |
| Q3 | **Errors on the line (QE3):** short red text at the end of the line beside the dot. | Validation overlays | 👁 | ☑ already built: validation draws a short inline note after each failing line beside the gutter dot |
| Q4 | **Room to breathe (QE4):** wider gutter padding and a rounded current-line band inside the card. | Editor | 👁 | ☑ built, 👁 pending: the current line uses the theme's currentLine colour as a rounded band inset 6pt; numbers sit 12pt from the code |
| Q5 | **Outline edge (QE5)** as a setting: statement ticks, errors and the visible area on the right edge. | Editor | Toggles in Settings | ☑ built, 👁 pending: Settings › Appearance › Editor › Outline Edge, off by default; replaces the scroll bar while on |
| Q6 | **Helpful empty tab (QE6):** recent tables and snippets as faint starting points that vanish on typing. | Editor | 👁 | ☑ built, 👁 pending: Echo now remembers tables opened by Data, Structure, Diagram and search (`RecentTableStore`, per connection and database, 60 kept); the empty tab shows the last four as chips above the snippets, and a chip inserts the table's first-rows query |

## Phase 18 · SQL Server driver integration (round 22)

Rules: `decisions.md` › 2026-09-30 round 22 entries. Needs sqlserver-nio #11 (on `dev`), #12 (cell formatter, exact values) and #13 (TLS failure reasons) on `dev`, then `Package.resolved` updated.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| S1 | **Driver on dev:** update `Package.resolved`; handle the new error cases (`commitOutcomeUnknown`, `tlsFailed`) in `DatabaseError.from(sqlServerError:)`. | `Package.resolved`, `DatabaseError.swift` | Echo builds against sqlserver-nio `dev` | ☑ 156893a1 |
| S2 | **Values (DF1, DO1, MN1, GE1, SS1):** store every MSSQL row as wire bytes with the column's `SQLServerCellType`; decode spooled rows with `SQLServerCellFormatter`; retire `TDSBinaryDecoder` and `canUseRawPath`. | `MSSQLDedicatedQuerySession+Queries`, `SQLServerSessionAdapter+Queries`, `ResultSpoolHandle+Codec`, `ResultSpoolTypes+TDSDecoding` | Rows 1, 200, 201 and 1,000 read the same; Cyrillic varchar after row 200 is right | ☑ ce98d8e4 (`MSSQLResultPipelineTests`), 👁 pending |
| S3 | **Errors (EM1, LL1, AM1, CU1, FE1, ED1):** Messages lists every message with the SSMS header; the line is a link; COMMIT outcome unknown wording; severity ≥ 20 goes to the lost-connection path. **ED1 = the Postgres error-location decision (round 21, accepted):** EM5 squiggle with the message in a bubble on hover, on the reported line (SQL Server gives a line, not a column; when the message names an object, e.g. 207 `Invalid column name 'x'`, the squiggle narrows to that word); EH3 a Fix button when the error names a column (207 → the table's closest column); EC3 clears on edit or the next run, whichever comes first; RN1 run note `! Error`, with a Settings choice for the full message (owner's note); J1 no jump, but clicking the error in Messages goes there, and the error notification gets a **Go to Error** button (owner's note); IF1 an error inside a procedure marks the EXEC line and the bubble names the procedure and its line (`dbo.load_orders, line 12`). The mark itself is shared with the Postgres build; SQL Server supplies line, procedure and message. | MSSQL sessions, `ExecutionConsoleView`, execution error handling, shared error mark | Matches the lab 👁 | ☑ 8e8ea135 (SQL Server data), d6cf8cf3 (Messages with the SSMS header and line links; the shared error mark for both engines: EM5 squiggle and bubble, EH3 Fix, EC3, IF1, RN1 with the Settings choice, J1 with Go to Error; `QueryErrorMarkerTests`), 👁 pending |
| S4 | **Cancel and sessions (TO1, CL1, XA1, BG1):** remove the 45 s task-group timer and reconnect-after-cancel; cancel keeps the session; "Transaction rolled back" after a cancel inside one; the dedicated session becomes an actor; APP_NAME "Echo"; extra result sets spooled. | `MSSQLDedicatedQuerySession*`, `WorkspaceTabContainerView+Execution`, `MSSQLNIOFactory` | A cancel keeps #temp tables; no 45 s stop | ☑ 057a797b, c051c455 (XA1), a5ed0ffb (Cancelling and Force Stop like PostgreSQL), 20688328 (BG1: extra result sets spool; `MSSQLDedicatedSessionResultSetTests`). The session serializes with a lock rather than an actor. 👁 pending |
| S5 | **Dropped connection (LC4 = Postgres CW2, RC2, WD2):** detect the drop at once, say what was lost, offer Reconnect; shared with the Postgres implementation. | Tab session store, Messages | Matches the Postgres build 👁 | ☑ a5ed0ffb (told at once, Reconnect, runs wait; idle drops quiet; footer transaction pill; `MSSQLDedicatedSessionConnectionLossTests`), 👁 pending |
| S6 | **Encryption (C4)**. | see C4 | see C4 | ☑ 057a797b |
| S7 | **Imports with the bulk load (round 25: IO1, EC1, FA1, BS1, ME1):** Options section (Empty cells, Keep identity values, Check constraints, Fire triggers, Lock the table); one transaction; 10,000-row batches; a note when INSERT statements were used; sqlserver-nio pinned to 303a7b0. | `BulkImportViewModel`, `BulkImportSheet`, `+Sections` | An import that fails at row 25,000 leaves nothing; empty cells take the column default when asked 👁 | ☑ 2a235de8 (`LabSQLServerImportTests`, `BulkImportViewModelTests`), 👁 pending |
| S8 | **Always Encrypted columns (round 29: EV1, EH1, ED1, CP1, AO1):** SQL Server connections ask for column encryption metadata; encrypted cells read 🔒 Encrypted, dimmed, in the grid and Table Data; a lock in the header with type, kind, algorithm and key path on hover; read-only, with an explanation on edit; Copy gives the ciphertext; sqlserver-nio pinned to e8f975a. | `ColumnInfo.Encryption`, `ResultGridValueClassifier`, `QueryResultsTableBridge+Table`/`+Columns`, `ResultTableHeaderCell`, `TableDataEncryptedCell`, `MSSQLNIOFactory` | An encrypted column reads Encrypted with a lock; its header hover names the key; editing says why it can't 👁 | ☑ c25d5be9 (`LabSQLServerAlwaysEncryptedTests`, `AlwaysEncryptedColumnTests`), 👁 pending |

## Phase 19 · Run button (rounds 20 and 24)

Rules: `decisions.md` › 2026-09-30 rounds 20 and 24.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| RB1 | **Tooltip (T1, U1):** where Run runs, or why it can't; Stop (⌘↩) and Stopping while running. | `QueryRunToolbarControl`, `QueryRunButtonText` | `QueryRunButtonTests` 👁 | ☑ built, 👁 pending |
| RB2 | **Never overflows (V1).** | `WorkspaceToolbarItems`, `ToolbarContent+Overflow` | Narrow the window: Run stays 👁 | ☑ built, 👁 pending |
| RB3 | **⌘↩ toggles Run and Stop.** | `EchoApp+QueryMenu` | ⌘↩ while running stops 👁 | ☑ built, 👁 pending |
| RB4 | **Timer K1, drawn ✓ (E1), Stopping (J1).** | `QueryRunToolbarControl`, `ElapsedTimeText` | 👁 | ☑ built, 👁 pending |
| RB5 | **Long query notification (N1).** | `NotificationEngine+LongQuery`, `LongQueryNotice`, `QueryEditorState.runEndedHandler` | `QueryRunButtonTests` 👁 | ☑ built, 👁 pending |
| RB6 | **▶ into ■ (round 24):** one button in its own glass; ■ replaces ▶ in place, the glass fades to red, then it grows and the time fades in; the red drains as the ✓ draws. | `QueryRunToolbarControl(+Components)`, `WorkspaceToolbarItems`, `LayoutTokens.Toolbar`, `ColorTokens.Text.onFill` | Matches the lab 👁 | ☑ built, 👁 pending: the glass Echo draws must match its neighbours' height and the red the system's prominent red |

## Phase 20 · Query editor (round 28)

Rules: `decisions.md` › 2026-10-01 round 28; `05-components` › Editor card.

| ID | Task | Where | Done when | Status |
|---|---|---|---|---|
| QE1 | **Text (28.1):** lines 1.55 × the size; Line Height Compact, Comfortable, Relaxed; SF Mono default (moved once); ligatures off; code 16pt after the numbers; 8pt top. | `SQLLayoutManager.lineHeight`, `EditorLineHeight`, `GlobalSettings` (typography revision 2), `SQLEditorTheme`, `AppearanceSettingsView+EditorFont`, `MonospacedFontPicker`, `LayoutTokens.EditorGutter.numberTrailing` | `EditorTypographySettingsTests` 👁 | ☑ 9715ce3b, 👁 pending |
| QE2 | **Gutter (28.2):** numbers 2pt under the code, tertiary, the caret line's in the text colour; Hairline style. | `LineNumberRulerView`, `EditorGutterStyle` | `LineNumberRulerTests` 👁 | ☑ 9715ce3b, 👁 pending |
| QE3 | **Caret line and selection (28.3):** no band; system selection with corners from Settings (3pt); system caret. | `SQLTextView`, `SQLLayoutManager.fillBackgroundRectArray`, `EditorSelectionCorners`, `AppearanceSettingsView+Selection` | `EditorTypographySettingsTests` 👁 | ☑ 9715ce3b, 👁 pending |
| QE4 | **Statement (28.4):** a bracket beside the numbers, solid for a selected result's statement; grey Run arrow, accent on hover. | `SQLTextView+StatementFocus`, `LineNumberRulerView+StatementBracket`, `LayoutTokens.EditorGutter.statementBracket*` | `StatementFocusTests` 👁 | ☑ 9715ce3b, 👁 pending |
| QE5 | **Run note count:** every row the server sent, as the footer. | `QueryEditorState+Execution` | `QueryEditorStateRunNoteTests` | ☑ 18b2898d |
| QE6 | **Marks (28.5):** soft letters-high word highlight with Highlight Corners; bracket flash. | `SQLTextView+Background`, `+BracketMatch` | `EditorMarksTests` 👁 | ☑ 56799682, 👁 pending |
| QE7 | **Errors (28.6):** tinted pill, glass popover bubble on hover or caret line, live check on leaving the line or 2 s. | `ErrorPillView`, `ErrorBubble`, `SQLTextView+ErrorMark`, `+Validation` | `EditorErrorMarkTests` 👁 | ☑ 306a8fb2, 👁 pending |
| QE8 | **Run note (28.7):** glass pill per statement; breathing bracket while running; fading line when done. | `RunNotePill`, `QueryEditorState+RunNotes`, `LineNumberRulerView+RunMarks` | `QueryEditorStateRunNoteTests` 👁 | ☑ f530ad91, 👁 pending |
| QE9 | **Zoom (28.8):** 100% pill, menu, ⌘+ ⌘− ⌘0, pinch, per tab. | `EditorZoom`, `EditorZoomControl`, `SQLTextView+Zoom`, `EchoApp+ViewMenu` | `EditorZoomTests` 👁 | ☑ a80770d9, 👁 pending |
| QE10 | **Typing (28.9):** Go to Line field, soft tabs, indent, pairs, ⌘/. | `SQLEditorTyping`, `SQLTextView+Typing`, `GoToLineField` | `EditorTypingTests` 👁 | ☑ 8464a8c1, 👁 pending |
| QE11 | **Empty tab (28.10):** prompt on line 1, nothing else. | `SQLTextView+Placeholder` | `TablePreviewQueryTests` 👁 | ☑ 433f34e1, 👁 pending |
| QE12 | **Settings (28.11):** Settings › Editor; Aurora and Midnight only; whole sizes. | `EditorSettingsView`, `SQLEditorPalette+BuiltIn` | `EditorTypographySettingsTests`, `GlobalSettingsTests` 👁 | ☑ c30bc3e7, 👁 pending |
| QE13 | **Find bar (28.12):** glass capsule, menu options, Selection button. | `EditorFindBar`, `EditorFind`, `SQLTextView+Find` | `EditorFindTests` 👁 | ☑ ac5089f6, 👁 pending |
| QE14 | **Search and replace (28.13):** preview in the text, Replace grows the capsule, one-step Replace All. | `SQLTextView+FindPreview`, `EditorFindBar` | `EditorFindTests` 👁 | ☑ ac5089f6, 👁 pending |
| QE15 | **The lane (28.14):** full height, concentric corners, numbers centred. | `EditorGutterSurface`, `LineNumberRulerView` | `LineNumberRulerTests` 👁 | ☑ ac5089f6, 👁 pending |
| QE16 | **One mark language (28.15):** `EditorMarkTokens`, round ends, two strengths, Settings › Editor › Marks. | `EditorMarkToken`, `SQLTextView+Marks`, `SQLLayoutManager`, `EditorSettingsView` | `EditorMarksTests`, `GlobalSettingsExtendedTests` 👁 | ☑ ac5089f6, 👁 pending |
| QE17 | **Zoom pill (round 31):** 12pt in, 9pt up; above the server pill without results; 24pt, primary. | `EditorZoomControl`, `QueryInputSection` | `EditorZoomTests` 👁 | ☑ 3626716a, 👁 pending |

## Phase 21 · Settings pages (round 43)

| # | Task | Where | Done when | Status |
|---|---|---|---|---|
| SE1 | **The template:** `SettingsPage(preview:sections:)` with a pinned preview and Reset This Page; `PictureChoicePicker`; `PropertyRow` gains a ↺. | `DesignSystem/Components/SettingsPage`, `PictureChoicePicker`, `PropertyRow` | A page gets preview, ↺ and reset from the component 👁 | ☑ built, 👁 pending |
| SE2 | **Editor page:** a live editor preview of every setting, pictures for gutter, corners and strength, a size stepper, short lines and ⓘ. | `EditorSettings/*` | Every setting changes the preview 👁 | ☑ built, 👁 pending |
| SE3 | **Results and Sidebar previews:** the grid; a narrow server card (owner's note). Appearance has none: the app is the preview. | `ResultsSettingsPreview`, `SidebarSettingsPreview` | Matches the lab's Proposal 👁 | ☑ built, 👁 pending |
| SE4 | **Search and reset:** a search field lists settings across pages; Reset This Page confirms first. | `SettingsSearchIndex`, `SettingsSearchResults`, `SettingsWindow` | Typing "gutter" finds Line Numbers and Gutter Style 👁 | ☑ built, 👁 pending |
| SE5 | **Per connection (PC0):** two deliberate ones: the query time limit (round 21) and Confirm Unguarded Writes (an UPDATE or DELETE without WHERE asks first; Default, Always or Never per connection, synced). Settings › Databases lists the connections that chose, each with its colour dot. | `SavedConnection.confirmUnguardedWrites`, `UnguardedWriteDetector`, `WorkspaceTabContainerView+UnguardedWrites`, `ConfirmUnguardedWritesRows`, connection editor | A production connection set to Always asks before `delete from t` 👁 | ☑ built, 👁 pending |
| SE6 | **Settings sync (SY0):** settings already synced as one blob; now this Mac's paths (spool folder, pg and MySQL tool paths) are left out going up and kept coming down. Window sizes were never in settings. | `GlobalSettings+Sync`, `SyncAdapter` | A path set on one Mac stays on it 👁 | ☑ built, 👁 pending |

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
- The Echo Labs playgrounds are the visual reference for every 👁 task; build to match them.
- Four pre-existing unit test failures on `dev` are unrelated; don't chase them in this work.
- The owner builds and checks on their Mac. Say what couldn't be verified.
