# Components

Each section lists the rules for one part of Echo. Items marked **Open** have a Design Lab preview; when one is settled, update it here and in `decisions.md`.

## Server rail

- Two glass pills: servers on top, tools at the bottom. See `02-layout.md`. *Decided.*
- **Identity is a two-letter monogram** from the connection name ("18", "TI"). *Decided.* Whether the selected monogram takes the accent or the server's own colour is *Open*. Colour dots and engine badges were rejected.
- **Selection:** *Leaning* toward a white disc that slides under the monograms. The liquid stretch and the glass lens stay *Open* until compared in the Design Lab. A tinted disc and a ring were rejected.
- **The highlight follows scrolling:** the rail marks the server whose rows are at the top of the tree. A click holds the highlight on the clicked server while the tree glides to it. *Decided.*
- **Hover** shows the system tooltip (name and host). No custom hover cards. *Decided.*
- **Status:**
  - A connecting server's monogram breathes (opacity) until it connects. *Decided.*
  - How to show running queries and lost connections is *Open*. Rings, comets, count badges and extra dots were rejected, so it should be very quiet or live only in the tooltip and peek card.
- **No + in the rail.** The toolbar handles connecting. *Decided.*
- Item size: medium (34pt) default, with small and large as a setting. *Decided.*
- **Clicking a server with the tree hidden:** *Open* between peek, reopening the tree, and a click / ⌘-click split. Recommendation: a plain click peeks (the tree for that server slides out over the cards; a click away or Esc slides it back), and a double-click or ⌘-click reopens the tree for good. The glance card and "switch context only" were rejected.

## Explorer tree

- It is an SSMS/pgAdmin-style tree on the canvas. *Decided.*
- **Server header = sticky header:**
  - The server name is the section header.
  - When it pins at the top it grows a breadcrumb for the database you're in ("postgres18 › employees"), over a soft fade rather than a band.
  - One element, two states. *Decided.*
  - Style is *Open*: bold 13pt, or Finder-style small caps. A two-line header was rejected.
- **Selection:** a neutral grey pill; the icon turns accent. *Decided.*
- **Counts:** plain grey tabular digits at the right; zero is hidden. *Decided.*
- **Density:** four levels (compact, small, default, large) stay as a setting. *Decided.*
- **Icon colour** stays a setting. *Decided.* How each mode looks is *Leaning*:
  - Monochrome mode: pure monochrome, or monochrome with accent on expanded folders. Both are liked; pick in the lab.
  - Colourful mode: today's colours softened (lower saturation, hierarchical symbols).
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
- The exact groups are *Open*. The starting proposal:

  [Project] [Recents · Connections · Quick Connect] … [Run] [Format · Validate · Help · Plan] [MSSQL toggles] [Refresh] [Inspector]
- **Run** is the one tinted item: accent glass, turning red with a timer while running. *Decided.* A menu of run modes (statement at cursor, selection, explain) is *Open*.
- Editor actions (Format, Validate, Context Help, Estimated Plan) stay in the toolbar. *Decided.* A floating capsule that appears only while editing is still *Open*; an always-on floating capsule was rejected.
- Cancel must be bound to ⌘. as the Run tooltip promises. *Decided.*

## Tabs

- **Tabs should look and behave like Safari.** *Decided.*
- Keep today's strip: a grey capsule plate with a raised white active tab and the database as a subtitle. Move its hard-coded greys into tokens. *Decided.*
- **Switching tabs is instant.** *Decided.*
- **Running query:** a spinner at the leading edge, and a timer replacing the subtitle. *Decided.*
- **Many tabs:** tabs shrink to a minimum width, then inactive tabs collapse to their icon while the active tab keeps its title. *Decided.*
- **New tab** grows out of the + button. *Decided.*
- Position is *Open*: on the canvas above both cards, or inside the editor card. Recommendation: on the canvas, the way Safari's tab bar sits above the page.

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
- **After the first run**, the results card rises from the bottom while the editor card shrinks. The editor keeps its scroll position, undo and focus. *Decided.*
- **Resizing:** drag the canvas gap between the cards; a grab capsule appears on hover. *Decided.* Double-click to maximise the results is *Open*.

## Results card

- Echo's existing AppKit grid stays, improved in place. *Decided.*
- **Cells:**
  - Numbers and dates are right-aligned with tabular digits. *Decided.*
  - Booleans show as ✓ / ✗ symbols. *Decided.*
  - Monospaced cells are available as a setting. *Decided.*
  - NULL keeps today's italic grey text; a badge was rejected. *Decided.*
- **Header:** name, data type and a sort arrow are liked, but the header is too bare today. It needs a deep dive in the Design Lab. *Open.*
- **Selection:**
  - One rounded outline around the whole selected range, instead of today's per-row outline that shows seams, plus a stronger ring on the active cell. *Decided.*
  - Row numbers of selected rows turn accent. *Decided.*
  - A row hover highlight only if it looks excellent. *Open.*
- **Footer:**
  - Keep a footer under the results. *Decided.*
  - While streaming, show rows loaded against the total ("12 000 of 1.2 M rows"), using the existing row progress, with no progress line. *Leaning.*
  - A selection summary (count, sum, average) is *Open*.
  - No Export button in the footer. *Decided.*
- **Query errors:** shown in the results card with the message, line and a "Show in editor" button, with Messages one click away. They are also recorded in notification history. When the failing tab isn't the one on screen, a toast points to it. *Decided.*
- **Where the connection context lives** (server › database picker, result panes, rows and time) is *Open*. Recommendation: the footer of the results card, and a slim footer on the editor card while no results are shown. The database name must look clickable.

## Inspector

- The native macOS inspector column. *Decided.*
- Fixes: *Decided.*
  - one section style across every panel;
  - one smooth width change instead of today's stepped jumps;
  - a row-detail mode that shows every column of the selected row.
- Single 12pt padding instead of the doubled gutter. *Leaning.*
- The exact look is to be shown in the Design Lab before it is built. *Open.*

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
- A borderless panel window only where a card must go past the window edge (for example autocomplete at the caret). *Leaning.*
- Close on a click outside or Esc; no pinning. *Decided.*
- Sizes: small 260, medium 320 and large 420pt wide. 12pt padding, 18pt corners, 28pt rows with 10pt corners, and the same hover and selected fills as the tree. *Leaning.*
- Keep system popovers only where an arrow is genuinely useful. System popovers are no longer the default. *Decided.*
