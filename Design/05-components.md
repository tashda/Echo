# Components

Each section lists the rules for one part of Echo. Items marked **Open** have a Design Lab preview; when one is settled, update it here and in `decisions.md`.

## Server rail

- Two glass pills: servers on top, tools at the bottom. See `02-layout.md`. *Decided.*
- **Identity is a two-letter monogram** from the connection name ("18", "TI"). The selected monogram takes **its server's own connection colour**; the others are secondary grey. *Decided.* Colour dots and engine badges were rejected.
- **Selection: liquid stretch.** A white disc sits under the selected monogram. When the selection moves, its leading edge races to the target and the trailing edge follows, so it stretches like a drop and settles back into a disc. *Decided.* A plain sliding disc, a glass lens, a tinted disc and a ring were rejected.
- **The server pill grows and shrinks** with a spring as servers connect and disconnect, and works on the translucent canvas. *Decided.*
- **The highlight follows scrolling:** the rail marks the server whose rows are at the top of the tree. A click holds the highlight on the clicked server while the tree glides to it. *Decided.*
- **Hover** shows the system tooltip (name and host). No custom hover cards. *Decided.*
- **Status:**
  - A connecting server's monogram breathes (opacity) until it connects. The first version was judged too subtle; the stronger values in `06-tokens.md` need a quick check in the Design Lab. *Decided*, stronger version confirmed.
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
- **One opaque card per server**, hugging its rows, with exactly the editor card's look: `textBackgroundColor`, 12pt corners, 0.5pt edge, the `workspaceCard` shadow. Cards are one gutter apart (Spacing Between Panes), with 4pt below the last row. Never glass. *Decided* (review rounds 4 and 5).
- Servers are listed in the rail's order; connecting and failed servers come last, each on its own card. *Decided.*
- **No pinned header** (round 10, P1): rows scroll to the card's rounded top edge; the rail highlights the server you're scrolled into, and a rail click glides to a server's top. The glass header, its blur and the "Pin server and database" setting are gone. *Decided.* (Replaces round 6's glass card header.)
- **Rounded end:** the tree stops one gutter above the window edge, on the editor card's bottom line. A card cut by the bottom edge ends in rounded corners with its full shadow. No fades. *Decided* (round 7).
- **No scroll bar** (round 9, SB3); the rail shows which server you're in. Settings › Sidebar › Show scroll bar brings back the small overlay scroller, inset inside the card corners. *Decided.*
- **Server header:** the server name heads its card in **bold 13pt** and scrolls with the rows (it no longer pins, round 10). Small caps and a two-line header were rejected. *Decided.*
- **Selection:** a neutral grey pill; the icon turns accent. *Decided.*
- **Counts:** plain grey tabular digits at the right; zero is hidden. *Decided.*
- **Density:** four levels (compact, small, default, large) stay as a setting. *Decided.*
- **Icon colour** stays a setting with two modes. *Decided.*
  - Monochrome mode defaults to **monochrome with accent on expanded folders**, so you see your path. A sub-setting switches to pure monochrome. *Decided.*
  - Colourful mode uses today's colours softened (lower saturation, hierarchical symbols). *Decided.*
- **Expanding:** rows slide down with a fade (native table animation), scaled by the speed setting. *Decided.*
- **Loading:** shimmer placeholder rows at the right indent, then crossfade to the real rows. *Decided.*
- **No search field in the tree.** *Decided.*
- **Empty folders** are hidden by default, with a setting to show them. *Decided.*

## Search

- **Toolbar search:** macOS 26 minimised toolbar search. A magnifier that expands into a field, with results in a glass card. *Decided.*
- **⌘K palette:** a centred glass palette. *Decided.*
- Both find objects across all connected servers, open tabs, actions ("Connect to…", "New query in…", "Switch database", "Run") and history and snippets. *Decided.*
- Find in Sidebar must move off ⇧⌘F, which clashes with Format SQL. *Decided.*

