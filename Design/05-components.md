# Components

Each section lists the rules for one part of Echo. Items marked **Open** have a Echo Labs preview; when one is settled, update it here and in `decisions.md`.

## Server rail

- Two glass pills: servers on top, tools at the bottom. See `02-layout.md`. *Decided.*
- **Identity is a two-letter monogram** from the connection name ("18", "TI"). The selected monogram takes **its server's own connection colour**; the others are secondary grey. *Decided.* Colour dots and engine badges were rejected.
- **Selection: liquid stretch.** A white disc sits under the selected monogram. When the selection moves, its leading edge races to the target and the trailing edge follows, so it stretches like a drop and settles back into a disc. *Decided.* A plain sliding disc, a glass lens, a tinted disc and a ring were rejected.
- **The server pill grows and shrinks** with a spring as servers connect and disconnect, and works on the translucent canvas. *Decided.*
- **The highlight follows scrolling:** the rail marks the server whose rows are at the top of the tree. A click holds the highlight on the clicked server while the tree glides to it. *Decided.*
- **Hover** shows the system tooltip (name and host). No custom hover cards. *Decided.*
- **Status:**
  - A connecting server's monogram breathes (opacity) until it connects. The first version was judged too subtle; the stronger values in `06-tokens.md` need a quick check in the Echo Labs. *Decided*, stronger version confirmed.
  - Running queries show nothing in the rail; the tooltip and the peek list them. *Decided.*
  - A lost connection dims the monogram to 40%, and the tooltip says why. *Decided.*
  - Rings, comets, count badges and extra dots were rejected.
- **A + ends the server pill** and opens the connections menu; it is never selected and the disc never moves onto it. It replaced the toolbar's Connections button. *Decided* (2026-09-29).
- **The selection disc is inset 3pt** inside its item, so a single server never looks like a pill inside a pill. *Decided* (2026-09-29).
- Item size: medium (34pt) default, with small and large as a setting. *Decided.*
- **Clicking a server with the tree hidden:** a plain click peeks (the tree for that server slides out over the cards; a click away or Esc slides it back), and ⌘-click or double-click reopens the tree for good. *Decided.* A setting lets users choose instead "always peek" or "always reopen the tree". The glance card and "switch context only" were rejected.

## Server page

- Shown on the canvas while a server is active and no tab is open. No big card, like the welcome. *Decided* (review round 4).
- No icon. The server name in 26pt bold, only the version under it (the host is its tooltip); the page's top lines up with the rail. *Decided* (round 8, S1a).
- The server's tools as **Liquid Glass buttons** (`.glass`), with **New Query** first as `.glassProminent`. Tools that need a database open a menu of them. The buttons wrap when the window is narrow. *Decided.*
- The databases on one small opaque card with a filter field, 28pt rows. Recent queries and connection details are not on this page. *Decided* (round 8).

## Welcome

- Shown on the canvas while no tab is open and no server is active. **No card**: cards are only for content. *Decided* (2026-09-29).
- Centred, 420pt wide: Echo's icon (64pt), **"Echo"** in 26pt bold, then glass buttons: **Connect…** (prominent, opens the connections menu), Quick Connect, Manage. No subtitle. *Decided* (round 8, W1b).
- Below, "Recent" and the **5 latest connections on one small opaque card**, 28pt rows: the rail monogram in the server's colour, name, host, and when it was last used. A click connects, and the server grows into the rail. *Decided.*
- With a server active but no tab, the server dashboard shows on a card as before.

## Explorer tree

