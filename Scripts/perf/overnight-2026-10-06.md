# What the overnight trace pass found (2026-10-06, Debug builds, test servers)

Time Profiler on scripted scenarios (`Scripts/perf/README.md`): ~35 scenarios against the lab's SQL Server
(251 databases, many left from lab runs) and PostgreSQL. Main-thread numbers are for Debug builds.

## Fixed (branch `perf/overnight-2026-10-06`, echo-sense `dev` 65e1612)

| What | Before | After |
|---|---|---|
| Hidden (kept-mounted) query tabs rebuilt the EchoSense catalog on every schema load, once per tab | 13% of the main thread while a big server's schemas load | 0.4% |
| EchoSense built the Built-in schema once per database, and the catalog on every context change | 58% of each rebuild | once per catalog, and only when completion needs it |
| Settings › Editor font list made in the view body | 1.5 s hang opening the pane | 0.36 s, no hang (list found once, off the main thread) |
| Tab strip joined a string of every database name on each evaluation | O(databases) on every strip update | a hash in a small child view; lists only when names change |
| AppKit rechecked the window's drag regions on every frame of a tab opening, closing or switching | ~190 ms on a tab open, 3–6% overall | the window holds still for those frames, as for the sidebar |
| Every mounted tab rebuilt its content when the tab container's body ran (closures are new each time) | all six tabs | only the tab that changed |

## Measured, not fixed (needs a decision or a bigger change)

- **Sidebar or inspector slide with a query tab open**: ~800 ms of saturated main thread per toggle (about 25 fps).
  Experiments with a throwaway DEBUG switch (not committed: an `ECHO_PERF_OFF` list of parts to swap for empty space) switched off the rail, the tree, the Save
  card overlay, shadows and blurs one by one with no effect (all within 7%). Removing the main content
  halves the cost and removes the 800 ms blocks; removing the strip, dashboard, editor, results and footer together gets
  to the same level, each alone saves under 10%. Echo's own view bodies are under 6% of it: the rest is SwiftUI layout
  and CPU redraw of layers (`display_if_needed` 28%) as the width changes every frame. The honest options are to hold
  the content at its final width during the slide (a design change) or to cut the number of views in the main content.
- **A server with hundreds of databases** keeps the main thread ~15% busy for minutes after connecting (serial schema
  prefetch, one structure update each, reaching the sidebar, the Connect menu (a button per database), the editors, the
  dashboard and the toolbar). Only the catalog part is fixed. PostgreSQL with 4 databases idles at 0%.
- **Opening a tab or a tool tab** costs 400–700 ms of layout and display in one go; the toolbar relayouts
  (`NSToolbarView layout`) on each tab change.
- Typing: ~24 ms per character in Debug; a third is the completion popup (a SwiftUI list laid out per keystroke).
- `TabBoundsPreferenceKey` (the Save card's anchors) is evaluated over the whole window: 2–5% of main-thread time; the
  card could read tab frames from a registry instead.
- The Release build could not be measured: the automation is `#if DEBUG`, and macOS asks the owner for Local Network
  access for every new binary path.
