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

## Not covered yet

Settings pages (clicks and sheets), the SQLite and MySQL tools, and the heavy-load scenarios (3 to 4 servers connecting at once).