- It is an SSMS/pgAdmin-style tree. *Decided.*
- **One opaque card per server**, hugging its rows, with exactly the editor card's look: `textBackgroundColor`, 12pt corners, 0.5pt edge, the `workspaceCard` shadow. Cards are one gutter apart (Spacing Between Panes), with 4pt below the last row. Never glass. *Decided* (review rounds 4 and 5; the owner likes the card as it is, tree card round).
- Servers are listed in the rail's order; connecting and failed servers come last, each on its own card. *Decided.*
- **No pinned header** (round 10, P1): rows scroll to the card's rounded top edge; the rail highlights the server you're scrolled into, and a rail click glides to a server's top. The glass header, its blur and the "Pin server and database" setting are gone. *Decided.* (Replaces round 6's glass card header.)
- **Rounded end:** the tree stops one gutter above the window edge, on the editor card's bottom line. A card cut by the bottom edge ends in rounded corners with its full shadow. No fades. *Decided* (round 7).
- **No scroll bar** (round 9, SB3); the rail shows which server you're in. Settings › Sidebar › Show scroll bar brings back the small overlay scroller, inset inside the card corners. *Decided.*
- **Row style: S4 Quiet** (revised tree card decision). *Decided.*
  - Rows are 28pt in a 29pt slot at the default density, so neighbouring highlights never touch; 13pt labels.
  - Symbols are 13pt light. **Duotone** by default (IC2, 2026-09-30): the outline in the role colour over its fill at low opacity; **mono line** (IC1) is the setting. A Recraft icon set is pinned for later. *Decided.*
  - No separate chevron column: a folder's icon becomes an 11pt semibold chevron on hover.
  - 8pt between icon and label; 16pt indent per level; 8pt row corners. Folder counts always show (round 16).
- **Section dock** (TC1, 2026-09-30; rounds 16 and 19): under the server's name, a row of icons switches what the card shows; the tree shows one section at a time. *Decided.*
  - **Capsule (C5):** Xcode's navigator icons spread across a Liquid Glass capsule as wide as the card, with a hairline edge and a soft shadow. Icons in **medium** weight, sized by the sidebar size; the current one in the accent colour, no fill; **hovered icons grow slightly**. The dock's icon style is its own setting (mono by default), apart from the tree's.
  - **At most five** sections in the capsule. Sections left out are listed by **More (»), a section of its own**: its card shows them as ordinary folders that open and right-click as usual. No database type's blueprint has more than five server-level sections.
  - **Pinned:** the name and the capsule stay at the top while the rows scroll under them. **Blur rows:** rows stay visible under the header, blurring and fading more towards the top over a light wash of the card colour. No material, no line.
  - **Switching (S3):** the card's rows fade out, swap and fade in while the card's bottom edge settles (`settle`). The view **jumps** instantly to where that section was left (while faded); a new section doesn't scroll. Each section keeps its open folders; the card remembers its section per connection.
  - **The other cards (N2):** only a card whose own place or height changes animates, and the view never scrolls back by itself when the list gets shorter; the room below the last card stays until you scroll up.
  - **Initial load (I4 · Folders first):** a section's folders and tools show at once, spinning in their count slots; a level that is only items shows one spinner row. The dock icon stays still.
  - **Menus:** right-click an icon for its section's own menu, then Dock (show or hide each section, the type's dock, Customize Dock); right-click the empty capsule for Dock alone.
  - **Customize Dock:** order and visibility for every server of the type (Settings › Sidebar, synced) or one server (on the saved connection).
  - Servers with fewer than two sections have no dock.