## Toolbar

- System glass, but **Echo decides the grouping** so related items always sit together. *Decided.*
- **Groups by task:** *Decided.*

  [Project] [Recents · Connections · Quick Connect] … [Run] [Format · Validate · Help · Plan] [MSSQL toggles] [Refresh · Bell · Inspector]

  Each bracket is one glass capsule.
- **Tab-specific tools** (Structure add and apply, Activity Monitor pause and refresh rate, Job Queue controls, Error log cycle, maintenance database) form one contextual capsule next to Run. It appears only on tabs that need it and melts in and out as you switch tabs. *Decided.*
- **Run** is the one tinted item: accent glass, turning red with a timer while running. *Decided.* A small chevron beside Run opens a menu of modes: Run statement at cursor, Run selection, Explain, Explain analyze. A plain click still runs as today. *Decided.*
- Editor actions (Format, Validate, Context Help, Estimated Plan) stay in the toolbar. *Decided.* No floating capsule in the editor, whether always on, while typing or on selection. *Decided.*
- Cancel must be bound to ⌘. as the Run tooltip promises. *Decided.*

## Tabs

- **Tabs should look and behave like Safari.** *Decided.*
- Keep today's strip: a grey capsule plate with a raised white active tab and the database as a subtitle. Move its hard-coded greys into tokens. *Decided.*
- **Switching tabs is instant.** Tabs are real buttons, so a click selects at once and dragging still reorders; recently used tabs keep their editors alive, keeping scroll, undo and cursor (round 9, TFIX). *Decided.*
- **Running query:** a spinner at the leading edge, and a timer replacing the subtitle. *Decided.*
- **Many tabs:** tabs shrink to a minimum width, then inactive tabs collapse to their icon while the active tab keeps its title. *Decided.*
- **New tab** grows out of the + button. *Decided.*
- **Position: on the canvas above both cards**, the way Safari's tab bar sits above the page. *Decided.*
- **One glass capsule** holding the tabs and the + as its last item; the active tab is the white pill (round 9, TB1). **Inactive tabs are faint filled capsules with near-full-strength titles** (round 11, T2), so they read as buttons. The earlier grey plate stays available as Settings › Appearance › Tab Bar › Classic, to revert to. *Decided.*

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
- **Gutter:**
  - Subtle (numbers only) or tinted (faint column with an edge) as a setting. *Decided.*
  - Both get current-line emphasis and validation markers (a red dot on failing lines). *Decided.*
  - Fixes that apply either way: one number per logical line, width that grows with digit count, and using the theme's gutter colours. *Decided.*
- **After the first run, the results grow up out of the footer** (round 10, RS2): the footer detaches from the editor card as a footer-high results card, then the seam travels up to the split line while the rows fade in. The editor keeps its scroll position, undo and focus. *Decided.*
- **Resizing:** drag the canvas gap between the cards; a grab capsule appears on hover. *Decided.* **Double-click the gap to maximise the results**: the editor shrinks to a one-line card. Double-click again to restore. It is also available as a menu item with a shortcut. *Decided.*

## Results card

- Echo's existing AppKit grid stays, improved in place. *Decided.*
- **Cells:**
  - Numbers and dates are right-aligned with tabular digits. *Decided.*
  - Booleans show as ✓ / ✗ symbols. *Decided.*
  - Monospaced cells are available as a setting (accepted in the Design Lab). *Decided.*
  - NULL keeps today's italic grey text; a badge was rejected. *Decided.*
- **Header: name + type line.** Column name in 12pt semibold with the data type underneath in grey monospace. A sort arrow appears on hover and clicking it sorts; clicking elsewhere still selects the column. *Decided.* The name-only header and the type-chip-with-keys header were rejected.
- **Selection:**
  - One rounded outline around the whole selected range, instead of today's per-row outline that shows seams, plus a stronger ring on the active cell. *Decided* (accepted in the Design Lab).
  - Row numbers of selected rows turn accent. *Decided.*
  - Row hover: a faint rounded tint on the hovered row, and its row number turns accent. *Decided.*
