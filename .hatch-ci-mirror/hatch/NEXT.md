# Hatch: how to continue

Written so a fresh session (or a person) can pick up without this conversation. Read `SUMMARY.md` first, then `STATUS.md`.

## Where things live

| What | Where |
|---|---|
| This work, until it moves | `tashda/Echo`, branch `claude/echo-labs-features-wmwnbv`, folder `Hatch/` |
| The new home of the app | `tashda/hatch` (private, created, empty at the start of the build) |
| Tickets (GitHub Issues) | `tashda/hatch-tickets` (private; has issue forms, `labels.json`, `attachments/`) |
| Echo-today views and rounds | `tashda/echo-specimens` (private, empty) |
| Extracted design system | `tashda/echo-design-system` (private, empty; do **not** extract from Echo without the owner's go) |
| The interactive design page and answers | https://claude.ai/artifact/STGbCJYZxTST7zHXzntxyN, source in `design-page/`, answers in `design-page/db/` |

## Packages in `Hatch/`

- `Package.swift`: the core, builds on Linux and macOS. Targets: `HatchCore` (SQLite store, workflow, claims, sync queue, agent queue, Proposal state), `HatchGit` (worktrees, previews, merge plans), `HatchSync` (GitHub client, sync engine), `HatchAgent` (briefs, Iris, quality gate, runners), `HatchAPI` (local API for the Stage), `HatchImport` (Echo Labs and Spec importers), `hatch` (the CLI).
- `App/`: the macOS SwiftUI app. macOS only.
- `Stage/`: `StageCore` (pure logic, tested on Linux), `StageKit` and the toast round (SwiftUI, macOS only).

## Get a Swift toolchain in a cloud container (Linux)

The container cannot reach download.swift.org. Run `Hatch/tools/install-swift-linux.sh` (unpacks the official Docker Hub image layers), then:

```
export PATH=/opt/swiftroot/usr/bin:$PATH
cd Hatch && swift test --scratch-path /tmp/build-main
```

Use a different `--scratch-path` per parallel agent. SwiftUI, AppKit and WebKit do not exist on Linux, so `App/` and the SwiftUI parts of `Stage/` can only be compiled on macOS.

## Compile the macOS code from a cloud session

`.github/workflows/hatch-ci.yml` (in the Echo repo) runs on every push to the session branch: the core on Linux, and on the `xcode-27` runner the core tests plus `swift build` of `App/` and `Stage/`. Push, then read the result with the GitHub tools (`actions_list` for jobs, `get_job_logs` with `failed_only`). Typical loop is two to three minutes. When Hatch has its own repo, copy this workflow there and check that the `xcode-27` label is available to it.

## Moving to `tashda/hatch`

When the module agents are done and CI is green: `git subtree split --prefix=Hatch -b hatch-split` in the Echo clone, push that branch to `tashda/hatch` as `main`, copy `.github/workflows/hatch-ci.yml` to the root of the new repo (drop the `Hatch/` path prefixes), and continue there. Keep `SUMMARY.md`, `DECISIONS.md` and `design-page/` with it. The Echo copy of `Hatch/` can then be deleted in a separate commit.

## What is left (see `STATUS.md` for what is done)

1. Finish and verify each core module (tests green on Linux).
2. The `hatch` CLI commands that use the other modules: `take`, `offer`, `ready`, `sync`, `serve`, `import-labs`, `spec index`, `workspace`, `preview`, `stage`.
3. Wire `StageKit` to `HatchAPI.StageClient`; launch the Stage from the app (`StageLauncher`).
4. App screens: compile on CI and fix; then the first real run on the owner's Mac.
5. Measure the round-only Stage build time on the macOS runner (decision S1/O1). If it is slow, revisit S1.
6. Echo-side changes, only with the owner's agreement: `hatch` branch trigger in `ci-light.yml`, DEBUG "Preview" banner in Echo, extraction of EchoDesignSystem into `tashda/echo-design-system` (tagged), `echo-specimens` with the "Echo today" views.
7. Import the existing Echo Labs rounds (`hatch import-labs`) once the owner has chosen whether the imported tickets should be pushed to GitHub.
8. `CLAUDE.md` for the Hatch repo (the Echo one is gitignored; commit a trimmed one in the new repo).

## Rules that must not be lost

- The app does the bookkeeping: status changes go through `HatchStore.move`, which validates, logs, indexes and queues GitHub sync. Agents use the `hatch` commands, never edit state.
- Every suggestion carries one recommendation and its reason.
- Hatch is the only writer to SQLite and GitHub; the Stage talks to Hatch over the local API.
- Cost matters: free local search before any model call, compact briefs, no full test suite before merge (CI covers it).
- iOS is out of scope. EchoSense and server testing are a separate tool.
- Do not claim code works that has not been compiled and tested; say what is unverified.
