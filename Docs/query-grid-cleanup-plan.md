# Query → Grid Pipeline Map

## Current Flow

1. **`PostgresDatabase.streamQuery`** (`Echo/Sources/Infrastructure/Database/PostgresDatabase.swift:125-372`)
   - Declares a cursor and iterates the `fetch` loop.
   - For every row it
     - builds preview strings via `CellFormatterContext.stringValue`,
     - collects raw `ByteBuffer`s plus length metadata,
     - optionally encodes a `ResultBinaryRow`,
     - emits per-row `QueryStreamUpdate`s (metrics + payload descriptors).
2. **`ResultStreamBatchWorker`** (`Echo/Sources/Infrastructure/Database/ResultStreamBatchWorker.swift`)
   - Runs on a private `DispatchQueue`.
   - Accumulates payloads, applies flush policy (aggressive 20 ms cadence during preview), converts `.raw` rows back into `ResultBinaryRow` when flushing, and forwards a coalesced `QueryStreamUpdate` to the UI-facing progress handler.
3. **`ResultStreamIngestionService`** (`Echo/Sources/Domain/Query/ResultStreaming/ResultStreamIngestionService.swift`)
   - Bridges streaming updates onto the background spool (`ResultSpoolHandle`) while also hydrating the `ResultSpoolRowCache`.
4. **`WorkspaceTab.applyStreamUpdate`** (`Echo/Sources/Domain/Tabs/WorkspaceTab.swift:663-756`)
   - Main-actor entry point.
   - Copies preview rows into `streamingRows`, bumps counters, forwards to spool, records metrics, toggles `visibleRowLimit`, and calls `markResultDataChanged`.
5. **`WorkspaceTab` change propagation**
   - `@Published` properties (`results`, `streamingRows`, `visibleRowLimit`, `resultChangeToken`, etc.) trigger SwiftUI updates.
   - `WorkspaceTab.subscribeToContent` (lines 89-138) simply mirrors `QueryEditorState.objectWillChange` onto the tab, so every mutation schedules a main-run-loop notification.
6. **`QueryResultsSection`** (`Echo/Sources/UI/Results/QueryResultsSection.swift`)
   - Hosts eight `.onChange` observers (row count, streaming rows, columns, command tag, execution state).
   - Rebuilds `rowOrder` and resets selection on many of those notifications.
7. **`QueryResultsTableViewCoordinator`** (`Echo/Sources/UI/Results/QueryResultsTableView.swift`)
   - Reads data through `WorkspaceTab.valueForDisplay`.
   - On every reload compares `resultChangeToken`, row counts, column props, etc. to decide between full reload vs `noteNumberOfRowsChanged`.
   - Uses `tableView(_:viewFor:row:)` to pull string values synchronously; cache misses call back into `WorkspaceTab.ensureRowsMaterialized`, which can hit disk (`ResultSpoolRowCache.prefetch`).

The preview/front-buffer is redundantly stored (`streamingRows`, `results.rows`, `rowCache`, `ResultSpoolHandle.inMemoryRows`), and metrics/stat updates piggy-back on the same notification path.

## Pain Points Confirmed

- **Notification storms**: `ResultStreamBatchWorker` flushes every 20 ms during preview; each flush produces a `QueryStreamUpdate`, which triggers `WorkspaceTab.applyStreamUpdate` → `markResultDataChanged` → `resultChangeToken` bump → SwiftUI invalidates the grid. `WorkspaceTab.subscribeToContent` mirrors `objectWillChange`, so the `QueryEditorState` emits as well.
- **Triple conversion per cell** inside `PostgresDatabase` (stringify for preview, keep buffer, re-encode binary) dominates CPU during fetch (analysis report §2).
- **Row-order rebuilds** in `QueryResultsSection` allocate/sort the entire `[0..<rowCount]` array whenever `streamingRows.count`, `displayedRowCount`, `results.rows.count`, or sort criteria change.
- **Main-actor I/O**: `ResultSpoolHandle.persistMetadata` and `.persistStats` write to disk from `@MainActor` tasks; they run on every append.
- **Stats emission** at 200 Hz feeds back into `WorkspaceTab.applySpoolStats`, raising additional notifications.
- **Redundant storage**: four distinct containers hold the same rows (`streamingRows`, `results.rows`, `rowCache`, `ResultSpoolHandle.inMemoryRows`), increasing memory pressure and copy work.
- **Synchronous cache misses**: `WorkspaceTab.valueForDisplay` invokes `ensureRowsMaterialized`, then returns `nil`; the NSTableView cell shows `"NULL"` first and repaints later when the cache fills.
- **Flush policy** thrashes: preview threshold ~48 rows with 20 ms latency budget keeps small batches flowing, overwhelming the UI before copy-out even becomes a factor.

## Cleanup Goals

1. **Single-source row model** shared between preview/front buffer and spool, avoiding extra copies.
2. **Deterministic batch cadence** (e.g. ≥100 rows or ≥150 ms) so UI updates coalesce.
3. **Explicit change tokens**: only touch SwiftUI state when batch boundaries change; remove mirrored `objectWillChange`.
4. **Lazy view updates**: results section/table view should rely on `resultChangeToken` + row count, without expensive row-order rebuilds during streaming.
5. **Async background I/O**: move spool metadata/stat writes off the main actor; ensure disk access happens after UI updates.
6. **Graceful cache misses**: value lookups should return immediately available data; any async loads should update via a debounced token, not per-cell fallbacks.

This map guides the upcoming refactor steps (streamlined ingestion model, WorkspaceTab simplification, UI slimming, helper alignment).
