# Hatch: summary of everything decided

Hatch is the replacement for Echo Labs. This file says what Hatch is, what was decided, and what is being built. Every one of the 99 individual decisions, with options, recommendation and reason, is in `DECISIONS.md`. The interactive design page is at https://claude.ai/artifact/STGbCJYZxTST7zHXzntxyN (private; its source is in `design-page/`).

Nothing in this folder is a promise that code exists. See `STATUS.md` for what is actually built and verified.

## 1. Why Hatch exists

The owner uses Echo Labs to look at Swift specimens and choose between design options without building Echo. Three things were wanted:

1. **Claude inside the tool**, not in a separate window.
2. **Tickets with screenshots**, links between tickets, a system showing what is done and what is not, and every new ticket vetted by an agent against the other tickets and the specs, with questions asked before any work starts.
3. **Faster, more reliable builds.** The Rebuild button in Echo Labs often fails and the app has to be quit and started again. A whole-lab build takes 10 to 15 seconds.

It grew into a separate product used for several projects (Echo first; iOS is explicitly out of scope).

## 2. What Echo Labs is today (findings)

All under `EchoLab/` in the Echo repo. A native macOS 26 SwiftUI app, one SwiftPM executable target, 386 Swift files, about 45k lines, swift-tools 6.2.

- `Shell/` (app shell, `LabStore`, `LabBuilder`, `LabAgentHandoff`), `Areas/` (per-area specs and "As built" pages), `Blueprint/` (`RoundSpec`, `RoundPage`, decision UI), `Ongoing/` (159 files, one folder per open round, plus the `LabQE*` query editor replica), `Decided/Library/`, `Ported/`, `Test/` (54 files, EchoSense scenarios and server labs), `Spec/`, `Conformance/`, `Rounds/`.
- Replicas are hand-written SwiftUI specimens. They do not import the Echo app, only `Packages/EchoDesignSystem`.
- Build: `Scripts/open-lab.sh` (zsh, also a Raycast command). Runs `swift build`, assembles `Echo Labs.app` by hand, signs ad hoc, quits and relaunches. `LabBuilder` (cmd-shift-B) shells out to it. One monolithic module, so every edit recompiles and relinks all files. Dependencies track `branch: "dev"` (EchoSense, postgres-wire, sqlserver-nio, echo-server-lab). `LabBuilder` and `LabStore` find paths from `#filePath`, so it only works from a source checkout.
- State: `EchoLab/State/lab-state.json` (about 115 KB, keyed by page id: status, comments, picks, verdicts, optionNotes, pickNotes, needsMore, generalNote, history, revisions, takenBy). Round metadata and specs are hard-coded Swift (`LabRounds.all`, `OngoingPages`, `LabAreas`, `RoundSpec`).
- Agent scripts (Python): `lab-inbox.py`, `lab-brief.py <round> --take`, `lab-revise.py`, `lab-status.py`, `new-round.py`, `verify-round.py` (conformance: parts at 0.5pt, timeline at 0.25s, pixels), `verify-labs.py`.
- Statuses today: Judging, New feedback, Accepted, In Echo, Decided.
- `CLAUDE.md` is gitignored (`.gitignore:42`); the round guide `HOW_TO_WRITE_A_ROUND.md` is referenced but missing from the repo. Copies of the guide and `CONFORMANCE.md` are in `reference/`.
- Only `Test/` imports EchoSense and the server packages, plus three files in `Ongoing/QueryEditor` that import `EchoSense`.
- Echo CI (`.github/workflows`): "CI (Light)" runs Build and Test on every push to `dev` on a self-hosted macOS runner labelled `xcode-27`. "CI (Full)" runs on `main` and pull requests to it. There are also nightly, UI tests (`echo-ui-runner`) and `rerun-lost-runner.yml`.
- Two xcodeproj test plans matter: `UnitTests`, `LabTests`.

## 3. The product

