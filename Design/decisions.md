# Decision log

Newest first. Each entry says what was decided, and where the rule now lives. When a rule changes, add an entry; never rewrite an old one.

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

Still open, for the Design Lab:
- Card corner treatment and shadow (must match macOS window corners) and gutter width.
- Rail selection shape (disc, liquid stretch, glass lens) and the selected monogram's colour.
- Tree-hide motion (tree shrinks into rail, or card slides over).
- Clicking a server with the tree hidden (peek, reopen, or click / ⌘-click).
- Tree header style (bold or small caps) and the monochrome icon variant.
- Results header design, row hover, selection summary, loaded-of-total rows.
- Where the connection context and status bar live.
- Tab strip position (canvas or card).
- Inspector look, shown before building.
- Toolbar group layout.

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
