# Hatch

Hatch is a Mac app and a command-line tool for running design and code changes with AI agents. Tickets live as issues in a **private** GitHub repository and are mirrored into a local SQLite database. Agents take tickets through the `hatch` command. You judge options visually, in a sketch or in a small Swift "Stage" app, before anything is built.

**Status: early.** The core, the command-line tool, the app and the Stage build and pass their tests. The app has not had much use yet, and some of the design is still to be built. See `STATUS.md` for exactly what is verified.

## What it does

- **Tickets** of six types (Question, Sketch, Proposal, Tweak, Bug, Theme) and sixteen statuses, each saying whose turn it is: yours, an agent's, or Hatch's.
- **A vetting agent (Iris)** that checks a new ticket against the others and your specification, asks questions, suggests a clearer text and the right type. You accept, edit or keep your own.
- **Visual decisions.** Sketches are HTML. Proposals open a separate Stage app that shows options next to the current app, with controls and scenarios.
- **Agents that cannot trample each other.** File claims, a limit on agents at once, one git worktree per ticket, previews that combine several tickets, and a merge plan that promotes only on green CI.
- **Your tickets stay private.** Hatch creates the tickets repository private and refuses a public one.

## Requirements

macOS 26 or later and Xcode 27 for the app. The core library and the `hatch` tool build on macOS and Linux with Swift 6.1 or later (SQLite with FTS5 is needed).

## Build

```
swift build                      # core and the hatch tool
swift test
tools/smoke.sh                   # end-to-end check of the command line
cd App && swift build            # the app (macOS only)
cd Stage && swift test           # the Stage logic
```

## Connecting GitHub

Open Settings, paste a token (a classic token with the `repo` scope; the link in Settings pre-fills it) and press Connect. The token is kept in the macOS Keychain. Without one, Hatch uses `GITHUB_TOKEN` or the `gh` tool. Then, in Project settings, choose an existing repository for tickets or let Hatch create a private one.

## Documents

- `SUMMARY.md`: what Hatch is and everything decided.
- `DECISIONS.md`: every design decision with the options, the choice and the reason.
- `DESIGN.md`: the rules for how the app looks.
- `STATUS.md`: what is built and verified.
- `CLAUDE.md`: instructions for AI coding agents working on this repository.
- `examples/project.json`: a sample project file (`.hatch/project.json`).

## License

Not yet chosen.
