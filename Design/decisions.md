# Decision log

Newest first. Each entry says what was decided, and where the rule now lives. When a rule changes, add an entry; never rewrite an old one.

## 2026-09-29 · Tree card revised to S4 Quiet with folders

The owner revised the tree card choice to **S4 Quiet**, with the Design Lab's **Folders** and **Dimmed prefix** controls. The card stays the same. At medium density, ordinary rows are 28pt in a 29pt slot, with 13pt labels, 13pt light monochrome-rendered symbols, an 8pt icon-to-label gap, 16pt indentation and 8pt corners. There is no separate disclosure column: a folder's icon becomes a 10pt semibold chevron on hover. Folder counts appear on hover. Selection returns to the semantic grey fill; selected icons remain accented. Server-level groups return to ordinary folders and their children regain one indent level. The bold server name and version, Vivid icon palette and ordered blueprints remain. Supersedes the S1 and Sections choices below. → 05-components, 06-tokens

## 2026-09-29 · Phase 6–9 answers

- **Cancel Query is ⌥⌘.**; EchoSense keeps ⌘. → 05-components, plan K1
- **The tab overview button** leads the right-hand capsule: [Overview · Refresh · Bell · Inspector]. → 05-components
- **Query shortcuts kept:** Run Statement at Cursor ⇧⌘↩, Explain ⌥⌘E, Explain Analyze ⌥⇧⌘E, Validate ⇧⌘B, Search ⌥⌘F, Command Palette ⌘K. → 05-components
- **Statement at cursor** ends at a semicolon, a `GO` line or a blank line (blank lines split, even inside a procedure body). → 05-components

## 2026-09-29 · EchoSense keeps ⌘.

The owner: EchoSense must be triggered by ⌘., which is muscle memory; users can pick another shortcut. This reverses K3's "EchoSense off ⌘." and clashes with "Cancel on ⌘.". Cancel is ⌥⌘. until the owner picks its shortcut. Open. → 05-components, plan K1, K3

## 2026-09-29 · The database switcher becomes a system popover

The owner found the status popover's Liquid Glass perfect and the switcher's in-window glass flatter and whiter (glass drawn inside the window samples only the card behind it and has no window shadow). Rather than an AppKit panel to mimic a popover without its arrow, the owner chose SwiftUI's own `.popover`, accepting the arrow, "and not fight it, as it will cause different theming issues". The card keeps its filter, list and keyboard; the popover handles closing. Replaces L2/A2. → 05-components › Results card, Floating cards

## 2026-09-29 · Round 11 corrected: T1 with two-line tabs and icons

The owner meant **T1 (Safari)**, not T2, together with T7's two lines, and from round 12 **L2's icon**; no more lab rounds for the tab bar. The glass tab bar: inactive tabs have no fill, full-strength titles and hairline dividers; the active tab is a raised white pill; every tab shows its kind's icon (a spinner while running) and two lines, the title over the database (the timer while running). The bar is 10pt taller. Classic stays as the fallback. Supersedes the T2 entry below. → 05-components

## 2026-09-29 · Tree card answers: S1 Tahoe, sections, blueprints

