# Hatch: build status

Updated whenever work lands. "Verified" means it was compiled and its tests were run. This file is the source of truth for what exists.

## Environment facts

- Cloud sessions are Ubuntu 24.04 x86_64 with **no macOS and no SwiftUI/AppKit**. Swift 6.1.3 for Linux is installed with `tools/install-swift-linux.sh` (Docker Hub image layers; download.swift.org is blocked).
- A cloud session can only reach repositories attached to it. This repository is `tashda/hatch`; the others are `tashda/hatch-tickets`, `tashda/echo-specimens`, `tashda/echo-design-system` (all private, the last two still empty) and `tashda/Echo`.
- **GitHub Actions does not start any job in `tashda/hatch`** (checked 2026-10-03: even a one-line `echo` job fails in about two seconds with no runner assigned, no steps and no log). It looks like an account or repository Actions/billing setting. The same workflows run fine in `tashda/Echo` (runner label `xcode-27`). Until the setting is fixed, `tools/mirror-to-echo.sh` copies the tree to `.hatch-ci-mirror/` on the Echo working branch, where `Hatch CI (mirror)` compiles the core, the app and the Stage on macOS. This is temporary; delete `.hatch-ci-mirror/` and `.github/workflows/hatch-ci-mirror.yml` from Echo afterwards.

## Built and verified on Linux (`swift test`, 2026-10-03)

| Module | What | Tests |
|---|---|---|
| HatchCore | SQLite + FTS5, schema v1, 16-status workflow with who-may-move-what, ticket store, events, notes, questions, links, search, sync queue with coalescing and backoff, file claims (queue, stack, wake), agent queue and slots, Proposal state, decisions, agent runs | 32 |
| HatchSync | `IssueTracker`, GitHub REST client (fake transport), in-memory tracker, push/pull engine, status-drift handling, CI status, attachments | 38 |
| HatchGit | worktrees per ticket, pre-push guard, claim drift, preview builder (names the conflicting pair), merge plan and executor, promote only on green CI | 37 |
| HatchAPI | local HTTP API for the Stage with token auth, client with an outbox so picks are never lost, idempotency keys | 42 |
| HatchImport | Echo Labs importer (all 46 real pages import), Spec markdown format, Spec exporter (233 items from the real Swift specs), project bootstrap (25 suggested Echo areas) | 56 |
| HatchAgent | Proposal manifest and quality gate, brief builder, Iris contract and applier, Claude CLI runner, offer and vetting services | 129 |
| `hatch` CLI | `tools/smoke.sh` passes: init, ticket, next, take, plan (claim queue), sync (dry run), status, search, Echo Labs import | smoke |

Total: 334 package tests plus the CLI smoke test, all green.

## Written, not yet compiled (macOS only)

- `App/`: the SwiftUI app (shell, Desk, Tickets, Board, ticket view, composer with Iris review, Previews, Agents, Project, Specs, Decisions, Log, Ask panel, command palette, Sketch board, Stage launcher, settings). Compile errors are expected on the first macOS build.
- `Stage/`: `StageCore` logic (tests run on Linux), `StageKit` SwiftUI and the toast spike round (macOS only).

## Not started or open

- Wiring `StageKit` to `HatchAPI.StageClient` and launching the Stage from the app end to end.
- Measuring the round-only Stage build time (decision S1/O1).
- Echo-side changes that need the owner's agreement: a `hatch` trigger in `ci-light.yml`, a DEBUG "Preview" banner, extracting EchoDesignSystem into `tashda/echo-design-system`, the "Echo today" views into `tashda/echo-specimens`, splitting Echo Lab Tools, the Echo Labs rebuild-flake fix.
- Importing the real Echo Labs rounds into the owner's database and choosing whether to push them to GitHub (`hatch import-labs --enqueue`).