- **Server header:** the server's name heads its card in bold (13pt at the default size, following the sidebar size), primary, with the product and release under it in tertiary 11pt, followed by the current section when the card has a dock ("SQL Server 2022 · Security"; the full build in the tooltip). *Decided* (rounds 16 and 19).
- **Folders:** server-level groups are ordinary folder rows with children indented one level. SQL Server has five (round 19, SSMS's grouping): Databases (Database Snapshots at the end), Security, Server Objects (Linked Servers, Server Triggers), Agent Jobs and Management (with Integration Services Catalogs). MySQL's and SQLite's server tools sit under Management. *Decided* (round 19).
- **Selection:** the row uses the semantic grey fill and its icon turns accent, inset equally on both sides (round 16). The accent is the system's, the custom one or the server's colour, per the accent setting. *Decided* (revised tree card round).
- **Counts:** plain grey tabular digits at the right, always shown; zero is hidden. While a folder loads, a spinner takes the count's place. *Decided* (round 16; replaces "appearing on hover").
- **Schema names:** objects show their schema as a dimmed prefix (`employees.salary`). *Decided* (tree card round kept it; "schema on the right" and schema groups were rejected).
- **Density:** four levels (compact, small, default, large) stay as a setting. *Decided.*
- **Icon colour** stays a setting with two modes; **colourful is the default**. *Decided.*
  - Colourful mode uses the Vivid palette: today's colours softened towards grey (22%). Soft, Families and Server colour were rejected.
  - Monochrome mode defaults to **monochrome with accent on expanded folders**, so you see your path. A sub-setting switches to pure monochrome.
  - Colours are picked by the node's role, never by its title (tree blueprints, plan Phase 2b).
- **Expanding:** rows slide down with a fade (native table animation), scaled by the speed setting. *Decided.*
- **Loading:** a folder shows a quiet skeleton (row-shaped placeholders at the child indent, only after a quarter second), then the rows fade in. A section's first load is Folders first (above). *Decided* (round 16; replaces the shimmer).
- **No search field in the tree.** *Decided.*
- **Empty folders** are hidden by default, with a setting to show them. *Decided.*
- **How a tree is described:** each database type has an ordered **blueprint** (one file per type, built from shared fragments). The order in the blueprint is the order in the tree. Node kinds carry their title, symbol and role; the builder, rows and menus are generic. *Decided* (tree card round).

## Search

- **No search field in the toolbar** (owner, 2026-09-30): a magnifier at the start of the right-hand capsule, and ⌥⌘F, open the ⌘K palette. The system field was wide and pushed the Inspector toggle off the far right. *Decided.*
- **⌘K palette:** a centred glass palette. *Decided.*
- Both find objects across all connected servers, open tabs, actions ("Connect to…", "New query in…", "Switch database", "Run") and history and snippets. *Decided.*
- Find in Sidebar must move off ⇧⌘F, which clashes with Format SQL. *Decided.*

## Toolbar

- System glass, but **Echo decides the grouping** so related items always sit together. *Decided.*
- **Groups by task:** *Decided.*

  [Project] [Recents · Connections · Quick Connect] … [Run] [Format · Validate · Help · Plan] [MSSQL toggles] [Overview · Refresh · Bell · Inspector]

  Each bracket is one glass capsule.
- **Tab-specific tools** (Structure add and apply, Activity Monitor pause and refresh rate, Job Queue controls, Error log cycle, maintenance database) form one contextual capsule next to Run. It appears only on tabs that need it and melts in and out as you switch tabs. *Decided.*
- **Run** (round 15, idea 1) is a plain ▶ like its neighbours, with no tint and no chevron, in a capsule of its own so changing it moves nothing else. Running, it becomes ■ and the timer in red; a click cancels. When the query ends it shows ✓ or ! for a moment and settles back. The other modes (statement at cursor, Explain, Explain analyze) are on right-click and in the Query menu. *Decided.* The accent-glass Run with a chevron was rejected as too loud.
- Editor actions (Format, Validate, Context Help, Estimated Plan) stay in the toolbar. *Decided.* No floating capsule in the editor, whether always on, while typing or on selection. *Decided.*
- EchoSense keeps ⌘. (owner: muscle memory; it can be rebound). Cancel Query is ⌥⌘. *Decided.*
- Query shortcuts: Run ⌘↩, Run Statement at Cursor ⇧⌘↩, Explain ⌥⌘E, Explain Analyze ⌥⇧⌘E, Format ⇧⌘F, Validate ⇧⌘B, Search ⌥⌘F, Command Palette ⌘K. All can be rebound. *Decided.*
- Run Statement at Cursor ends a statement at a semicolon, a `GO` line or a blank line. *Decided.*

## Tabs

- **Tabs should look and behave like Safari.** *Decided.*
- **Round 9's strip, on one line** (2026-09-30): the grey plate with the raised white active tab; every tab shows its kind's icon (a spinner while running) and its title; the database is in the tooltip. Replaces the glass capsule with two lines below. *Decided.*
- **Switching tabs is instant.** Tabs are real buttons, so a click selects at once and dragging still reorders; recently used tabs keep their editors alive, keeping scroll, undo and cursor (round 9, TFIX). *Decided.*
- **Running query:** a spinner at the leading edge; the timer shows in the tooltip and the tab overview. *Decided* (one line, 2026-09-30).
- **Many tabs:** tabs shrink to a minimum width, then inactive tabs collapse to their icon while the active tab keeps its title. *Decided.*
- **New tab** grows out of the + button. *Decided.*
- **Position: on the canvas above both cards**, the way Safari's tab bar sits above the page. *Decided.*
- **One glass capsule** holding the tabs and the + as its last item; the active tab is the white pill (round 9, TB1). **Inactive tabs have no fill, full-strength titles and hairline dividers** (round 11, T1); every tab shows its kind's icon (a spinner while running) and two lines: the title over the database, or the timer while running (T7, round 12 L2). The bar is 10pt taller than the Classic strip. The earlier grey plate stays available as Settings › Appearance › Tab Bar › Classic, to revert to. *Replaced* (2026-09-30) by Round 9's strip on one line.
- **Tool pages unfold in the tab** (ST2, 2026-09-30): a tool with pages (Activity Monitor, Security, Server Properties) shows its pages as small chips inside its active tab; the other tabs make room with the house spring and it folds back when you leave. Replaces the segmented control at the top of tool tabs. *Decided.*

## Tab overview (open queries)

- The tab overview is Echo's "open queries" view. *Decided.*
- It opens from a toolbar button, with a trackpad pinch and ⇧⌘O. *Decided.*
- Look:
  - a slim header, then tabs grouped by server, active server first;
  - calm cards with live running state (timer and stop);
  - no gradient hero.

  *Decided.*
- Motion: the active tab zooms out into its card, and picking a card zooms back in. *Decided.*
- Group by the tab's current database, not the connection's default. *Decided.*

## Editor card

- Opaque card; SQL editor inside. *Decided.*
- **Fonts** (2026-09-30): JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Monaspace and Commit Mono, all SIL OFL. The default is still to be picked by the owner. **13pt with 1.55 line spacing** by default; both are settings. *Decided.*
- **Editor ideas** (2026-09-30), each a setting where it adds chrome: statement focus with a Run arrow in the gutter, results inline at the end of a statement, errors written on the line, a rounded current-line band with more room, an outline edge (setting), and faint starting points in an empty tab. *Decided.*
  - The empty tab's starting points: the four tables opened last on the tab's connection and database (Data, Structure, Diagram or search), then snippets. A table inserts its first-rows query. *Built 2026-09-30.*
- **Gutter:**
  - Three styles as a setting (2026-09-30): **Subtle** (numbers only), **Tinted column** (full height, cut by the card's corners, hairline edge) and **Tinted lane** (inset 5pt, rounded, no edge). *Decided.*
  - Numbers stop at the last line; the tint still runs the card's full height. *Decided.*
  - Both get current-line emphasis and validation markers (a red dot on failing lines). *Decided.*
  - Fixes that apply either way: one number per logical line, width that grows with digit count, and using the theme's gutter colours. *Decided.*
- **After the first run, the results grow up out of the footer** (round 10, RS2): the footer detaches from the editor card as a footer-high results card, then the seam travels up to the split line while the rows fade in. The editor keeps its scroll position, undo and focus. *Decided.*
- **Resizing:** drag the canvas gap between the cards; a grab capsule appears on hover. *Decided.* **Double-click the gap to maximise the results**: the editor shrinks to a one-line card. Double-click again to restore. It is also available as a menu item with a shortcut. *Decided.*

## EchoSense

Decided 2026-09-30 (design board, round 14). Ranking and rules stay as in `AUTOCOMPLETE_SPEC.md`.

- **Rows:** a kind badge, the name in the editor's font with the typed letters in bold accent, the alias or table for columns (always for same-named columns), and the type on the right. *Decided.*
- **Selection:** tinted while typing; solid once you move with ↑/↓, meaning Return inserts it. *Decided.*
- **Details footer:** the selected row's full name, type, source and detail with key hints, in an inset rounded panel concentric with the popup. No side panel and no timer. *Decided.*
- **Material:** the card fill, card edge and floating shadow; the corner follows Card Corners, capped at 14pt, and rows use it minus the padding. *Decided.*
- **Ghost text** (the top match inline in grey, Tab accepts) is a setting, off by default. *Decided.*

## Connections

Decided 2026-09-30.

- **One short sheet** for Quick Connect and New Connection: engine (segmented), server and port on one line, database, sign in, Keychain; Security and timeouts in one disclosure with a summary, which remembers whether it was open. Name, folder and colour only appear while "Save to Connections" is on; Quick Connect never asks for them. Quick Connect saves its password in the Keychain too. *Decided.*
- **Editing happens in Manage Connections:** its detail pane is the editable form; + adds a connection with the same form. *Decided.*
- **SQL Server encryption (round 22):** new connections start at Mandatory; the Encryption menu says what each mode checks (Optional encrypts without checking the certificate, Mandatory checks it, Strict is TLS first and always checks); Trust Server Certificate dims under Strict; an "Allow TLS 1.0" switch, off by default and absent under Strict, is for servers without their TLS 1.2 update; a failed Test names the certificate check that failed and offers Trust this certificate or Host Name In Certificate. *Accepted, being built.*
- **Rules:** the default button is never silently disabled (missing fields get an inline message and focus); the port placeholder follows the engine; pasting a connection URL or string fills the form; the test result sits beside the buttons. *Decided.*

## Tool tabs

Decided 2026-09-30.

- **One tool header** for every tool tab: the tool's icon, title, server and freshness ("updated 2 s ago"), and the tool's actions on the right. *Decided.*
- **Panes are cards** on the canvas, a gutter apart, like the editor and results cards. *Decided.*
  - A tool whose pages mix one-pane and several-pane layouts keeps one card for the one-pane pages; the card steps aside when the page brings cards of its own. *Built 2026-09-30.*
  - Once a tool's panes are cards, its toolbar row sits on the canvas under the tool header, lined up with it. *Built 2026-09-30.*
  - **A tool's bottom panel works like the query tab's results** (owner, 2026-09-30): the same cards (`ContentPanelCards`). Messages or Live Data grow up out of the status bar and fold back into it, the gap resizes, and a double-click on it (or View › Maximize Bottom Panel, ⌥⇧⌘Y) maximises the panel, leaving a one-line content card, the same everywhere. The status bar floats in the content card while the panel is closed; when the content is cards side by side, it rests on the canvas below them instead. *Built 2026-09-30.*
  - A pane that compares or lists two things of one object (a session's events and targets, the source and target DDL) keeps them in its one card.
- **Monitoring tools** open on dashboard tiles: the key figures as cards with sparklines above the detail. *Decided.*
- Configuration stays in the tab; read-only detail such as a job's history may use the Inspector. *Decided.*

## Results card

- **Transaction state** (round 21, PostgreSQL): the footer's status pill shows an open transaction as **Transaction** in orange with a branch icon, adding the time open after a minute, and a failed one as **Failed — roll back** in red. Clicking it opens Commit, Roll Back and Show in Messages (a failed transaction offers Roll Back only). After 15 minutes with nothing run inside an open transaction, a notification reminds. The state comes from the statements the tab runs, never an extra query. *Decided.*
- **Cancelling** (round 21, both engines): the footer's status says **Cancelling** (pulsing, no dots) until the query ends; rows already fetched stay, the count marked "partial"; the run note and Messages say "Cancelled after 3.2 s · 1 200 rows" in orange, adding "The transaction now needs ROLLBACK" when it was inside one. If the server hasn't stopped after 5 s, a banner in the results offers **Force Stop**, which closes the connection. Cancel is ⌥⌘. only. *Decided.*
- **PostgreSQL scripts** (round 21): the results show **a statement list at the left**, each row a status icon and the statement's first words ("SELECT … FROM customers"); commands are entries too, showing their tag ("INSERT 0 2"); statements that didn't run are left out. Selecting a statement shows its result and lights the statement in the editor (a stronger band than the caret's statement) until the text changes. Messages has one line per statement ("3 · UPDATE 3 · 12 ms") and says where a script stopped. A script **stops at a failed statement** unless Settings › Databases › PostgreSQL › Continue after a failed statement is on. **Run as One Transaction** (Run button menu, Query menu; off by default, per tab) wraps the script in BEGIN and COMMIT, rolling back on failure. *Decided.*

- Echo's existing AppKit grid stays, improved in place. *Decided.*
- **Cells:**
  - Numbers and dates are right-aligned with tabular digits. *Decided.*
  - Booleans show as ✓ / ✗ symbols. *Decided.*
  - Monospaced cells are available as a setting (accepted in the Echo Labs). *Decided.*
  - NULL keeps today's italic grey text; a badge was rejected. *Decided.*
  - PostgreSQL arrays show their element count (secondary text), then the elements without braces or quotes: `3  new, gift, express`. *Decided* (round 21).
  - JSON objects and arrays show a summary, `{ 4 keys }` / `[ 12 items ]`; scalars show as sent. *Decided* (round 21).
  - Hex binary (`\x…`, `0x…`) shows kind and size, `PNG image · 12 KB`. *Decided* (round 21).
  - Numbers line up on the decimal point (padding with figure spaces, no digit grouping). *Decided* (round 21).
  - These apply by value kind to every database. Copy, export and the inspector keep the server's text; the cell menu's **Copy as Shown** copies what is drawn. *Decided* (round 21).
- **Header: name + type line.** Column name in 12pt semibold with the data type underneath in grey monospace. A sort arrow appears on hover and clicking it sorts; clicking elsewhere still selects the column. *Decided.* The name-only header and the type-chip-with-keys header were rejected.
- **Selection:**
  - One rounded outline around the whole selected range, instead of today's per-row outline that shows seams, plus a stronger ring on the active cell. *Decided* (accepted in the Echo Labs).
  - Row numbers of selected rows turn accent. *Decided.*
  - Row hover: a faint rounded tint on the hovered row, and its row number turns accent. *Decided.*
- **Footer:**
  - Keep a footer under the results. *Decided.*
  - While streaming, show rows loaded against the total ("12 000 of 1.2 M rows"), using the existing row progress, with no progress line. *Decided.*
  - Show a selection summary (count, sum and average of selected numeric cells). *Decided.*
  - No Export button in the footer. *Decided.*
- **Query errors:** shown in the results card with the message, line and a "Show in editor" button, with Messages one click away. They are also recorded in notification history. When the failing tab isn't the one on screen, a toast points to it. *Decided.*
- **One footer, in the results card.** A single footer holds everything:
  - on the left, the server · database as a **glass chip** (no chevron). Clicking it opens the database switcher (a filter field and the databases) in a **system popover above the chip**, with its arrow: the popover's own Liquid Glass, theming and dismissal, rather than glass drawn in the window (owner, after round 10). "Switch database" is also in the ⌘K palette (DB3);
  - right beside it, the result views (Results, Messages, Plan…) as **one glass pill** of icons (moved from the middle after the first build);
  - on the right, **a glass pill per entry**: the status, the selection summary, rows loaded of total, and the duration (round 10).

  No strip, no divider (round 8, FT1a).

  The footer floats over the bottom of its card, lifted 4pt (round 9, FP1), with the content scrolling under a soft blur and a light tint (FB1).

  The window-wide bottom status bar goes away. While no results are shown, the editor card shows a slim version with just the picker and status. *Decided.*

## Inspector

- **A column on the canvas** (round 10, IN1), mirroring the tree on the trailing side: **one workspace card** holding the sections as **grouped boxes** (round 15): a header (icon, title, actions) over a rounded inset group of rows, label left and selectable value right, like System Settings. It has the tree's resize edge and show/hide motion. A card per section (round 10) was replaced: the stacked shadows were cut off at the column's edges. The window reads tree · cards · inspector. It replaces the native inspector column. *Decided.* A floating card (IN2), a pane inside the results card (IN3) and the restyled native column (IN4) were rejected.
- Its one job, once notifications move to the bell: the details of what you pointed at (object details, foreign-key records with related records, cell values, the JSON viewer, Agent job history, SQL keyword help). *Decided.*
- Fixes: *Decided.*
  - one section style across every panel;
  - one smooth width change instead of today's stepped jumps;
  - a row-detail mode that shows every column of the selected row.
- Single 12pt padding instead of the doubled gutter. *Decided.*
- The proposed look from the Echo Labs is accepted: grouped section cards with a header (icon, title, actions) and rows with the label left and a selectable value right. *Decided.*

## Notifications

- **Toasts:** *Decided.*
  - up to three stack and melt together;
  - hovering pauses them and repeats collapse to "×3";
  - a toast expands into a card on hover, with the full message and actions (Retry, Show details, Open tab);
  - errors stay until dismissed.

  Bottom-centre toasts were rejected.
- **History:** a bell in the toolbar with an unread badge. The history opens **in the inspector's column** (round 15, B) as one card of **compact cards grouped by day** (round 17, D): an icon, the message's first part and the time on one line, bold while new. A click fades the card open to the server, the rest of the message (selectable) and **small bordered buttons** (Open Tab or Show Server, Copy). The header is the title with a quiet count of what was new; filters and Clear All share **one ⋯ menu**. Kept across launches; nothing is greyed out. The bell and the inspector button switch the column between the two. *Decided.* The popover under the bell was rejected: too small for long messages and not Echo's surface.
- **Toasts sit** in the top-right corner of the tab's first card, below the tab bar and inset from its edges: inside the editor card on a query tab, left of the inspector. They keep one width (320pt) collapsed or expanded; their actions are quiet text links. A setting to move them (for example bottom-right) can come later. *Decided.*
- **A toast** (round 18) shows a bold title with the reason under it in two lines; hovering pauses it and shows the whole reason, selectable, with small bordered buttons (Open Tab or Show Server, Copy, Show All). A flick to the right dismisses it; × shows on hover and always on errors. Liquid Glass, dropping in from the top, three at most, 3 s. *Decided.*
- Every event is recorded in history, even when its toast is muted in settings. *Decided.*
- **A notification can carry one extra button** besides Open Tab and Copy (`NotificationAction`), shown on the toast and its history row while it still applies. *Decided* (round 21).
- **A query tab's connection dropping** (PostgreSQL; round 21) is told the moment it drops. With a transaction open: an error in Messages and an error notification, "Connection lost: Query 1 (shop) had a transaction open. The server rolled it back; nothing since BEGIN was saved.", with **Reconnect**; the footer says Disconnected and runs are refused ("Not connected: … Press Reconnect") until you reconnect, each refused run bringing the notification back. Reconnect opens a new session and says so in Messages. With nothing open: only the footer says Disconnected, the history records it without a toast, and the next run reconnects. Run again is never offered. *Decided.*

## Floating cards

- Drawn by Echo inside the window, in glass, with no arrow. They grow out of the button that opened them. *Decided.*
- **The database switcher uses the system popover**, arrow included: its glass is the system's own and it themes itself. It is the exception to arrowless cards. *Decided.* **Autocomplete no longer does** (2026-09-30, ESR5): it is a borderless panel with the card material whose corner follows Card Corners, so it can match the editor card. *Decided.*
- Close on a click outside or Esc; no pinning. *Decided.*
- Sizes: small 260, medium 320 and large 420pt wide. 12pt padding, 18pt corners, 28pt rows with 10pt corners, and the same hover and selected fills as the tree. *Leaning.*
- Keep system popovers only where an arrow is genuinely useful. System popovers are no longer the default. *Decided.*
