# Handover: finishing the canvas-and-cards redesign

Paste this to the next agent, or point it at this file. Written 2026-09-29 after Phase 1 and two rounds of fixes from the owner's builds (the latest adds the empty-window rules and the welcome).

---

You are taking over the redesign of **Echo**, a macOS SwiftUI database client (repo `tashda/echo`), into a native macOS 26/27 Liquid Glass app. Work on branch **`claude/ecstatic-fermi-u1jxr6`** (based on `dev`). Don't open a pull request unless the owner asks.

## What has been agreed

Everything is written down in `Design/`. Treat it as the contract:

- `Design/README.md`: index, rule status markers, how to change the design.
- `Design/01-principles.md` → `06-tokens.md`: the rules. **Every design question is Decided.** Only two details are Leaning: the floating-card sizes and the tree resize handle; settle them while building and log them.
- `Design/decisions.md`: why each rule exists, newest first. The two latest entries (2026-09-29) changed these rules:
  - the rail's server pill ends with a **+** (replacing the toolbar Connections button);
  - the selection disc is **inset 3pt**;
  - the tree only shows when it has content (a server or a tool page);
  - with no tab and no server, a **welcome sits on the canvas without a card**;
  - a sidebar button sits at the leading end of the toolbar;
  - each server's tree sits on its own **opaque card** (review round 4, never glass);
  - the server page sits on the canvas in the welcome's style, with Liquid Glass tool buttons.
- `Design/plan.md`: the build plan, Phases 0–10 with task IDs, a status per task, and "Notes from building it" under finished phases. **This is your to-do list.**
- `Design/current-state.md`: a map of the code from before the build (Phase 1 has since changed the window and rail; the plan notes say how).
- The Design Lab (`Echo/Sources/Features/DesignLab/`, debug builds, **Help › Design Lab**) is the visual reference for every task marked 👁. Its rail doesn't show the + yet.

The direction in one line: **canvas and cards**, inspired by Outlook. There's a glass rail of two pills at the leading edge (servers with a + on top, tools at the bottom). The tree sits straight on the grey window canvas. The editor and results are opaque cards with 12pt corners, a floating shadow and a 6pt gutter (setting 4/6/8). The tab strip sits on the canvas above the cards, and the inspector is the native one. Glass goes only on controls, never on content.

## Where things stand

- **Phase 0 (foundations) and Phase 1 (the shell) are built.** F1–F4 and S1–S7 are ☑. Most carry "👁 pending", meaning the owner still has to look at them on a Mac.
- Key code you will build on:
  - `EchoMotion` in `Shared/DesignSystem/MotionToken.swift`, read with `@Environment(\.echoMotion)`.
  - `Color.adaptive` in `AdaptiveColor.swift`.
  - Tokens in `LayoutToken.swift` (`Workspace`, `Rail`, `FloatingSurface`), `ColorToken.swift` (`Workspace`), and `ShadowToken.swift` (`workspaceCard`, `railSelection`).
  - The new settings in `Features/Preferences/Domain/GlobalSettings+Workspace.swift`, bound with `projectStore.globalSettingBinding(\.key)`.
  - The window, `AppHost/Views/Navigation/WorkspaceShell.swift` (rail column, tree with resize handle, peek, content).
  - The rail, `ObjectBrowser/Views/Components/ServerRail.swift`.
  - `workspaceCard()` in `Shared/DesignSystem/Components/WorkspaceCard.swift`.
- **Nothing on this branch has been compiled by an agent.** This container has no Swift toolchain, so the owner builds on their Mac and reports errors or sends screenshots. Write Swift carefully (Swift 6, default actor isolation nonisolated, macOS 26 target), re-read every edit for compile errors, and say plainly what you could not verify.
- Four unit tests already fail on `dev` (autocomplete ×2, login editor, object browser cache). They're unrelated; don't chase them.

## What to do

1. **First, ask the owner to build the latest commit** and fix whatever they report before starting new work. Open items from the last round:
   - Does the rail's + menu open cleanly, without a stray button border?
   - Is a 6pt gap below the toolbar enough?
   - Does the peek card's rounded top sit right over the tree?
   - Does the welcome look right: glass Connect… menu button, recents card, relative times?
   - Do ⌃⌘S and the toolbar sidebar button work, and are they disabled with nothing connected?
   - Do the server cards in the tree draw correctly while scrolling and expanding folders, and does the lifted card follow the rail?
   - Does the server page look like the welcome, with glass tool buttons that wrap on a narrow window?
2. Then work through `plan.md` **top to bottom**: Phase 2 (tree T1–T6), 3 (tabs B1–B5), 4 (cards E1–E4), 5 (grid R1–R6), 6 (toolbar and search K1–K5), 7 (notifications and floating cards N1–N5), 8 (tab overview O1–O3), 9 (inspector I1–I3), 10 (finish X1–X3). For each task:
   - Read the rules it names first.
   - Build it using tokens only. Add a token before using any new number or colour.
   - Mark it ◐ while working. When done, mark it ☑ plus the commit hash, adding "👁 pending" if it needs the owner's eye.
   - Add "Notes from building it" under the phase: anything the next person needs, and any gap left.
   - Commit with a clear message and push.
3. Known carry-overs, already noted in the plan:
   - The peek should also list running queries; do this with the floating-card primitive, N1.
   - Move the tab strip's active and hover gradients to adaptive tokens in B1.
   - E1 splits the single content card into editor and results cards.
   - Add the + to the Design Lab rail.
   - The translucent canvas isn't a setting yet; `ColorTokens.Workspace.canvas` is the switch point.
4. **"100% done"** means every row in `plan.md` is ☑, every 👁 has been checked by the owner, and X3 (walking every rule in `01`–`06` against the app) is ticked with no unlogged exceptions.

## How to work with the owner

- **Never decide a design question yourself.** If a rule doesn't cover something, or the owner's feedback conflicts with a rule, ask. Use an Echo Design Review web page (an artifact with the `db` capability, like the earlier rounds in `Design/reviews.md`) or the AskUserQuestion tool with clear options, previews and a recommended first option. Then update the rule and add a `decisions.md` entry before building.
- **Don't run or poll CI.** The owner asked not to spend tokens on CI during the redesign.
- **Keep `plan.md` current after every task.** The owner explicitly asked for this.
- Commits end with the attribution lines the session gives you. Never put a model name in commits or code.
- Performance rule from the handover notes: keep frequently changing state out of `ObjectBrowserSidebarView`'s body; every body run rebuilds the tree.
