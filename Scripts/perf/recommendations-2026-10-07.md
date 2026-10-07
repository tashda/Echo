# Performance: what is verified, what is not, and what would need your decision (2026-10-07)

Every number below comes from a run `verify.py` marked VALID (servers saw the connections), on the optimized build with six servers
(three SQL Server, three Postgres), main-thread CPU per step (`cpuMs`), quiet machine (load about 3.5).
Debug and Release builds showed the same pattern, so it is not a Debug artefact.

## Fixed
* **Postgres sessions**: the background prefetch held one connection per database (46 per server; three servers = the default limit of 100). It now keeps 4 per server. Three servers peak at 12 sessions (was 99).

## Measured, not fixed (no single cause found; each tried idea is listed in the memory file `perf_deep_traces_2026_10_06.md`)

| Interaction | Cost (main thread) | Where it goes |
|---|---|---|
| Window resize (6 tabs open) | about 60 ms CPU a frame, 13 to 23 fps | SwiftUI layout of the whole window; the results grid is about half, the tab strip about a quarter |
| Switch to another tab | about 750 ms | SwiftUI update 40%, AppKit layout, display, toolbar and drag-region checks; no single part is more than 20% (removing the results, sidebar, editor, footer or strip one at a time leaves 600 to 740 ms) |
| Open a Postgres table structure | 2.5 s with one server open, 4.5 s with six | grouped Form layout; grows with how much is already open |
| Open a SQL Server table structure | 1.5 to 2.3 s | the same |
| First visit of a server's Databases list | 1.7 s, then 1.2 s, then 0.8 s; later visits 30 to 50 ms | one-time cost per server (first use of each view type); repeats are fast |
| Scroll a long Tables list | about 10% of frames over 25 ms | not analysed yet |

## Ideas that need a design decision from you (none tried; each changes how something works or looks)

1. **Resize: draw a snapshot while the window is being dragged, redraw when it stops.** Would cost a frame of "stale" content at the edges during the drag, and remove most of the 60 ms a frame. Recommended: yes, if you accept content that catches up at the end of a drag.
2. **Table structure as one native table instead of a grouped Form.** The Form is laid out row by row for every column; a native table builds only the visible rows. Looks like Xcode's or Finder's list view with inline editing, not the grouped sections. Recommended: only if you accept the look change; ask before building.
3. **Tab switch: keep every tab's content alive and show or hide it, instead of building it on each switch.** No visible change except more memory per open tab (editor, results rows) and a slower first open. Recommended: yes, after measuring the memory per tab.

## Dead ends (verified, do not retry)
Row views keeping their picture while resizing; `windowResizability(.contentMinSize)`; a root layout answering min/ideal/max sizes without measuring; removing the Save card's window-wide overlay (section switch 1,749 vs 1,815 ms CPU); the tab strip, header, row numbers and scroll-bar blur as the resize cost (each alone is small).