**Name:** Hatch. (Considered and dropped: Labs, Bench, Fathom, many others.) CLI: `hatch`. Vetting agent: **Iris** (the owner's choice; I had recommended Tally).

**One universal macOS app** (SwiftUI, macOS 26), with projects. A project links repositories (with roles: App, Design system, Specimens, Tickets), branches, build and test commands, an area index and docs for agents. Echo is the first project. Hatch contains **no project code**.

**Tickets are GitHub Issues in a private repo** (`hatch-tickets`), mirrored into **SQLite** (FTS5 search, proper indexes). Type, status and project are labels (`type:proposal`, `status:your-call`, `project:echo`). Ticket number is the GitHub issue number (`#151`). Screenshots are committed to `attachments/<ticket>/` in the tickets repo. **The app does the bookkeeping in code:** a status change updates SQLite and GitHub together and records the sync in `sync_log` (queue, retry with backoff, banner when it fails). Agents never edit state or labels; they call `hatch`.

**Rules the owner set:**
- Systematically code as much as possible into the app; do not rely on an agent remembering a procedure.
- Every suggestion carries one recommendation and the reason.
- Cost matters: limit testing, do not spend tokens on things the app can do.
- iOS is out of scope. EchoSense and server testing become a separate tool, "Echo Lab Tools".
- No full build before merge; the repo's CI covers testing.

### 3.1 Ticket types (6)

| Type | For | Ends |
|---|---|---|
| **Question** | An idea or UX issue that is still words | Answered, often with new tickets |
| **Sketch** | Exploring layout/flow as 2 to 4 HTML variants, no Swift | Direction chosen; "Make it real" creates a Proposal |
| **Proposal** | A specific change with several Swift options (replaces "Round") | Accepted option goes to build |
| **Tweak** | Small change, one obvious fix | Built, verified in a Preview, merged |
| **Bug** | Something wrong; steps, expected, actual | One fix to build, or upgraded to a Proposal |
| **Theme** | Parent grouping tickets with progress | Done when children are done |

### 3.2 Statuses (16, five phases, each with a "turn" colour)

Turn colours: **You** amber, **Agent** teal, **Hatch** (automatic or queued) slate, **Finished** green, **Paused** grey.

- Intake: **Draft** (you), **Checking** (agent), **Needs answers** (you), **Ready** (Hatch, queued).
- Exploring: **Preparing** (agent), **Your call** (you), **Revising** (agent).
- Building: **Accepted** (Hatch), **Building** (agent), **To verify** (you), **Fixing** (agent).
- Landed: **Merged** (Hatch), **Done** (finished).
- Off: **Blocked** (Hatch), **Parked** (you), **Dropped** (paused).

Paths: Question: Draft, Checking, (Needs answers), Ready, Preparing, Your call, Done. Sketch adds Revising. Proposal: the whole chain. Tweak and Bug: Draft, Checking, (Needs answers), Ready, Building, To verify, (Fixing), Merged, Done. Theme: Draft, Done.

Old to new: Round to Proposal, Inbox to Desk, Judging to Your call, New feedback to Revising, In Echo to Merged, Decided to Done plus the Decisions library, Exhibit to Specimen (Swift) or Variant (Sketch), Conformance to Match check, Rebuild to Preview, Copy for an agent to `hatch take`.

### 3.3 Navigation (B, C, D)

Sidebar: project popup at top (with branch, includes "All projects"). **Work:** Desk, Tickets, Board, Previews. **Reference:** Specs, Decisions. **Machine:** Agents, Log. Footer: sync status. Toolbar: New ticket (cmd-N), Search (cmd-K), Ask panel (opt-cmd-A) on the right with the current ticket as context. Dock badge counts tickets waiting on you, plus macOS notifications.

- **Desk** (replaces Inbox): list plus a short brief pane; Return opens the ticket full width. Grouped by what is needed from you (Your call, Needs answers, To verify), then a collapsed "Waiting on agents". Rows show type, number, title, what to do and how long it takes, project chip, age. Shows all projects. Keyboard: J/K, Return, P park, and **full triage** (owner chose B): A accepts the recommendation from the list, but the confirmation sheet (H16) still appears. Empty Desk: "all clear" plus what agents are doing.
- **Tickets:** table with token filters (`type:bug status:to-verify`) and saved views; toggle to group by Theme.
- **Board:** five phase columns; cards show their exact status chip.
- **Theme page:** progress header ("3 of 7 done") and child list.

### 3.4 New ticket and the vetting agent Iris (E)

One form with a type picker, free-form body (owner chose this), project/area/theme, screenshots (drop, paste, capture the Echo window, simple annotation: box, arrow, note), links. A quick-capture shortcut makes a Draft with only a title.

- While typing: free local search (FTS) shows related tickets and Spec items. No tokens.
- On Submit, **Iris** (an agent) compares the ticket with open tickets and the Spec, then returns: **questions** (answer cards with suggested answers; structured), a **rewrite** of the ticket into the type's structure (shown as a diff with **Accept / Edit / Keep mine**; the original is always kept), and a **type check** (suggests a different type with its reason, e.g. a Bug with no steps is probably a Question; a Tweak with several reasonable fixes is a Proposal; a layout question may be a Sketch; a multi-area ticket may be a Theme). The owner decides every suggestion.
- Links: Related, Parent (Theme), Blocks, Duplicates, Supersedes. A likely duplicate offers Merge, Link or Keep separate.

### 3.5 Ticket view (F)

Header, then a **banner stating whose turn it is and what is expected, with the main action button**, then tabs: Overview, Options (or Variants), Thread, Work, History. The thread is one timeline (comments, agent messages, events) with filters. Messages from the owner have three kinds: **Note** (context), **Ask** (expects an answer, moves the turn), **Instruction** (creates a revision). History shows every event (status changes, picks, syncs, commits, token use).

### 3.6 Sketch (G)

HTML variants drawn by an agent, side by side (carousel for 4+), clearly labelled "Concept, not Swift". Feedback by **pinned comments** (click to drop a numbered pin). Ends with "Choose direction", which can mix parts ("header from A, list from C"); "Make it real" creates a Proposal or Tweak prefilled.

### 3.7 Proposal stage (H, the old Rounds page)

The most important screen. Layout: **stage first, with Controls and Decision panels that fold away** (owner's final choice). Details chosen:

- **Specimens:** side by side up to three; with 4 or more options a **filmstrip** with two shown large; Space always flips with Echo today; arrow keys switch.
- **Compare modes:** Side by side, Overlay (opacity), Flip, Wipe, and **Matrix** (every scenario by every option, cells that differ from Echo today are outlined). Default Side by side.
- **Echo today** is pinned first as a specimen with a **Match badge** (when last checked against real Echo; warns if Echo changed since).
- **Scenarios:** a strip of named states applying to all specimens, plus the Matrix. A **standard set** every Proposal must cover or mark "not applicable, because": Rest, Hover, Pressed, Focus, Disabled, Empty, Error, Long text, Many items, Loading.
- **Appearance bar always visible:** Light, Dark, Increase Contrast; Corners 10 or 26; text size; Reduce Motion; remembered per ticket.
- **Redlines overlay** draws padding, gaps and sizes. **Zoom:** 100% is Echo's real size; fit when too wide, with a label.
- **Controls panel:** decision controls first (with the recommended star), Playground folded, presets on top including a Recommended preset.
- **Decision panel:** one card per question with "Hatch recommends X because ..." and radio choices, Use recommendation, Use what's in preview, Needs more options, a note; **Pick / Maybe / No** on each option; per-option, per-question and general notes.
- **Pinned notes** on the stage store the scenario, appearance, corners and zoom they were written in.
- **Ask** button in the stage toolbar sends the question with a picture of the current view and state.
- **Revisions:** keep old options, NEW badges, a revision switcher, overlay revision 1 on 2.
- **Accept** opens a confirmation sheet (choices, repos and branches that change, tests that run, token estimate). **Send back** requires a reason (Needs more options, Change an option, Different direction) and a note.
- **Motion specimens** get a transport bar: play, scrub, frame step, 0.25x to 2x, loop, Reduce Motion preview.
- **Quality gate in code** on `hatch offer`: Echo today present, standard scenarios covered or marked not applicable, every question has a recommendation and reason, specimens render, design sizes set. Failures go back to the agent, not to the owner.
- **Mix column (H22):** a live column drawn from the owner's current answers, pinnable into extra columns (Mix 1, Mix 2) so combinations like "A's spacing with B's icon" can be compared next to the originals.
- A failed or stale specimen shows an error in its place with a report button; the others keep working.
- Keyboard map: Space flip, arrows switch specimen, 1 to 5 compare modes, L/D appearance, R redlines, S next scenario, cmd-Return Accept, cmd-shift-Return Send back, ? help.

### 3.8 Swift rounds as separate apps (S)

A Swift Proposal opens in its own **Hatch Stage** app, so Hatch is never rebuilt for a new round.

- Hatch stays stable and contains no project code. Each Proposal gets a small Stage app: prebuilt **StageKit** (compare modes, scenarios, redlines, decision panel) + prebuilt specimens kit + prebuilt design system + **the round package** (the only part compiled for a new round).
- **Hatch is the only writer** to SQLite and GitHub. The Stage sends every pick, note and verdict to Hatch over a local API; if Hatch is not running, the Stage keeps them and delivers them later.
- Round code lives in a per-project **specimens repo** (`echo-specimens`): the shared "Echo today" views plus one folder per round. Accepted rounds are archived into Decisions with a tag.
- One Stage window per Proposal; a new revision offers Reload; closes (after confirmation) when the ticket leaves Your call.
- Hatch builds the Stage and runs it headless for the quality gate **before** the ticket becomes Your call; a round that does not compile goes back to the agent.
- A crash is contained: "Stage closed unexpectedly" with Relaunch and "Send crash report to agent".
- Sketches stay inside Hatch (HTML, no compile).
- **Not yet measured:** the round-only build time. The first build step is a spike to measure it (see `NEXT.md`).

### 3.9 Building, merging, previews (I, J)

- After Accept, an agent builds in its own **git worktree** on a ticket branch (`ticket/151-toast-spacing`) in each repo it touches. Steps shown with results and a live log: Plan, Claim, Implement, Build, Tests, Match check, Ready.
- **Plan approval** only for Bugs and large changes (over a file-count threshold); accepted Proposals and Tweaks proceed.
- **Tests:** only those mapped to the area, in the ticket's workspace. **No full suite before merge.**
- **Match check** (from `CONFORMANCE.md`): parts table plus accepted | Echo | diff images.
- While an agent works the owner can stop it, take over in Terminal or Xcode, or send an instruction.
- **Preview:** the owner selects tickets; Hatch merges them into a throwaway branch, builds once (a separate copy of Echo labelled "Preview 03", with a DEBUG-only banner), conflicts name the pair and offer drop/stack/ask the agent to resolve. The owner verifies **per ticket**: Looks right or Needs work (note, screenshot), with a checklist of what to look at.
- **Merge plan** is shown first: design system first (merge, tag), then Echo bumps to the tag and merges. One failing ticket does not block the others.
- **Integration branch:** approved tickets merge into a `hatch` branch; Echo's CI (extended to run on `hatch`) checks it; Hatch reads the check results from GitHub and shows them; when green it promotes `hatch` to `dev`.

### 3.10 Agents and claims (K)

Agents screen: runs, claims, queue, token use per run, per ticket and per day. Default **3 concurrent agents** (setting). Overlapping files: the later ticket is **queued** by default, with a "Stack on #144" option (one branch, one commit per ticket). Agents are named by ticket ("Agent on #144"). A claim table records files each ticket expects to touch (from the area index and a planning step); git remains the final check at merge. Guardrails: each agent works only in its worktree; permission rules restrict writes and git commands; a pre-push hook allows only `ticket/<id>` branches; branch protection on `dev` requires a pull request.

### 3.11 Projects, Specs, sync (L, M, N)

- **Project setup** in a settings screen that writes `.hatch/project.json` into the app repo (readable by any agent).
- **Area index**: an agent drafts it (area to files and Spec IDs), the owner reviews; Re-scan available. It is the biggest token saving per ticket.
- **Specs**: Markdown in the project repo (`.hatch/spec/*.md`) indexed into SQLite FTS; **plus a per-project Spec app** launched by Hatch showing each element as a live specimen (the Echo Labs Specs section the owner loves), with a "blueprint" action that has an agent scaffold the Spec app for a new project from its area index. A ticket cannot reach Done until its Spec text and Spec app pages are updated or marked unchanged (checked in code).
- **Import** existing Echo Labs content: decided rounds become Done tickets and Decisions; open rounds become Proposals.
- **Sync rules:** Hatch owns status, GitHub owns text (edits to title, body, comments are accepted; a hand-edited status label is flagged, not obeyed). Offline: queue and retry. Search: SQLite FTS over tickets, comments, Specs, decisions (instant, offline).
- **Specs, Decisions, Log screens:** Specs by area with IDs and linked tickets; Decisions are read-only frozen results linked to tickets, picks and Spec items changed; Log shows every Hatch action with its GitHub sync result, filter failed, retry from the row.

## 4. The `hatch` command (what agents use)

Each command validates the move, writes SQLite and GitHub, records the sync, and answers with the exact next step.

`hatch next` (which ticket to take) · `hatch take #151` (claim, create workspace, return the brief) · `hatch ask #151 "..."` (structured question to the owner) · `hatch offer #151` (hand in options or variants; Hatch builds the Stage, runs the quality gate, then Your call) · `hatch plan #144 --files ...` (declare files; claim granted or who holds them) · `hatch ready #144` (work done; Hatch runs build, tests and match check and reports) · `hatch note #144 "..."` (thread note, posted to GitHub too).

## 5. Data model (SQLite)

`ticket` (id, gh_number, project_id, type, status, turn, title, body, parent_id, priority, updated_at; indexes (project_id,status), (turn,updated_at), gh_number unique, parent_id) · `ticket_fts` (FTS5) · `event` (append-only history, index (ticket_id,at)) · `sync_log` (id, ticket_id, op, direction, state, attempt, error, at; index (state,at)) · `ticket_link` · option / verdict / note (Proposal state) · repo / workspace / claim (index on (path_glob,state)) · preview / preview_ticket · stage_session · agent_run · spec_item / decision.

## 6. Repositories

| Repo | Purpose |
|---|---|
| `hatch` | The app, the `hatch` CLI, StageKit, core. **Needs to be created by the owner** (see below). |
| `hatch-tickets` (private) | Issues and `attachments/` |
| `echo-specimens` | Echo-today views and one folder per round |
| `echo-design-system` | EchoDesignSystem extracted from Echo, tagged |
| Echo (`tashda/echo`) | The app. Changes later: a `hatch` trigger in `ci-light.yml`, a DEBUG "Preview" banner, EchoDesignSystem moves out |

## 7. Where the owner chose differently from my recommendation

- **C5**: full triage from the Desk list (I recommended navigate/open/park/drop only). Kept, with the confirmation sheet.
- **E7**: one free-form body (I recommended required fields per type). Works because Iris rewrites it into the type's structure.
- **V1**: the vetting agent is called **Iris** (I recommended Tally).

## 8. Build order (decided, O1 = spike first)

0. Tidy: fix the Echo Labs rebuild flake; commit a trimmed `CLAUDE.md` and the round guide; split Echo Lab Tools out of Echo Labs.
1. **Stage spike:** the toast round (round 18) as a Stage app with the specimens kit; measure the round-only build time.
2. Foundation: extract EchoDesignSystem to its own tagged repo; SQLite, GitHub sync with `sync_log`, projects and repos, the `hatch` command.
3. Desk, Tickets, Board, composer with Iris's check and rewrite, ticket view.
4. Sketch.
5. Full Stage: compare modes, scenarios, redlines, Mix column, decision panel, quality gate, revisions.
6. Workspaces, claims, Preview, merge plan, `hatch` branch and CI watching.
7. Specs text and Spec app; import of old Echo Labs rounds.

## 9. Open items and risks

- Round-only Stage build time is unmeasured (assumption behind S1).
- Repos must be created by the owner: this cloud session cannot create GitHub repositories (access is limited to `tashda/echo`).
- Building and viewing the SwiftUI app needs macOS. The cloud container is Linux. Core logic is built and tested here; SwiftUI code can only be compile-checked on the owner's Mac or through CI on the `xcode-27` self-hosted runner.
- The Echo CI change (`hatch` branch trigger), the Preview banner in Echo and the EchoDesignSystem extraction touch the Echo repo and need the owner's agreement when we get there.
- Names of the four new repos should be confirmed by the owner.
