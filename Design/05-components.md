# Components

Each section lists the rules for one part of Echo. Items marked **Open** have a Echo Labs preview; when one is settled, update it here and in `decisions.md`.

## Server rail

- Two glass pills: servers on top, tools at the bottom. See `02-layout.md`. *Decided.*
- **Identity is a two-letter monogram** from the connection name ("18", "TI"). The selected monogram takes **its server's own connection colour**; the others are secondary grey. *Decided.* Colour dots and engine badges were rejected.
- **Telling servers apart** (round 51: TI0, NM1, CU2, WH2, WS0, *Decided*): the item stays the monogram, but a symbol or emoji the user chose for the server (connection fields `railSymbol` / `railEmoji`) replaces the letters in the same place and size. Hovering an item opens a glass bubble at once to its right (name, product line, and a line for connecting, lost or running queries) over the tree, taking no clicks; it replaces the tooltip. Right-click › Customize Appearance opens a popover at the item (colour, 12 symbols and 8 emoji, Reset to Automatic); the connection sheet shows the same controls, and the look also shows in the Manage Connections list. **SH5** (decided by the owner after the first build): a minimised card leaves the tree and its server in the trail takes a dashed ring (1.5pt, dash 3 3, the server's colour, the mark at 70%); clicking the ring restores the card and selects it; with every card minimised the tree says All Servers Are Minimized.
- **Selection: liquid stretch.** A white disc sits under the selected monogram. When the selection moves, its leading edge races to the target and the trailing edge follows, so it stretches like a drop and settles back into a disc. *Decided.* A plain sliding disc, a glass lens, a tinted disc and a ring were rejected.
- **The server pill grows and shrinks** with a spring as servers connect and disconnect, and works on the translucent canvas. *Decided.*
- **The highlight follows scrolling:** the rail marks the server whose rows are at the top of the tree. A click holds the highlight on the clicked server while the tree glides to it. *Decided.*
- **Hover** shows the system tooltip (name and host). No custom hover cards. *Decided.*
- **Status:**
  - A connecting server's monogram breathes (opacity) until it connects. The first version was judged too subtle; the stronger values in `06-tokens.md` need a quick check in the Echo Labs. *Decided*, stronger version confirmed.
  - Running queries show nothing in the rail; the tooltip lists them. *Decided.*
  - A lost connection dims the monogram to 40%, and the tooltip says why. *Decided.*
  - Rings, comets, count badges and extra dots were rejected.
- **A + ends the server pill** and opens the pill itself into the saved connections (round 52, PR4); it is never selected and the disc never moves onto it. It replaced the toolbar's Connections button. *Decided* (2026-09-29; opening rather than a menu, round 52).
- **The opened trail** (round 52: PR4, MP2, CT1, OP1, CX1, KB1, SM1): one glass shape, about 250pt wide, corners 24pt. At the top the connected servers lie in a row (the rail's own items and white disc, scrolling sideways under a soft edge) and New Connection, Manage Connections, Quick Connect and × sit at the right as icon buttons; the + glides to the ×. Under it a search field with the focus and the saved connections not already open, under their folder's name (Saved for none), each a mark, a name and host · database. Return connects the highlighted row (the first match), ↑ ↓ move it, Escape or × closes, ⇧⌘K opens it; File › Connect To keeps the system menu. Opening is the house spring; closing is `settle` after the list has faded out (0.12s), so the shrinking glass never passes under the server circles. *Decided* (owner's picks; check in Echo pending).
- **The selection disc is inset 3pt** inside its item, so a single server never looks like a pill inside a pill. *Decided* (2026-09-29).
- Item size: medium (34pt) default, with small and large as a setting. *Decided.*
- **Clicking a server with the tree hidden** (round 40): the tree opens, sliding in while it scrolls to that server; the rail's disc shows which server it is. No peek and no setting. *Decided* (replaces the peek with ⌘-click to reopen, and its setting; ⌥-click to peek and a flash on arrival were rejected).

## Server page

- Shown on the canvas while a server is active and no tab is open. No big card, like the welcome. *Decided* (review round 4).
- No icon. The server name in 26pt bold, only the version under it (the host is its tooltip); the page's top lines up with the rail. *Decided* (round 8, S1a).
- The server's tools as **Liquid Glass buttons** (`.glass`), with **New Query** first as `.glassProminent`. Tools that need a database open a menu of them. The buttons wrap when the window is narrow. *Decided.*
- The databases on one small opaque card with a filter field, 28pt rows. Recent queries and connection details are not on this page. *Decided* (round 8).
- **Arrival** (round 48, *Decided*): the page builds up, the name, the version, the tools and the databases each rising 8pt and fading in 0.06 s apart. It stays mounted under the tabs, so closing the last tab lifts the card away (0.28 s) and shows it; the server stays active.

## Welcome

- Shown on the canvas while no tab is open and no server is active. **No card**: cards are only for content. *Decided* (2026-09-29).
- Centred, 420pt wide: **Echo's mark alone** (120pt wide, the three pills, no tile and no name), then glass buttons: **Connect…** (prominent, opens the connections menu), Quick Connect, Manage. No subtitle. *Decided* (round 8, W1b; the name went in round 48).
- **Motion** (round 48, *Decided*): every time it appears the pills echo in as on echodb.dev (0.9 s, 0.12 s apart, overshoot), then the buttons and the recents rise 10pt, 0.15 s apart. When a server connects the pills echo out to the left first; the rail, the tree and the server page wait for that (`WelcomeMarkMotion`).
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
  - **The other cards (N2):** only a card whose own place or height changes animates, and the view never scrolls back by itself when the list gets shorter; the room below the last card stays until you scroll up. **Except folding a card** (2026-10-02, the owner's bug: collapsing the bottom server left the tree out of view): closing a card you are scrolled into first brings its header to its own place under the veil, and when the fold leaves the tree shorter than the view, the view glides back with the fold until the tree fills it. *Decided.*
  - **Initial load (I4 · Folders first):** a section's folders and tools show at once, spinning in their count slots; a level that is only items shows one spinner row. The dock icon stays still.
  - **Menus:** right-click an icon for its section's own menu, then Dock (show or hide each section, the type's dock, Customize Dock); right-click the empty capsule for Dock alone.
  - **Customize Dock:** order and visibility for every server of the type (Settings › Sidebar, synced) or one server (on the saved connection).
  - Servers with fewer than two sections have no dock.
- **Server header:** the server's name heads its card in bold (13pt at the default size, following the sidebar size), primary, with the product and release under it in tertiary 11pt, followed by the current section when the card has a dock ("SQL Server 2022 · Security"; the full build in the tooltip). *Decided* (rounds 16 and 19).
  - **Its look** (round 53, F5): the **title banner** is the default: the server's colour in full from the card's top through the dock, a line of small capitals (the dock's section while open, the engine while closed) over the name at 22pt semibold, a hairline edge, and the dock's icons straight on the colour with the current one filled and bold. Settings › Appearance › Server Header lets the user change the typeface, the size, the line above, the edge and the text colour (Automatic gives dark type on light colours); the five looks below stay. The collapse chevron turns a quarter on the house spring. A server's colour is one of thirty (each with a dark variant) or any colour from the colour well. *Decided* (rounds 50 and 53; replaces the wash as the default).
  - **Its colour** (round 30.1): a **wash of the server's colour** fading from the card's top edge through the dock (HD4); Settings › Appearance › Server Header also offers Plain, Bar, Glass Plate and Banner, and Server Header Color the accent or none. The dock's current icon takes the header's colour (Current Dock Icon). With the server's colour, the rail's monogram is always in it and the server's tabs and the footer's server pill carry a dot of it. The header's right-click menu sets the colour. *Decided.*
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
- **Folding a server card** (rounds 30.2 and 46): click the header; the card's edge glides (`expand`, 0.22s). Opening, the dock grows out of the header without fading and the rows wait under the section switch's veil, which fades away once the edge settles; closing, the veil covers the rows, then the card folds as the dock shrinks back. The chevron sits at the trailing edge, centred on the name and product line (CP1), shown on hover while open and always while closed; a closed card leaves the tree (round 51, SH5; it replaced the header-only closed card of round 30.2, CC0), its server staying in the rail as a dashed ring; cards open and close independently (Settings › Expand one connection at a time was removed). *Decided.*
- **Loading:** a folder shows a quiet skeleton (row-shaped placeholders at the child indent, only after a quarter second), then the rows fade in. A section's first load is Folders first (above). *Decided* (round 16; replaces the shimmer).
- **Rows that open a tab** (round 38): a tool row (Agent Jobs Overview, Security Overview, Management's tools, a sheet too) ends in a grey ↗ (arrow.up.right), always. Every SQL Server Security, the server's and each database's, starts with **Security Overview**. *Decided.*
- **No search field in the tree.** *Decided.*
- **Empty folders** (round 30.3): **Tables, Views, Functions and Procedures always show**, empty or not (EF1); the rarer folders (Synonyms, Sequences, Types…) only when they have something. An empty folder is **dimmed with no count** (EL1) and **opens to a grey “No views” row** (OE0). There is no setting (ST1). *Decided* (replaces “hidden by default, with a setting to show them”).
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
- **Refresh and the activity signal** (round 34): Refresh is in the right-hand capsule **only while the front tab can reload**, and shows **only its own reload** (spinner, then ✓ or ✗); ⌘R (View › Reload Tab) does the same. A query tab has no Refresh. Long operations show on the **bell**: a small spinner once one has run for a second, its name in the tooltip; query runs show only on Run. *Decided.*
- **Tab-specific tools** (Structure add and apply, Activity Monitor pause and refresh rate, Job Queue controls, Error log cycle, maintenance database) form one contextual capsule next to Run. It appears only on tabs that need it and melts in and out as you switch tabs. *Decided.*
- **Run** (round 15, idea 1) is a plain ▶ like its neighbours, with no tint and no chevron, in a capsule of its own so changing it moves nothing else. Running, it becomes ■ and the timer in red; a click cancels. When the query ends it shows ✓ or ! for a moment and settles back. The other modes (statement at cursor, Explain, Explain analyze) are on right-click and in the Query menu. *Decided.* The accent-glass Run with a chevron was rejected as too loud.
- **Run, round 20** (2026-09-30): at rest as above. Its tooltip says where it runs ("Run in employees on Prod SQL (⌘↩)"), or why it can't ("Type a query to run") while dimmed. It never goes into the toolbar's » overflow. ⌘↩ toggles: while a query runs it stops it. Running, the timer reads "5 s", then "1:05"; after a cancel the server hasn't acted on yet, it dims and says Stopping with a small spinner. When the query ends, the ✓ draws itself. A query of 30 s or more that ends while Echo isn't in front posts a macOS notification. *Decided.* **Round 24:** Run is one button in glass of its own that never swaps: running, ▶ is replaced by ■ in place while the glass fades to red, then the capsule grows and the time fades in (staged, no overshoot); at the end the red drains as the ✓ draws. Echo draws the red itself. *Decided.*
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
  - **How they look** (round 36.1, 2026-10-01): the title, a short hairline, then the pages at the title's size (11pt) on the tab itself, the shown one semibold on a soft pill; no grey track. The tab is exactly as wide as that (at most 62% of the strip) and the other tabs share the rest; alone, it keeps its width at the leading edge. It unfolds on the house spring, the pages fading out first. *Decided.*
  - **Every page in the tab, and how it moves** (round 49, 2026-10-02, *Decided* pending the owner's check in Echo): no More menu. Pages use shortened names and 6pt padding in the tab; the other tabs shrink to their icons (40pt) to give them room; if even that cannot fit, the pages take a row under the strip at full names. Switching tabs glides one white plate and every width on a smooth 0.3s curve; titles ride with their tab, the icons stand still on their own layer. Tab icons: one per tool, none repeated. No server dot on tabs or on the footer's pill. Advanced Objects (PostgreSQL) is four tools. Supersedes round 36.2's More and 36.1's UF1.
  - **Every tool whose sections are separate views** has pages (round 36.2: nine tools; Query Store's two views stay inside its Maintenance page); the pages that don't fit go into a More menu at the end; a tool reopens on the last page used on that server. *Decided.*

## Tab overview (open queries)

- **The tab overview is a scope of the ⌘K palette** (round 35.1, TO6, owner 2026-10-01): no full-window grid. Typing "Tab Overview" in ⌘K (a row that keeps the palette open), ⇧⌘O, the toolbar's overview button and a trackpad pinch in turn the palette to **this window's tabs** (OS0). *Decided.* Replaces the grouped card grid (O1 to O3) and its Comfortable/Compact style setting.
- **What it is for (OR1):** seeing everything that's open and what state it's in. Each row: the kind's icon, the title (semibold for the front tab), the database (or the tool's name and database), a pin if pinned, and on the right a status dot and word, live: Running 0:12 (orange), Failed (red), N rows (green), Cancelled or Not run (grey). Tabs group under their server's name with a count, servers in strip order; rows keep strip order while you type. *Decided.*
- **Keys (owner's note):** ↑↓ move, ↩ or a click goes to the tab and closes the palette; **⌫ closes the selected tab** (while nothing is typed; ⌘⌫ always), **⌘D duplicates it**, **⌥⌫ closes the others**; the palette stays open after these. ⎋ or a click outside closes it. The hint line lists them. *Decided.*
- **⌘D duplicates** a query tab (same server, database and SQL, right after it); Esc closes the overview wherever focus is (owner, 2026-10-01). *Decided.*
- **Unsaved changes** (owner, 2026-10-01): a query tab whose SQL changed since it opened or was last saved asks before closing, from anywhere, in a standard alert: Save (to a bookmark: its own, or a new one named after the tab), Save As (a .sql file; the tab takes its name), Don't Save, Cancel. Several at once (Close Others, Close All, quitting, switching project) ask once: Review Each, Close Without Saving, Cancel. File › Save ⌘S and Save As ⇧⌘S. *Decided.*

## Editor card

- Opaque card; SQL editor inside. *Decided.*
- **Fonts** (2026-09-30): JetBrains Mono, Geist Mono, Google Sans Code, Intel One Mono, Martian Mono, Fragment Mono, Atkinson Hyperlegible Mono, Cascadia Code, Monaspace and Commit Mono, all SIL OFL. **SF Mono is the default** (round 28.1); ligatures off unless turned on for a font. **13pt, lines 1.55 × the size** (20pt); Line Height is Compact (1.3), Comfortable (1.55) or Relaxed (1.75). The code starts 16pt after the line numbers, 8pt below the card's top. *Decided, round 28.1.*
- **Editor ideas** (2026-09-30), each a setting where it adds chrome: statement focus with a Run arrow in the gutter, results inline at the end of a statement, errors written on the line, more room (the rounded current-line band was removed in round 28.3), an outline edge (setting), and faint starting points in an empty tab. *Decided.*
  - The empty tab's starting points: the four tables opened last on the tab's connection and database (Data, Structure, Diagram or search), then snippets. A table inserts its first-rows query. *Built 2026-09-30.*
- **Gutter:**
  - Four styles as a setting: **Subtle** (numbers only), **Tinted column** (full height, cut by the card's corners, hairline edge), **Tinted lane** (inset 5pt from the card's edges, full height, corners concentric with the card's, numbers centred, no edge; round 28.14) and **Hairline** (only the edge; round 28.2). *Decided.* Subtle is the default; the **results' row numbers** have their own setting with the same four styles, Hairline by default (round 47).
  - Numbers are SF digits 2pt under the code in the tertiary label colour; the caret line's number is in the text colour, at the same weight (round 28.2). *Decided.*
  - Numbers stop at the last line; the tint still runs the card's full height. *Decided.*
  - Every style gets the current-line number and validation markers (a red dot on failing lines) in a column left of the numbers. *Decided.*
- **Caret line and selection (round 28.3):** nothing behind the caret's line; the system selection colour with the marks' corners (Settings › Editor › Marks › Corners); the system insertion point. *Decided.*
- **Marks on the text (round 28.5):** the word at the caret's other uses get a soft grey mark as high as the letters; typing ) flashes its (; no glass on text. *Decided.*
- **One mark language (round 28.15):** every mark on the text has round ends (Settings › Editor › Marks › Corners) and one of two strengths, soft 10% or strong 22% (Strength), coloured by meaning: grey the same word, yellow found, red wrong or removed, green added, accent where you are. Tokens: `EditorMarkTokens`. *Decided.*
- **Find and replace (rounds 28.12, 28.13):** a glass capsule with glass buttons over the top of the editor; options in a menu; a Selection button only when text over several lines is selected; Replace opens inside the capsule as it grows; each match shows its replacement in the text (old struck through on red, new on green) until Replace; Replace All is one undo. *Decided.*
- **Errors (round 28.6):** a strong red mark behind the wrong word, the same while typing and after a run; the message in a glass popover with a pointer, on hover or with the caret on the line; the live check runs when you leave the line or 2 s after typing. *Decided.*
- **After a run (round 28.7):** a glass pill with the result's symbol after each statement that ran; the statement's bracket breathes while it runs, and a line beside it fades when it ends. *Decided.*
- **Zoom (round 28.8):** a glass “100%” pill at the editor's bottom left with a menu; ⌘+ ⌘− ⌘0 and pinch; per tab. *Decided.*
- **Typing (round 28.9):** soft tabs of four, Return keeps the indent, brackets and quotes close themselves, ⌘/ toggles --, Go to Line is a glass field. *Decided.*
- **Empty tab (round 28.10):** “Start typing a query” where you type; nothing else. *Decided.*
- **Statement at the caret (round 28.4):** a thin accent bracket beside its line numbers, solid for a selected script result's statement; the Run arrow is grey and turns accent under the pointer. *Decided.*
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

Decided 2026-09-30; **revised 2026-10-02 (round MC)**, which replaces the sheet layout, CR1 and CR4 below.

- **Sign in with an identity or the connection's own login.** No folders: connection folders and identity folders retire (round MC). Own login covers the engine's methods (password, Kerberos, Windows, Entra token) in a Method menu shown only when there are several. *Decided.*
- **New Connection is a sheet in two steps.** "Which database?": four tiles with the engine symbols (`DatabaseSFSymbols`), no ports, MySQL marked Beta, Return picks the engine used last; under them a paste field with a one-line example string for the hovered engine (double-click fills the field and selects the first part; Tab moves to the next; Return reads it). Then the form. **The engine cannot change after this step**; there is no Change button. *Decided.*
- **The form:** the icon chip (opens Customize Appearance: symbol, emoji, thirty colours) and the name; Server (Engine row with the symbol and name on the right, server and port on one row split by a hairline, database); Sign in with **Password | Identity** (the identity menu starts with New Identity…); Security & limits in one disclosure with a summary that remembers whether it was open. **Inset rows**: the grouped-form row is the field, left-aligned text after a 96pt label, no bordered boxes; the focused row takes a faint accent tint. *Decided.*
- **Toolbar actions:** Cancel (✕, sheet) or Discard (pane, only after an edit) on the left; Test (stethoscope) and Save (✓, glass prominent) on the right. **Both are dimmed until they can work**; the tooltip names what's missing ("Add a server to test", "Add a user name to save", "Nothing to save") and Return on a dimmed Save focuses the first missing field. Test needs a server and a complete sign-in (a user name for a password; the password may be empty). *Decided.*
- **Test results:** the Test button spins while testing (⌘. or a click cancels; editing a field cancels too). Success: a green ✓ and the subtitle "Connected · PostgreSQL 18.0 · 38 ms" until a field changes; clicking the subtitle shows the log. Failure: a red ✕ and a popover that opens by itself with the server's message word for word, the log (resolve, connect, encryption, sign-in, reply) and Copy Log. Echo never guesses a fix. A system notification only when Echo isn't frontmost. *Decided.*
- **Editing happens in Manage Connections:** its right pane is the same form, with the engine shown in the subtitle and a locked Engine row; Save is dimmed until something changed; selecting another row with unsaved changes asks Save / Don't Save / Cancel. *Decided.*
- **Manage Connections:** three-column split view; a project switcher heads the sidebar; two-line rows (monogram or glyph, name, engine · server:port · database, sign-in, last used) beside the editor by default, a table on ⌘2; sign-in always in words; duplicate names marked with an orange dot and explained in the editor; double-click connects. *Decided.*
- **SQL Server encryption (round 22):** new connections start at Mandatory; the Encryption menu says what each mode checks (Optional encrypts without checking the certificate, Mandatory checks it, Strict is TLS first and always checks); Trust Server Certificate dims under Strict; an "Allow TLS 1.0" switch, off by default and absent under Strict, is for servers without their TLS 1.2 update. *Accepted.* (Round 22's "offers Trust this certificate" after a failed test is superseded by the log-only failure popover.)
- **PostgreSQL for companies (round 23):** Kerberos under Method; the ticket line under User name; client certificate rows with labels; Key Password only for encrypted keys; "+ Add Server" rows and Connect To; Test checks every server; after a failover the footer names the new server. *Accepted.*
- **Rules:** the port placeholder follows the engine; pasting a connection URL or string fills the form. *Decided.* ~~The default button is never silently disabled~~ and ~~the test result sits beside the buttons~~: replaced in round MC.

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
- **Panes inside a tool tab share one pane header** (round 33, JH1): the title (13pt semibold), a grey count, the pane's actions at the right, on one 36pt line (`PaneHeader`). *Decided.*
- **Agent Jobs, after checking it in Echo** (owner, 2026-10-01): Open in New Window is a toolbar item of its own at the start of the right-hand side while Agent Jobs is in front; the header uses the tree's clock in the jobs colour; a double-click opens Edit Step or Edit Schedule, and schedules can be edited. *Decided.*
- **New Step and Edit Step** (round 33.2): the command full height at the left in Echo's SQL editor with Parse (T-SQL), the settings in a sidebar at the right (Step; When it finishes: On success, On failure, retries); Edit Step adds the step's last run under the title. *Decided.*
- **Sheets are one surface** (round 33.2, SE1): no hairline between the content and the buttons; the default button is prominent while it can be pressed (`SheetLayout`). *Decided.*
- **Five families** (round 37.1, 2026-10-01): Monitor, Manage, Health (Query Store included), Properties, Canvas; the psql console follows the editor instead. **One theme for all:** one header, the same pane cards, tables and empty states. *Decided.*
- **Controls** (round 37.3): the main action a glass capsule (symbol in colour, word in grey); other actions together in one glass capsule; pickers one glass pill (symbol, value, chevron); running, the main action turns into Stop with a pulsing dot; search a glass capsule at the right; every control 28pt. *Decided.*
- **One header line** (round 37.2, UH5): the tool's tile, name and subtitle, then its controls on the same line; no second toolbar row. *Decided.*
- **Every tab's own buttons in the window toolbar** (round 37.5, replacing 45): at the right before the window's icons, as native toolbar items: its special button with its word, then each group of its other buttons (no tab symbol, the owner after checking it); the query editor keeps Run's red capsule; pickers and search stay on the header line; the glass reshapes as tabs switch; nothing for a tab without buttons. *Decided.*
- **Per family** (round 37.4): Monitor opens on tiles; Manage has a details card beside the list; Health's findings each carry a fix; Properties ends in an Apply bar with the number of changes; Canvas has a floating glass bar at the bottom. *Decided.*
- **Agent Jobs** (round 33): Jobs the full height on the left, Details over History on the right; Details' sections segmented and centred under its header; the jobs' columns Status, Name, Last Run, Next Run, a running job spinning with its elapsed time in Last Run; New Job and Start/Stop on the Jobs header, the rest in ⋯ and right-click; no stripes below the last row. *Decided.*

## Results card

- **Query time limits** (round 21): Settings › Databases › Query time limit (seconds, 0 = none, the default) applies to every connection that doesn't set its own Query Time Limit in its sheet. While a statement runs under a limit the footer's timer shows it ("0:12 / 0:30"). A stopped statement is explained in the results ("Stopped after 30 s: the statement limit for this connection.", or the server's limit by name) with Run Without Limit and a button to the setting; a notification comes when its tab or Echo isn't in front. A PostgreSQL statement waiting for a lock after 2 s makes the status say **Waiting for lock** (orange, lock icon), naming the holder on hover. *Decided.*
- **An open transaction on close** (round 21, PostgreSQL): closing a tab, switching its database, disconnecting or quitting while a transaction is open asks in an alert: "Commit before closing Query 1?", "Query 1 has a transaction on shop that is not committed. Open for 12 minutes · 3 statements.", Commit (default), Roll Back (destructive), Cancel. A failed transaction offers Roll Back and Cancel. Several tabs (quitting, disconnecting) get one alert listing them: Review…, Roll Back All, Cancel. The state is checked with the server first. *Decided.*
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
  - **One line under the header** at its true bottom, level with the row-number column's: the header paints its full height in the card's colour and draws the hairline itself, and its cells draw only their text and sort arrow (the system's cell drawing adds a second line 4pt higher); the short column dividers stay (round 41.1, HL1, VD0, and round 47). *Decided.*
  - **Row numbers** (round 47): their style is Settings › Results › Row Number Style (Subtle, Column, Lane, Hairline; Hairline by default), apart from the editor's. Right-aligned 12pt tabular digits in the tertiary colour, the gutter **fitting the digits, at least three**, with 8pt either side; the Hairline's edge starts **below the header**; a selected row's number is accent on the selection's tint; hovered rows' numbers are accent; the `#` in the corner selects every cell and shows Select All on hover. Shaded rows stop at the gutter; column names stay left-aligned. A click on a number selects its row, a drag extends and autoscrolls, a right-click opens the row menu, and the width is reserved for the known row count so it doesn't move while rows stream in. *Decided.*
- **Selection:**
  - One rounded outline around the whole selected range, instead of today's per-row outline that shows seams, plus a stronger ring on the active cell. *Decided* (accepted in the Echo Labs).
  - Row numbers of selected rows turn accent. *Decided.*
  - Row hover: a faint rounded tint on the hovered row (inset 8pt by 1pt, 6pt corners, the shape of the shaded rows), and its row number turns accent on the same tint in the gutter (round 47). *Decided.*
- **Footer:**
  - Keep a footer under the results. *Decided.*
  - While streaming, show rows loaded against the total ("12 000 of 1.2 M rows"), using the existing row progress, with no progress line. *Decided.*
  - ~~Show a selection summary (count, sum and average of selected numeric cells).~~ The selection pill shows **the count** ("89 cells"); Settings › Results › **Selection summary** can add the sum and/or the average in the locale's short form ("89 cells · Sum 34.6T · Avg 389B"; default: count only; text stays a count). Clicking the pill opens a popover with the exact figures (Count, Sum, Average, Min, Max, Median, Distinct, Empty; for text Count, Distinct, Empty), each copyable, and Copy All (round 41.2). *Decided.*
  - **Each right-hand pill opens its own popover** (round 41.5): rows (rows and columns, result set, loaded of total, memory), time (a timeline of sending, waiting and reading; started, finished, the tab's last runs), status (what happened and when, the transaction; Cancel, Commit / Roll Back, Show in Editor). **No Export, Copy All, Messages or Run Again buttons** in them (owner): exporting and copying results is the grid's right-click menu (Copy, Copy with Headers, Copy as Shown, Copy As, Save As, Select All). Server CPU and the session (SPID) wait for the drivers. *Decided.*
  - No Export button in the footer. *Decided.*
- **Query errors:** shown in the results card with the message, line and a "Show in editor" button, with Messages one click away. They are also recorded in notification history. When the failing tab isn't the one on screen, a toast points to it. *Decided.*
  - **As a banner at the top left of the card** (round 41.3, EP1): symbol, "Failed on line 7", the message, SQL Server's Msg · Level · State as quiet chips (ED0), and Show in Editor, Messages and Copy Error (EA1). Running, No rows and Cancelled use the same banner instead of a centred poster. The editor's red pill on the statement's first word stays (HL0). *Decided.*
- **Messages** (round 41.4): grouped by statement, a "Line 7 · first line of the statement" heading over what it said (ML1); an error is a red symbol and a semibold message, no fill (EE1); no strip at the top, only the counts ("1 error · 2 messages"), which filter, and a ⋯ menu with Copy All and Clear (MT1). Messages hold what the server said: Echo's own started/finished/failed lines (EM0) and the execution metrics (DM1, now in the time pill's popover) are gone. *Decided.* The symbol of a message **from the server** opens a popover, "From the server": number, level, state, line, procedure and server (SQL Server), other fields the driver passed on (PostgreSQL's SQLSTATE, detail, hint) and the text as sent, with Copy; Echo's own lines have a plain symbol. *Decided.*
- **Scroll bars over the footer** (round 27): the system's overlay bar, shown while scrolling, on the footer's top edge with its thumb as far above the footer's pills as the pills sit above the card's edge (9pt; 42pt from the edge to the thumb). The vertical bar runs down to it. The rows stay sharp at both sides: the soft edges where more columns wait (X1) were removed after round 47, as they veiled the first and last column. The bar runs as wide as the footer, over the row numbers (L2). While it shows, the blur rises past it and settles a moment after (U5), moving smoothly; the blur meets the rows along an S curve, not at a line. The footer's blur sits under the bars, in the scroll view's clip view. Everything that scrolls under the footer does the same: the grid, the editor, Messages, Extended Events. **Every horizontal scroll bar in Echo gets the same rising blur**, set once for the app (`ScrollBarBlur`). *Decided.*
- **One footer, in the results card.** A single footer holds everything:
  - on the left, the server · database as a **glass chip** (no chevron). Clicking it opens the database switcher (a filter field and the databases) in a **system popover above the chip**, with its arrow: the popover's own Liquid Glass, theming and dismissal, rather than glass drawn in the window (owner, after round 10). "Switch database" is also in the ⌘K palette (DB3);
  - right beside it, the result views (Results, Messages, Plan…) as **one glass pill** of icons (moved from the middle after the first build);
  - on the right, **a glass pill per entry**: the status, the selection summary, rows loaded of total, and the duration (round 10).

  No strip, no divider (round 8, FT1a).

  The footer floats over the bottom of its card, lifted 4pt (round 9, FP1), with the content scrolling under a soft blur and a light tint (FB1).

  The window-wide bottom status bar goes away. While no results are shown, the editor card shows a slim version with just the picker and status. *Decided.*

## Inspector

- **A column on the canvas** (round 10, IN1), mirroring the tree on the trailing side: **one workspace card** holding the sections as **grouped boxes** (round 15): a header (icon, title, actions) over a rounded inset group of rows, label left and selectable value right, like System Settings. It has the tree's resize edge and show/hide motion. A card per section (round 10) was replaced: the stacked shadows were cut off at the column's edges. The window reads tree · cards · inspector. It replaces the native inspector column. *Decided.* A floating card (IN2), a pane inside the results card (IN3) and the restyled native column (IN4) were rejected.
- **Details** shows what you pointed at (object details, foreign-key records with related records, cell values, the JSON viewer, Agent job history, SQL keyword help). **Bookmarks and History share the column** via a segmented selector (round 39, RT2); the notification bell still temporarily takes the column. *Decided; round 39 built; owner verification pending.*
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
