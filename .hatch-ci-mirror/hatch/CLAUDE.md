# Hatch

Hatch is a macOS app and a `hatch` command-line tool for tickets, AI agents and visual design decisions. It replaces Echo Labs. Read `DESIGN.md` before changing any UI. Read `SUMMARY.md` for what it is, `DECISIONS.md` for every decision (99, with the reason), `STATUS.md` for what is built and verified, `NEXT.md` for how to continue.

## Layout

- `Package.swift`: the core (builds on Linux and macOS, no external packages, language mode 5): `HatchCore`, `HatchGit`, `HatchSync`, `HatchAgent`, `HatchAPI`, `HatchImport`, and the `hatch` executable.
- `App/`: the SwiftUI app (macOS only). `Stage/`: `StageCore` (logic, tested on Linux), `StageKit` and the round packages (macOS only).
- `design-page/`: source of the interactive design page and the saved answers.
- `examples/`: sample `.hatch/project.json`. `tools/`: Swift install script for Linux containers, CLI smoke test, temporary CI mirror.

## Rules that must hold in every change

1. **The app does the bookkeeping.** A status changes only through `HatchStore.move`, which validates against `Workflow`, logs an event, indexes the ticket and queues the GitHub sync in one transaction. Never write SQL for state outside `HatchCore`, and never let an agent edit labels, state or the database. Agents use the `hatch` commands.
2. **Hatch is the only writer** to SQLite and GitHub. The Stage app talks to Hatch over the local API (`HatchAPI`).
3. **Every suggestion carries one recommendation and its reason**; the quality gate (`ProposalValidator`) enforces it for Proposals.
4. **Cost matters.** Free local search (FTS) before any model call, compact briefs, no full test suite before merge (CI covers it).
5. iOS is out of scope. EchoSense and server testing are a separate tool.
6. Do not claim code works that has not been compiled and tested. SwiftUI code cannot be compiled on Linux; say what is unverified.

## Working on it

- Linux container: `tools/install-swift-linux.sh`, then `export PATH=/opt/swiftroot/usr/bin:$PATH` and `swift test --scratch-path /tmp/build-x` (use a separate scratch path per parallel worker). `tools/smoke.sh` checks the CLI end to end.
- macOS code (`App/`, `Stage/`): push and read the CI result. GitHub Actions currently does not start jobs in this repository (see `STATUS.md`); `tools/mirror-to-echo.sh` is the temporary workaround.
- Public API gets short comments that say why. Plain, direct style. Tests are XCTest. Commit often with focused messages.
- Names: app Hatch, vetting agent Iris, ticket types Question / Sketch / Proposal / Tweak / Bug / Theme, 16 statuses in 5 phases (see `Workflow.swift`).