Design Lab page "Tree card · contents" (owner's answers, pasted in chat):
- **Tree style: S1 Tahoe.** 26pt rows in a 27pt slot (medium), 13pt labels, 13pt hierarchical symbols in both icon modes, 9pt bold chevrons in the quaternary grey, 7pt between chevron, icon and label, 14pt indent, 8pt row corners, the selection tinted with the row's accent (18%, 30% with Increase Contrast) instead of grey, and the server's name in bold 13pt primary with its product and version on the right. Replaces the grey selection pill, the 12pt indent and the 11pt grey server name. → 05-components, 06-tokens
- **Icons: colourful by default, Vivid palette** (today's colours softened 22%). Monochrome stays a setting. → 05-components
- **Schema names: the dimmed prefix stays.** → 05-components
- **Server folders are sections:** Databases, Security, Agent Jobs and the other server-level folders are Finder-style headings (11pt semibold grey, count, a trailing chevron shown while collapsed or hovered), and their children start at the card's left edge. MySQL's and SQLite's server tools move under a Management heading so they don't read as databases. → 05-components
- **Tree blueprints: accepted.** Each database type's tree becomes an ordered blueprint with node kinds and roles, replacing the switch statements. Plan Phase 2b. Explainer: https://claude.ai/artifact/N7UL1qHMGicpthQmSKVa89

## 2026-09-29 · Tree card contents opened

The owner likes the server card itself but finds the content inside it dated. Design Lab page "Tree card · contents" shows six styles beside today's (S1 Tahoe, S2 Tiles, S3 Structure, S4 Quiet, S5 Detailed, S6 Path), each in colourful and monochrome, with shared controls for the palette (Vivid, Soft, Families, Server colour), schema names and server folders as sections. The card's surface, corners, edge and shadow are not in question. It also proposes describing each database type's tree as an ordered blueprint (explainer: https://claude.ai/artifact/N7UL1qHMGicpthQmSKVa89). Open.

## 2026-09-29 · Round 11 answer: T2 filled tabs; two-line tabs to explore

Design Lab round 11 (owner's answer, pasted in chat): **T2, filled tabs** inside the glass capsule, so inactive tabs read as buttons with near-full-strength text. "I like the idea of T7 with two lines. Let's explore that as well" → round 12 in the Design Lab explores two-line versions of T2. Also: the results must fold back into the footer smoothly; it now runs as one continuous path (the editor card grows back to full height while the results card lands on its bottom edge and its chrome fades out). → 05-components

## 2026-09-29 · Round 11 opened: the tab bar again

After living with TB1, the owner finds the glass capsule weaker than the old strip ("the tabs not used is too light"). Round 11 in the Design Lab lays out eight designs (T1 Safari, T2 filled tabs, T3 separate pills, T4 server colour, T5 hugging, T6 underline, T7 two-line, T8 accent active) beside today's glass and Classic. Fixed meanwhile: results always fold back into the footer; the status pill sits at the far right.

## 2026-09-29 · Round 10 review page answers

Page: https://claude.ai/artifact/BfUjeUCPDv9rd6cDXzCwEA (collection `round10`)
- **Results entrance: RS2, the results grow up out of the footer** ("I want it to look like it is the footer that is expanding up"). Rejected RS1 (split in place) and RS3 (crossfade). → 05-components, 04-motion
- **Pinned path header: P1, removed**, with its blur and its setting. Rejected P2 (only with one server), P3 (blur only), P4 (keep it, off by default). → 05-components
- **Inspector: IN1, a column of cards on the canvas**, mirroring the tree. Rejected IN2 (floating card), IN3 (inside the results card), IN4 (native, restyled). Phase 9 is rewritten around it. → 05-components, plan Phase 9

## 2026-09-29 · Round 10, Design Lab answers

Lab page "Round 10 · footer and switcher" (owner's answers, pasted in chat):
- **Footer right-hand side: a glass pill per entry** (status, selection summary, rows, time), the same size as the server · database chip. `FooterMetricsStyle.pillPerEntry` is the default. → 05-components
- **Database switcher: L2, a card floating above the chip**, which stays visible; no chip label inside the card. → 05-components
- **Opening: A2, the card rises** a little while fading in, with the house spring. It replaces the frame morph. → 04-motion, 05-components

## 2026-09-29 · Round 9 decided in the Design Lab

Lab page "Round 9 · open questions" (owner's answers, pasted in chat):
- **Behind the footer: FB1, soft blur** (`BackdropEdgeBlur` over the AppKit grid and editor). Follow-up asked: show the right-hand data (status, rows, time) as one big pill or a pill per entry; that goes to round 10. → 05-components
- **Footer position: FP1**, lifted 4pt from today. → 05-components, 06-tokens
- **Tree scroll bar: SB3, none**, with a setting to show it, off by default ("Show Scroll Bar" in Settings › Sidebar). → 05-components
- **Tab bar: TB1, one glass capsule with + inside.** The owner isn't fully sold, so the old strip stays in the code as "Classic", switchable in Settings › Appearance, to revert to. → 05-components
- New asks for round 10: the results card's entrance should split the editor card rather than rise from the bottom; a view on removing the pinned path header; an Inspector phase; and the database switcher's card and animation judged in the Design Lab (it should open as a glass card from the pill).

## 2026-09-29 · Scroll bar, database switcher, footer and tabs (review round 9, first answers)

Page: https://claude.ai/artifact/U3DDrkf5zQUEq6635UVBaY (collection `round9`)
- **Database switcher DB1:** clicking the footer chip grows it upward into a glass list with a filter field at the top, no arrow; Esc or a click outside shrinks it back. It replaces the system popover. Rejected DB2 (native menu) and DB4 (pick it in the tree). → 05-components
- **DB3 as well, not instead:** "Switch database" also joins the ⌘K palette in Phase 6 ("This is not a replacement but an alternative"). → plan K4
- **Faster tab switching (TFIX):** tabs become real buttons, so a click selects at once and dragging still reorders; recently used tabs keep their editors alive, so switching back keeps scroll, undo and cursor. → 05-components, plan B5
- Rejected: SB2 (a scroll bar inside each card), SB4 (position shown in the rail), FP2 (footer inset by the corner radius), TB2 (tabs on the canvas), FB3 (a glass footer bar with glass pills inside it: glass on glass).
- **Still open, to judge in the Design Lab:** scroll bar SB1 or SB3; footer position FP1 or FP3; tab bar TB1, TB3 or TB4; and what sits behind the footer, FB1, FB2 or FB4 (section 5, added after the owner found the solid band behind the footer ugly: soft edge, hard edge, or one glass bar with flat controls inside).

## 2026-09-29 · After the SwiftUI tree build (asked in chat)

- Bug: the tree's cards layer set the tree's minimum height, so the window grew with the tree and couldn't be shrunk. The cards now draw in the scroll view's background.
- **Hiding the tree no longer overshoots:** it uses a spring with no bounce (`settle`), and showing it keeps the bounce. The rail-edge mask is gone because it cut the tree card's shadow. → 04-motion
- **Footer:** the result views pill sits right beside the server/database chip instead of in the middle. → 05-components

## 2026-09-29 · Corners and tree motion (review round 8, first answers)

Page: https://claude.ai/artifact/XPy7hr8a2BgpXjejFSxUWA
- **Card corners 16pt by default** (C3), the macOS 27 window corner as measured from the owner's screenshot (about 16pt; my first guess of a 26pt window and 20pt cards was wrong). A Card Corners setting in Appearance offers 10 / 12 / 16 / 20 / 26pt for every card. → 02-layout, 06-tokens
- **Hiding the tree keeps the bounce, walled off** (M1): everything right of the rail is masked at the rail's edge. **The tree slides left behind the rail** as it fades (M2's motion) instead of shrinking. → 04-motion
- Answered on the page (collection `round8`):
  - **The Explorer tree is rebuilt fully in SwiftUI, replacing the AppKit table, with no debug switch** ("more future proof"). That settles tree cards as T1 (each server card is the editor's own `.workspaceCard()`) and the path header as H1 (a pinned glass section header that blurs the rows). → 05-components, `swiftui-tree.md`
  - **Welcome W1b:** one centred column on the canvas: Echo's icon, "Echo" large, the glass actions, the recents card. No subtitle. Rejected W1a and W1c. → 05-components
  - **Server page S1a:** the server name large, only the version under it, the glass tools, then a databases card with a filter; its top lines up with the rail. Recent queries and connection details leave the page. Rejected S1b and S1c. → 05-components
  - **Footer FT1a:** no strip or divider; the server and database as a glass chip (no chevron; click to switch database), the result views in one glass pill, and the status, rows and time as quiet text. Rejected FT1b, FT1c and FT1d. → 05-components

## 2026-09-29 · Tree cards, scrolling and the bottom edge (review rounds 5–7)

Pages: round 5 https://claude.ai/artifact/CZU1FEeERxgrgLLYttJJ1U · round 6 https://claude.ai/artifact/3VqbnxEy4z1ThCnQJt64Ta · round 7 https://claude.ai/artifact/D77uNvnAc3AzGzic7k88PW and https://claude.ai/artifact/RMNCE8fCR7X367ydcyUjZk
- **Tree cards use exactly the editor card's tokens** (fill, edge, `workspaceCard` shadow, 12pt corners). The lighter shadow and the lifted card from round 4 are gone. The tree follows the existing settings: Spacing Between Panes sets the gap between cards, the Explorer size setting sets the rows. No new card settings. → 05-components, 06-tokens
- **Glass card header** (round 6, option 2): once a server's own header scrolls away, "server › database" pins at the top of its card on Liquid Glass with the card's rounded top corners; rows blur through it. It holds controls, so glass is allowed. Replaces the blurred path bar. Rejected: opaque sticky top (1), scrolling under the toolbar (3), a blur band (4). → 05-components, 03-materials
- **Rounded end** (round 7, F2): the tree stops one gutter above the window edge, on the editor card's bottom line; a card that runs past the bottom is cut into rounded corners with the full card shadow. No fade anywhere. Rejected: glass footer (F1), next-server tab (F3), filter bar (F4). → 05-components
- Fixed as bugs: the first card lines up with the rail and tab plate; connecting and failed servers come last in rail order, each on its own card; the scroller is the small overlay scroller inset inside the card corners; the sidebar toolbar button has its own glass. → 05-components

## 2026-09-29 · Tree cards and server page (review round 4)

Review page: https://claude.ai/artifact/2A6mzm6CNJTKnWt8FwLETg
- **Each server's tree sits on its own opaque card** (option B, "Server groups"). The card has the editor card's fill, a lighter shadow, and 12pt corners; the server at the top of the tree, which the rail selects, lifts with a slightly stronger shadow. The first card lines up with the top of the rail. Replaces "the tree has no panel or background of its own". → 02-layout, 05-components, 06-tokens
- **Opaque, not glass.** The owner asked; the reasons: the tree is content, glass over the flat canvas has nothing to refract and reads as a grey box, and glass trees would compete with the glass rail. "Glass only on controls" stands. → 03-materials
- Rejected: one full-height tree card (A), staying on the canvas with lines and a tint (C), glass per server.
- **Server page in the welcome's style:** on the canvas with no big card; icon, name, host and version; the tools on Liquid Glass buttons with New Query prominent; "New query in", "Recent queries" and "Connection" as small opaque cards with 28pt rows, two columns when there is room. → 05-components

## 2026-09-29 · Empty window (asked in chat)

After the owner opened Echo with nothing connected:
- **The tree only shows when it has content:** a server in the rail (connected or connecting) or a tool page from the bottom pill. With neither it is hidden and ⌃⌘S and the toolbar button do nothing. → 02-layout
- **Welcome on the canvas, no card.** Cards are only for content. With no tab and no active server the canvas shows Echo's icon, "Connect to a server", glass buttons (Connect… prominent with the connections menu, Quick Connect, Manage), and the 5 latest connections on one small opaque card, each row with its rail monogram in the server's colour, name, host and when it was last used. Tiles and a search-first welcome were offered and not chosen. → 05-components
- **Sidebar button in the toolbar** at the leading end (`sidebar.left`), as on every Mac app with a sidebar. Fixed as a bug: ⌃⌘S now reaches Echo, because the system's sidebar menu item is replaced.

## 2026-09-29 · First build of the shell (asked in chat)

After the owner ran Phase 1:
- **+ back in the rail**, as the last item of the server pill. It opens the connections menu and replaces the toolbar's Connections button (Recent and Quick Connect stay in the toolbar). Reason: with one server the pill held a single item and read as a double border; connecting from the rail is also closer to the servers. Replaces "no + in the rail" from round 1. → 02-layout, 05-components
- **Selection disc inset 3pt** inside its item, so it never echoes the pill's edge. → 06-tokens, 05-components
- **Tools stay a vertical pill** at the bottom of the rail, the same width as the server pill. Horizontal under the tree, one combined pill and toolbar tools were offered and not chosen. → 02-layout
- Fixed as bugs, no rule change: the start page lists the 5 latest connections; content can never push the window past its edges; the rail, tree and tab plate sit one gutter below the toolbar and the plate lines up with the card; the pinned path blur is tinted to the canvas and fades at every edge.

## 2026-09-29 · Last open questions (asked in chat)

Decided:
- Stronger connecting pulse confirmed. → 06-tokens, 05-components, 04-motion
- Rail status: running queries show nothing in the rail; a lost connection dims the monogram to 40%, with the reason in its tooltip. → 05-components
- Toolbar grouped by task; tab-specific tools in one contextual capsule next to Run. → 05-components
- Run gets a chevron menu of run modes. → 05-components
- No floating editor capsule. → 05-components
- Double-click the gap to maximise the results. → 05-components
- Autocomplete keeps its system popover, the one exception to arrowless cards; no panel windows planned. → 03-materials, 05-components

With this, nothing in the design is left Open.

## 2026-09-29 · Review round 3 (Design Lab), second part

The remaining 11 questions.

Decided:
- Rail selection: liquid stretch (glass lens rejected, so "no glass on glass" is now fully decided). → 05-components, 04-motion, 01-principles, 03-materials
- Selected monogram in its server's colour. Pill growth and the translucent canvas accepted. → 05-components, 06-tokens
- Connecting pulse was too subtle: stronger values proposed, to confirm in the Design Lab. → 06-tokens
- Results: name + type header with a sort arrow on hover; row hover tint with an accent row number; one-outline selection; footer with rows loaded of total and a selection summary; monospaced cells setting. → 05-components
- One footer only, in the results card, holding both the connection picker and the results data. The window-wide status bar goes away. → 05-components

## 2026-09-29 · Review round 3 (Design Lab), first part

17 of 28 questions answered in the Design Lab. The server rail and results grid pages couldn't be judged because the playgrounds slid under the lab's page list; that is fixed, and those 11 questions are still open.

Decided:
- Card corners 12pt, replacing the earlier "concentric with the window" rule. → 02-layout, 06-tokens
- Floating card shadow. Gutter 6pt, adjustable in settings (4/6/8). → 02-layout, 06-tokens, 01-principles
- Hiding the tree: the tree shrinks into the rail. → 02-layout, 04-motion
- Server click with the tree hidden: peek, ⌘-click reopens; adjustable in settings. → 05-components, 01-principles
- Tab strip on the canvas above the cards. Results card rising accepted. → 02-layout, 05-components
- Tree: bold server header; pinned header with breadcrumb accepted; monochrome mode defaults to accent on open folders, with pure monochrome as a setting; soft colourful mode accepted. → 05-components
- Toasts: stacking, expanding on hover, ×2/×3 repeats and the history card growing out of the bell all accepted. → 05-components
- Inspector: proposed design and smooth width change accepted. → 05-components

Still open (to judge in the Design Lab): rail selection style, selected monogram colour, connecting pulse, pill growth, rail on the translucent canvas; results column header, row hover, selection outline, footer content, where the connection bar lives, monospaced cells setting.

## 2026-09-29 · Review round 2 (deep dives)

Decided:
- Motion: bouncy by default; speed setting Default / Fast (Slow rejected). → 04-motion
- Glass morphing everywhere it explains change: new server from the pill, peek card from its server, toolbar groups, stacked toasts, new tab from +. → 04-motion
- Rail: server pill hugs its servers and scrolls once full. Connecting servers breathe. → 05-components
- Tree: expand with a slide and fade; loading with shimmer rows; the server header is the sticky header, with a breadcrumb. → 05-components
- Search: minimised toolbar search plus ⌘K palette; finds objects, tabs, actions and history. → 05-components
- Tabs: Safari as the reference; keep today's grey plate, tokenised; switching is instant; running shows spinner + timer; many tabs collapse inactive ones to icons. → 05-components
- Tab overview is the "open queries" view: toolbar button + pinch; calm cards with live state; zoom motion. → 05-components
- Run is the one tinted toolbar item (accent, red while running). Echo keeps control of toolbar grouping. → 05-components
- Editor actions stay in the toolbar. Gutter: subtle or tinted as a setting, with validation markers. Results card rises after the first run; drag the gap to resize. → 05-components
- Results: right-aligned numbers, boolean symbols, monospaced setting, one outline per selected range, accent row numbers, no footer Export, NULL stays as text. → 05-components
- Notifications: stacked and expandable glass toasts; history under a toolbar bell; query errors in the results card plus a toast for background tabs. → 05-components
- Floating cards: in-window glass, no arrow, close on outside click or Esc, no pin. → 03-materials, 05-components
- Inspector: native; one section style, smooth width, row-detail mode. → 05-components

Left open after round 2 (see round 3 for what was settled): card corners, shadow and gutter; rail selection and monogram colour; tree-hide motion; server click with the tree hidden; tree header style and monochrome variant; results header, hover, footer; where the connection bar lives; tab strip position; inspector look; toolbar group layout.

## 2026-09-28 · Review round 1 (143 options)

Decided:
- Canvas and cards layout replaces the system sidebar. → 02-layout
- System grey canvas by default, translucent as the alternative, graphite dark mode. → 02-layout
- Rail: Liquid Glass, two pills, medium size with a setting, monograms, system tooltip, highlight follows scroll, no + in the rail. → 02-layout, 05-components
- Tree hidden: the rail stays identical and the cards slide over the tree. → 02-layout, 04-motion
- Tree: grey selection, plain counts, breadcrumb sticky header, density levels stay. → 05-components
- Toolbar: glass groups. Editor and results as two cards, results footer kept. Inspector stays native. → 02-layout, 05-components

Rejected: glass cards for content, flush panes without gutters, white canvas, one combined rail pill, tools under the tree, a + at the top of the rail, colour dots and engine badges on servers, ring and comet status indicators, a search field at the top of the tree.

## 2026-09-28 · Direction chosen

The "Canvas and cards" direction, inspired by Outlook's Mac layout: rail pill at the leading edge, tree on the window canvas, content in floating cards. It replaced the adaptive server rail inside the system sidebar, which read as loose buttons with the tree lost in the middle.
