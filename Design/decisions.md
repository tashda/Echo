# Decision log

Newest first. Each entry says what was decided, and where the rule now lives. When a rule changes, add an entry; never rewrite an old one.

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
