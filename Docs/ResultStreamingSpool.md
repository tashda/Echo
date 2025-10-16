## Echo Result Streaming & Spool Architecture

### Goals
- Match or exceed DbGate’s query execution responsiveness by avoiding monolithic in‑memory result sets.
- Deliver the first 500 rows to the grid immediately, then continue streaming in the background without UI jank.
- Support continuous row-count updates in the status bar while batches arrive.
- Keep memory usage predictable (sub‑linear to row count) and enable reuse for multiple database engines.
- Expose cache controls so power users can tune storage size, retention, and location.

### High-Level Design
1. **ResultSpoolManager (new service)**
   - Lives under `Domain/Query`.
   - Owns a cache root inside the Application Cache directory (configurable via Settings).
   - Creates a `ResultSpoolHandle` for each execution, generating a unique `spoolID`.
   - Provides async APIs:
     - `append(columns:rows:encodedRows:metrics:)` — writes rows using the binary row codec (header + row payloads).
     - `finish(commandTag:totalRowCount:)` — finalizes metadata, flushes stats.
     - `load(range:)` — random access with offset/limit semantics for virtualization.
   - Tracks metadata files (`.meta.json`) recording schema, totals, completion flag, and rolling metrics for performance monitor replay.
   - Emits incremental `ResultSpoolStats` (rowCount, latestBatch, timestamps) to observers via `AsyncStream` so UI can keep counters in sync.

2. **Storage Format**
   - `<spoolID>.rows.bin` — newline-delimited binary rows (`0x00` for null, `0x01` + little-endian length + UTF-8 bytes per cell).
   - `<spoolID>.meta.json` — lightweight summary.
   - `<spoolID>.stats` — latest counter snapshot written after every append (mirrors DbGate’s `.stats` cadence).
   - Keep handle-level file handles open on a low-priority dispatch queue to minimize `FileHandle` churn.

3. **Workspace Integration**
   - `WorkspaceTab` requests a new spool before dispatching a query.
   - Database drivers call into a shared `ResultStreamSink` instead of directly appending to `streamingRows`.
   - First batch (up to `resultsInitialRowLimit`) is cached in-memory for instant paint; subsequent rows are only flushed to disk.
   - `QueryEditorState` maintains:
     - `spoolHandle` (`ResultSpoolHandle?`)
     - `displayWindow` (ring buffer for the rows currently visible).
     - `rowCountPublisher` (bridges to status bar & performance monitor).

4. **Paging / Virtualization**
   - `QueryResultsTableView` asks `QueryEditorState` for rows on demand.
   - When scrolling nears the end of the buffered window, `QueryEditorState` pulls additional slices from the spool via `load(range:)`.
   - Empty rows remain virtual until data is fetched, ensuring NSTableView row count can reflect total rows without backing arrays of equal size.

5. **Live Metrics**
   - Every append triggers `ResultSpoolHandle.recordBatch` which feeds the existing `QueryPerformanceTracker`.
   - Stats written to disk include timings, batch sizes, decode durations, and approximate memory deltas; they surface in the new Performance Monitor UI.
   - Console `[QueryPerformance] …` output now relies on the spool stats stream to report continuous row-count growth.

6. **Application Cache Settings**
   - Extend `GlobalSettings` with:
     - `resultSpoolMaxBytes`
     - `resultSpoolRetentionHours`
     - `resultSpoolLocation` (default: `~/Library/Application Support/Echo/ResultCache` on macOS).
   - Update `ApplicationCacheSettingsView` to display usage, purge controls, and allow relocating the cache (with migration support).

7. **Cross-Engine Support**
   - Introduce `ResultStreamingSink` protocol; implement in Postgres driver first.
   - MySQL, MSSQL, SQLite adopt the same sink interface once Postgres path stabilizes.
   - Non-streaming drivers (e.g., short metadata queries) can call `ResultSpoolHandle.finish` with precomputed rows for compatibility.

### Migration & Cleanup
- `ResultSpoolManager` prunes expired or oversized spools on startup and before allocating new ones.
- When a query tab closes, `WorkspaceTab` asks the manager to evict its spool (unless cached for history or quick reruns).
- Provide a “Clear Result Cache” button in Settings to delete all spools safely.

### Immediate Implementation Steps
1. Scaffold `ResultSpoolManager`, `ResultSpoolHandle`, and JSONL codecs with unit tests.
2. Wire Postgres streaming to append via the new sink, keep first `resultsInitialRowLimit` rows in memory, flush remainder to disk.
3. Update `QueryEditorState` + grid to consume from the spool while preserving existing APIs for interim compatibility.
