# Deep traces: tool tabs, tables, structure, Manage Connections (2026-10-06, Debug, lab servers)

Each place was explored the way a person would (`crawl.py`: page chips, toolbar buttons, menus, sorting, selecting,
double-clicking and right-clicking rows, filter fields, sheets scrolled and closed), then replayed under the profiler
with `driver.py` (Time Profiler, a sampler of threads/CPU/connections/network twice a second, the servers' statement
counters before and after). `report.py`, `overview.py`, `hangs.py` and `hangstacks.py` read the result.

**Caveat on rendering numbers.** Runs that keep Echo from taking the focus (the default now) leave its window behind
other windows; macOS then draws less, so main-thread numbers are lower than a person would see and "hangs" are partly
App Nap. Data, thread and server numbers are not affected. Rendering-sensitive runs need the window in front (`ECHO_AUTOMATION_KEEP_FOCUS=0`).

## Fixed

| What | Before | After |
|---|---|---|
| SQL Server Activity Monitor read every query plan (XML) of the 20 most expensive queries, and of every running request, on each refresh. Nothing in Echo shows them (`SQLServerActivityOptions.includeQueryPlan` was ignored) | 90 MB in 234 s (393 KB/s) while the tab was open; 368 statements, 11.6 s server CPU; the plan query alone 5.1 s of server CPU | 5.5 MB in 201 s (28 KB/s); 248 statements, 1.7 s server CPU; that query 0.12 s (echo-sqlserver 99d896d) |

| The welcome mark's clock was asked for one more entry for ever after the pills settled, so the window redrew at the display's rate while the welcome showed (and behind Settings and Manage Connections opened over it) | 13% of the main thread, constantly, on every launch with no server connected | 0.0% (the mark is drawn once when it has settled) |
| Every SQL Server connection started its own group of 4 event-loop threads | 4 servers: 8 to 42 threads (16 NIO threads) | 8 to 31 (4 NIO threads), echo-sqlserver 1fa4cf3 |
| A hidden Activity Monitor polled at the chosen rate | seven statements every 5 s per hidden tab | once a minute; Settings › Databases › Activity Monitor › Slow down when not shown keeps the rate |
| The XEvents event picker was a dropdown of 2,513 events | 1.8 s freeze, +300 MB | a searchable list in a popover |

## Heavy load (3 or 4 servers, lab servers, Debug)

| | 4 SQL Server connections | 2 SQL Server + 2 PostgreSQL |
|---|---|---|
| Threads | 8 to 42 (31 after the shared event loops) | 9 to 35 |
| TCP connections | up to 20 | up to 16 |
| Memory | 154 to 557 MB | 164 to 410 MB |
| Server sessions opened | 6 to 27 (about five per connection) | 6 to 15 |
| Longest main-thread stretch | 1.5 s (switching a sidebar section, with the tree holding ~1,000 rows) | 1.1 s |
| Postgres catalog rows read while connecting two sessions | | 148,730 returned, 198 transactions |

## Found, not fixed

- **XEvents "New Session" event picker** (`ExtendedEventsEventControls.eventPicker`): a SwiftUI `Picker` with all 2,513 events: the main thread is
  busy 1.8 s and memory rises ~300 MB (to 576 MB) until the sheet closes. A searchable list is the fix: a design decision.
- **A hidden Activity Monitor keeps polling** (it collects but does not publish, `ActivityMonitorViewModel+Visibility`): the server keeps
  answering its seven statements every five seconds for a tab nobody sees. Pausing or slowing it when hidden costs chart history: a decision.
- **Opening a tool tab** costs 300 to 900 ms of main-thread layout in one stretch (Jobs 800 ms, Activity 230, Maintenance 360).
- **Opening a row's details** (double-click) in tables: 650 to 850 ms (Maintenance, Server Security, Error Log) when Echo is in front.
- **PostgreSQL Activity Monitor**, one run: a double-click on a row of the Operations table kept the main thread busy 5.4 s, all in
  `NSTableView.endUpdates` → removing cell views (`NSKeyValueShareableObservationInfoNSHTHash`, KVO observer removal). It did not reproduce in
  six isolated replays, so it depends on what the window held at the time (suspected: many hosting views observing the window).
- **PostgreSQL Server Properties/Maintenance/Structure** show error banners ("Loading PostgreSQL server overview failed", "BGWriter stats failed",
  "WAL stats failed") on the lab server: a functional problem, not a performance one.
- NIO event-loop threads spend 3 to 6 s of CPU in `_IntegerBitPacking` per 4 minutes of Activity Monitor: a Debug-build cost (generic, not specialised).
- Background workers spent ~6 s encoding `SchemaObjectInfo` for the local encrypted store while schemas of newly created databases arrived.

- Switching a sidebar section with several servers connected holds the main thread 0.9 to 1.5 s (`ExplorerTreeScrollState.withMutation` → every row placed again); the same shape as the single-server cost, a little worse. Another session is working on the tree.
- Opening a row's details (the inspector sliding in) and opening a tool tab are the whole-window layout cost the slide traces found: Echo's own code is 1 to 2% of it.
- `NSScrollView.echo_tileWithScrollBarBlur` shows large inclusive times in traces, but that is AppKit's own `tile()` it wraps, not the hook.

## Not covered

MySQL and SQLite tools (the automation config has no such server), and a pass with Echo's window in front for rendering and smoothness (the runs here leave it behind other windows, where macOS draws less).
