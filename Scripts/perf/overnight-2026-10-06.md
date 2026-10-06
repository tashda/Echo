# What the overnight trace pass found (2026-10-06, Debug builds, test servers)

Time Profiler on scripted scenarios (`Scripts/perf/README.md`): ~35 scenarios against the lab's SQL Server
(251 databases, many left from lab runs) and PostgreSQL. Main-thread numbers are for Debug builds.

## Fixed (branch `perf/overnight-2026-10-06`, echo-sense `dev` 8bee329)

| What | Before | After |
|---|---|---|
| Hidden (kept-mounted) query tabs rebuilt the EchoSense catalog on every schema load, once per tab | 13% of the main thread while a big server's schemas load | 0.4% |
| EchoSense built the Built-in schema once per database, and the catalog on every context change | 58% of each rebuild | once per catalog, and only when completion needs it |
| Settings › Editor font list made in the view body | 1.5 s hang opening the pane | 0.36 s, no hang (list found once, off the main thread) |
| Tab strip joined a string of every database name on each evaluation | O(databases) on every strip update | a hash in a small child view; lists only when names change |
| AppKit rechecked the window's drag regions on every frame of a tab opening, closing or switching | ~190 ms on a tab open, 3–6% overall | the window holds still for those frames, as for the sidebar |
| Every mounted tab rebuilt its content when the tab container's body ran (closures are new each time) | all six tabs | only the tab that changed |
| A completion wrote a line to `/tmp/echo_crossdb_debug.log` (open, seek, write, close) on the main thread, in every build | a file write per completion and per new context | off unless `ECHO_CROSSDB_DEBUG` is set |
| Resizing the window: AppKit rechecked drag regions on every frame | per-frame cost for the whole resize | the window holds still during a live resize (`windowWillStartLiveResize` / `windowDidEndLiveResize`) |
| A long script (2000 to 10000 lines) in the editor: highlighting the whole text, laying out the ruler's lines, counting lines from the top a dozen times per key, EchoSense parsing the whole text per completion | one key press froze the main thread for 6 s (2000 lines) | highlighting only near the visible part (re-done on scroll), ruler lays out only what is visible, a kept line index patched on each edit, EchoSense parses a window around the caret. 2000 lines: longest stretch 5976 ms to ~1 s, 10000 lines: still ~1.3 s on the first key after a paste (Debug) |

## Measured, not fixed (needs a decision or a bigger change)

- **Sidebar or inspector slide with a query tab open**: ~800 ms of saturated main thread per toggle (about 25 fps).
  Experiments with a throwaway DEBUG switch (not committed: an `ECHO_PERF_OFF` list of parts to swap for empty space) switched off the rail, the tree, the Save
  card overlay, shadows and blurs one by one with no effect (all within 7%). Removing the main content
  halves the cost and removes the 800 ms blocks; removing the strip, dashboard, editor, results and footer together gets
  to the same level, each alone saves under 10%. Echo's own view bodies are under 6% of it: the rest is SwiftUI layout
  and CPU redraw of layers (`display_if_needed` 28%) as the width changes every frame. The honest options are to hold
  the content at its final width during the slide (a design change) or to cut the number of views in the main content.
- **A server with hundreds of databases** kept the main thread ~15% busy for minutes after connecting (serial schema
  prefetch, one structure update each, reaching the sidebar, the Connect menu (a button per database), the editors, the
  dashboard and the toolbar). Fixed afterwards, see "Schema prefetch merges" below. PostgreSQL with 4 databases idles at 0%.
- **Opening a tab or a tool tab** costs 400–700 ms of layout and display in one go; the toolbar relayouts
  (`NSToolbarView layout`) on each tab change.
- `TabBoundsPreferenceKey` (the Save card's anchors) shows up high in call trees because it is evaluated over the whole window, but
  switching the Save card off changed nothing (sidebar and slide runs): the time is the update it waits for, not the preference.
- Typing: ~24 ms per character in Debug; a third is the completion popup (a SwiftUI list laid out per keystroke).
- The Release build could not be measured: the automation is `#if DEBUG`, and macOS asks the owner for Local Network
  access for every new binary path.
- Large script, what is left (Debug, 10000 lines): `applySyntaxHighlighting` for the window, `QueryEditorState.sql`'s Equatable
  check against the 300 KB bridged string (`_stringCompareSlow`), `refreshStatements`, and the string scans in EchoSense's `performCompletions`.

## Schema prefetch merges (251 databases)

`prefetch` and `prefetch-editor` scenarios: connect to the lab SQL Server and leave it for 150 s while the
prefetch merges about 245 databases, one structure update each. Main-thread busy time over the 170 s trace (Debug):

| | No query tab | With a query tab |
|---|---|---|
| Before | 13.9 s | 3.5 s of it in `EchoSenseBridge.makeStructure` (1.2 s) |
| Rows keep their content key (`ObjectBrowserNode.renderKey`) | 5.8 s | |
| Readers of the list, a version or one database no longer read the whole structure | 3.2 s | |
| The editor converts only the database that changed (`EchoSenseBridge`) | | `makeStructure` 0.17 s, editor container 1.3 s to 0.35 s |

- A row is redrawn when what it draws changes, not when its node is a new object (`SidebarRow` bodies 1016 ms to 27 ms).
- `ConnectionSession` keeps slices that change only when they do: `databaseSummaries` (name, state, access),
  `hasDatabaseStructure`, `reportedServerVersion`, and a `DatabaseSlot` per database (`databaseInfo(named:)`) for the
  readers that open one database. The sidebar, the Connect menu, the dashboard, the tab strip and the version lines use them.
- The loading spinner on a database row reads a per-database flag (`schemaLoadFlag(forDatabase:)`), so it follows the
  database that is loading; it used to show on the one loaded before, because the in-flight set is not observed.
- What is left is the fetch itself, the merge (`mergeSingleDatabase` about 0.8 ms), the debounced cache write and the editor
  container's body, which still runs per merge.
