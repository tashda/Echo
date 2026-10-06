# Tracing Echo (DEBUG builds)

Scripted scenarios against the test servers, traced with Instruments' Time Profiler, then read with
small scripts. Written for the overnight performance pass of 2026-10-06.

1. `python3 Scripts/perf/gen.py` writes the scenario scripts (`Scripts/perf/scenarios/*.json`): sidebar
   sections, tabs, query typing, 100k-row queries, tool tabs, Settings, Manage Connections, table
   structure and more. A script is the automation steps in `Echo/Sources/Features/AppHost/Automation/`.
2. `ECHO_APP=<Echo.app> Scripts/perf/run.sh <name> Scripts/perf/scenarios/<name>.json <seconds>` runs one
   under the profiler (set `ECHO_AUTOMATION_CONFIG` to your server list, see `AutomationConfiguration.swift`).
3. Read it:
   - `SUMMARY=1 python3 parse.py <trace>`: per step, main-thread busy time, the longest unbroken stretch
     and how many stretches are over 50 ms; hangs. Without `SUMMARY`, the heaviest functions per step.
   - `score.py <trace>...`: the same totals by kind of step, to compare two builds.
   - `hunt.py <trace>`: the Echo functions with the most inclusive time (wrappers left out).
   - `tree.py <trace> t0 t1` (`APPONLY=1` to keep only Echo and layout frames) and `incl.py <trace> t0 t1`:
     call tree and inclusive frames for a stretch of seconds into the trace.
   - `agg.py <trace> <pattern>...` (`STEP=<regex>` to limit to steps): inclusive share of frames.

Caveats found on the way:
- `ECHO_AUTOMATION_ISOLATED=1` keeps a run away from the Keychain, the account and the stored data.
- Launch through `open` and attach by pid. `xctrace --launch` is ambiguous when other Echo.app copies share
  the bundle id, and the SwiftUI template crashes xctrace when it saves.
- Don't change the bundle id and don't run a build from a new path while measuring: macOS asks for Local
  Network access per binary, and only the owner can answer.
- Release builds have no automation (it is `#if DEBUG`).