- **Footer:**
  - Keep a footer under the results. *Decided.*
  - While streaming, show rows loaded against the total ("12 000 of 1.2 M rows"), using the existing row progress, with no progress line. *Decided.*
  - Show a selection summary (count, sum and average of selected numeric cells). *Decided.*
  - No Export button in the footer. *Decided.*
- **Query errors:** shown in the results card with the message, line and a "Show in editor" button, with Messages one click away. They are also recorded in notification history. When the failing tab isn't the one on screen, a toast points to it. *Decided.*
- **One footer, in the results card.** A single footer holds everything:
  - on the left, the server · database as a **glass chip** (no chevron). Clicking it opens a **glass card with a filter field floating just above the chip**, which stays visible; the card rises a little as it fades in; no arrow; Esc, a click outside or another click on the chip closes it (round 9, DB1; round 10, L2 and A2). "Switch database" is also in the ⌘K palette (DB3);
  - right beside it, the result views (Results, Messages, Plan…) as **one glass pill** of icons (moved from the middle after the first build);
  - on the right, **a glass pill per entry**: the status, the selection summary, rows loaded of total, and the duration (round 10).

  No strip, no divider (round 8, FT1a).

  The footer floats over the bottom of its card, lifted 4pt (round 9, FP1), with the content scrolling under a soft blur and a light tint (FB1).

  The window-wide bottom status bar goes away. While no results are shown, the editor card shows a slim version with just the picker and status. *Decided.*

## Inspector

- **A column of cards on the canvas** (round 10, IN1), mirroring the tree on the trailing side: each section is an opaque workspace card (header with icon, title and actions; label left, selectable value right), one gutter apart, with the tree's resize edge and show/hide motion. The window reads tree · cards · inspector. It replaces the native inspector column. *Decided.* A floating card (IN2), a pane inside the results card (IN3) and the restyled native column (IN4) were rejected.
- Its one job, once notifications move to the bell: the details of what you pointed at (object details, foreign-key records with related records, cell values, the JSON viewer, Agent job history, SQL keyword help). *Decided.*
- Fixes: *Decided.*
  - one section style across every panel;
  - one smooth width change instead of today's stepped jumps;
  - a row-detail mode that shows every column of the selected row.
- Single 12pt padding instead of the doubled gutter. *Decided.*
- The proposed look from the Design Lab is accepted: grouped section cards with a header (icon, title, actions) and rows with the label left and a selectable value right. *Decided.*

## Notifications

- **Toasts:** *Decided.*
  - up to three stack and melt together;
  - hovering pauses them and repeats collapse to "×3";
  - a toast expands into a card on hover, with the full message and actions (Retry, Show details, Open tab);
  - errors stay until dismissed.

  Bottom-centre toasts were rejected.
- **History:** a bell in the toolbar with an unread badge. The history opens as a glass card below it, grouped by server, with filters, kept across launches, and each item links to its tab or server. *Decided.* The inspector notification tab goes away.
- Every event is recorded in history, even when its toast is muted in settings. *Decided.*

## Floating cards

- Drawn by Echo inside the window, in glass, with no arrow. They grow out of the button that opened them. *Decided.*
- **Autocomplete keeps today's system popover**, arrow included. It is the one exception to arrowless cards. *Decided.* No borderless panel windows are planned.
- Close on a click outside or Esc; no pinning. *Decided.*
- Sizes: small 260, medium 320 and large 420pt wide. 12pt padding, 18pt corners, 28pt rows with 10pt corners, and the same hover and selected fills as the tree. *Leaning.*
- Keep system popovers only where an arrow is genuinely useful. System popovers are no longer the default. *Decided.*
