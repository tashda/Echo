# How to write a round in Echo Labs

A **round** is how a suggestion or a change to Echo's design gets judged. You describe it in three
lists; the lab draws the page, keeps the owner's settings, and builds the decision panel. Follow
this exactly so every round looks and works the same.

**Every choice the owner has to make carries your recommendation and the reason for it.** This is
required: a control with a `question`, an `exhibitTopic`, and every `question` must say which choice
you would ship and why. (A missing one fails an assertion in the lab.)

## When to write one

- Any visual or behavioural change the owner should judge before it goes into Echo: a new look, a
  different control, an animation, a bug fix with more than one reasonable fix.
- Not for a change with one obvious fix. Just fix it (after checking Echo Labs, see CLAUDE.md).
- If your change would differ from what Echo Labs records for that element, do not write the round
  yourself first: ask the owner with `AskUserQuestion`, recommendation first.

## The steps

1. **Look it up.** Read the area on the **Spec** page (`TABS-2.7`, …) and its rounds. Note the IDs
   you are changing; put them in your round's summary (for example "changes TABS-2.4").
2. **Create it with one command** (writes the round file, registers it in `OngoingPages`,
   `LabAreas.roundAreas` and `LabRounds.all`, and numbers it):
   ```
   python3 EchoLab/Scripts/new-round.py --slug notification-history --title "Notification history" \
       --area notifications --asked "What the owner asked, in one sentence" [--summary "..."] [--symbol bell]
   ```
   Then fill in the generated `Ongoing/<Pascal>/<Pascal>Round.swift` (a `RoundSpec`, below) and
   replace its TODOs. Put helper views next to it. Never hand-edit the registration markers
   (`ROUNDS-LIST`, `ROUNDS-DEFINITIONS`, `ROUND-INFO`, `ROUND-AREAS`).
3. **Build and look:** `EchoLab/Scripts/open-lab.sh`, or launch with
   `ECHOLAB_PAGE=<page id> .build/.../EchoLab`. Check light and dark, Corners 10 and 26.
4. **Commit** (`git commit -- <your paths>`), then tell the owner the round is ready. The owner's
   Raycast build only sees what is committed on disk.

## Revising a round (the owner sent feedback)

Keep the old options, add the new ones, and record the revision so the owner sees what to look at:

1. In the round, mark everything you add with `addedIn: N` (N is the new revision number; `Control`,
   `Exhibit`, `Choice` and `Topic` take it, and `.of(..., newChoices:)` marks a topic's new choices).
2. Record it: `python3 EchoLab/Scripts/lab-revise.py <page-id> "One-line summary" "New option: C · Spinner" "New exhibit: ..."`
   (adds revision N, sets the status back to Judging, writes a history event; `--status Accepted` etc. to override).
3. Commit, then tell the owner.

The owner then sees "Rev N" and "New since rev M" on the page's Inbox row, and a
"New since your last review" card at the top of the right-hand decision panel that lists your
changes and marks each new topic, choice and exhibit with a NEW badge. It clears when they send
feedback, accept, or press "Mark as seen".

## The RoundSpec

```swift
@MainActor
enum MyRound {
    static let spec = RoundSpec(
        controls: [
            // The knobs. A control with a `question` is part of the decision.
            .of("style", "Style", MyStyle.self, default: .quiet,
                question: "Which reads best at Default and Large? Look at the selected row.",
                recommend: .quiet,                                   // required with a question
                why: "One or two sentences: the reason you would ship it, and why the others lose."),
            .of("speed", "Speed", LabSpeed.self, default: .standard),   // playground-only: no question
        ],
        exhibits: [
            // Echo today first, then each proposal. Same sample data in all of them.
            .init(id: "today", title: "Echo today", summary: "As it is built now.",
                  isEchoToday: true, designWidth: 340, designHeight: 480) { _ in TodayView() },
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls above.",
                  designWidth: 340, designHeight: 480) { values in
                ProposalView(style: MyStyle(rawValue: values["style"]) ?? .quiet)
            },
        ],
        questions: [
            // Decisions with no control.
            .init(id: "extra", title: "Empty state", question: "Is the empty state clear?",
                  choices: [.init(id: "yes", name: "Yes"), .init(id: "no", name: "Needs changes")],
                  recommended: "yes", why: "The hint names the next step."),
        ],
        // Optional: a topic that picks between the exhibits (each gets Pick / Maybe / No).
        exhibitTopic: ("Which one?", "Which proposal do you prefer, judged against Echo today?",
                       "proposal", "Why it beats Echo today, and what it costs."),
        // Optional: one-click combinations of control settings. Mark the recommended one.
        presets: [.init(id: "rec", name: "My recommendation", values: ["style": MyStyle.quiet.rawValue], isRecommended: true)]
    )
}
```

Register it:

```swift
static let myRound = LabPage.round(
    id: "ongoing.my-round-r18", group: "Explorer tree",        // group = the area's title
    title: "My round · round 18", symbol: "rectangle.stack", status: .judging,
    summary: "One or two sentences: what changes and why. Name the Spec IDs it touches.",
    spec: MyRound.spec)
```

### What the owner sees

- An **info box** with the title, area, status and your summary (this is the only header).
- **A workbench:** controls (and presets) in a left column, the exhibits in the middle where they stay
  put and wrap to the width, the decision on the right. Each part scrolls by itself, so changing a
  control never scrolls the previews away. A round with four or fewer controls and no presets gets
  a slim control bar above the exhibits instead. No sideways scrolling ever. Specimens are drawn at
  the toolbar zoom, where 100% is the size Echo draws them: the exhibits wrap into as many columns
  as fit at that size, and one that still does not fit is scaled down with a note saying so. The
  owner can also show exhibits **one at a time** (the Layout control, or the button at the top
  right of a card) and flip between them with ⌥⌘← and ⌥⌘→. Give every exhibit its real
  `designWidth`, since that is the size it is judged at.
- **Your decision** in the right-hand panel: one card per question (every control with a
  `question`, the exhibit topic, and your `questions`). Each card shows **"I recommend: X"** with your
  reason, a ★ on that choice, radio choices, an "in preview" tag on the choice currently set in the
  controls, **Use recommendation**, **Use preview**, **Needs more options**, and a note. At the top:
  **Use all recommendations** and **Use what's selected in the preview**. At the bottom: a general
  note, then **Accept** or **Send back**.
- Each exhibit has **Pick / Maybe / No** and a note when you set `exhibitTopic`.
- Everything the owner sets (controls, picks, notes, appearance) is remembered automatically.

### Rules for exhibits

- **Self-contained:** plain SwiftUI with sample data, tokens only (`SpacingTokens`, `ColorTokens`,
  `TypographyTokens`, `LayoutTokens`), no app state, no network. Copy what you need from Echo.
- **First exhibit is Echo today** (`isEchoToday: true`), drawn from what Echo really does, not from
  memory. Every proposal is judged against it.
- **Size:** design at 340 to 700 wide and up to about 620 tall; scroll inside the exhibit if there is
  more. Pick one design size per exhibit and the lab scales it down when the window is narrow.
- **No title inside an exhibit.** The card already has the name and summary. Do not repeat it.
- **Read the controls through `values["id"]`**, never keep a second copy of them in `@State`.
  `@State` is fine for things inside one exhibit (an open row, a scroll position).
- Motion goes through `@Environment(\.echoMotion)` so Fast and Reduce Motion apply. Colours adapt to
  light, dark and Increase Contrast. Corner radii read `@Environment(\.workspaceCardCornerRadius)`.
- Only SF Symbols that exist (check on macOS 26); a missing symbol draws nothing.

### Rules for recommendations

- Recommend the option you would actually ship, not a safe middle. If it is a close call, say so in
  the `why` and still pick one.
- The `why` is the design reason (a principle, a decision already made, a measurement), in one or two
  sentences, and says what the runners-up cost. If the owner already decided it on the design board,
  recommend that and say "You decided …".
- If you truly can't judge (it depends on how it feels to use), recommend the safest option and say
  what to look for to change your mind.
- Mark one preset `isRecommended: true` so the owner can try your whole recommendation in one click.

### Rules for wording

- A control's `question`: one or two sentences. **What to do, then what to decide** ("Scroll the
  Proposal, then say whether the edge feels soft enough."). Never just "Which do you prefer?".
- A control with no `question` is a playground knob (speed, sample size); it is not asked about.
- Choice names are short and stable (`H1 · Navigator bar`). Do not rename them after the owner has
  answered; their saved picks refer to the choice ids.
- Add a choice's one-line `summary` when the name alone doesn't say what differs.

## Reading the owner's answers

`EchoLab/State/lab-state.json`, per page id:

| Key | Meaning |
|---|---|
| `status` | `New feedback`, `Judging`, `Accepted`, `In Echo`, `Decided` (exactly these spellings) |
| `picks` | topic id to the picked choice id |
| `verdicts` | `topic/exhibit` to `maybe` or `no` (a pick is in `picks`) |
| `optionNotes` | `topic/exhibit` to a note on that exhibit |
| `pickNotes` | topic id to a note on that topic |
| `needsMore` | topic ids where nothing fit: **add new options, keep the old ones** |
| `generalNote` | notes on the whole round |
| `comments` | what Accept / Send back wrote, and any feedback; a comment can carry an `element` (a Spec ID) |

Treat `needsMore` and notes as instructions. When you act on new feedback, change the round, use `lab-revise.py` (above),
which sets the status back to Judging and adds the history event.

## After the decision

Any agent can do this part. `python3 EchoLab/Scripts/lab-brief.py <page-id or 35.2> --take "<name>"` prints
the whole brief for one round (what was asked, the owner's answers, the code, the steps for its status)
and marks it taken so other agents leave it; the owner copies that command with **Copy for an agent**.
Write rounds so that brief is enough: the round's summary, the `asked` in `LabRounds.all` and the
choice names must make sense to an agent that has never seen this conversation.

1. **Accepted:** record it (`Design/decisions.md`, the rule file, `Design/plan.md`), build it into
   Echo, set the status to `In Echo` (`lab-status.py <page-id> "In Echo" "Built into Echo: …"`), and ask
   the owner to check the running app.
2. **Decided** (the owner confirmed in the running app): freeze the round into
   `Decided/Library/<Slug>/` with a `LabDecision`, and **update the area's Spec elements and As built
   page in the same change** so they say what Echo is now. Update `LabRounds.all`'s outcome.
3. Decisions are never edited; a change starts a new round.

## Do and don't

- Do check the Spec first; do name the Spec IDs your round touches.
- Do keep every round to one screen of controls and two to four exhibits.
- Don't build a free-form playground page, add a "Questions" column, or put a title in a specimen.
- Don't add horizontal `ScrollView`s to fit a wide layout: make it two exhibits instead.
- Don't move a round to Decided yourself.
- Don't let long or wrapping content decide the window's size. Wrapping `Text` with
  `.fixedSize(horizontal: false, vertical: true)` is measured at zero width when SwiftUI asks for the
  window's minimum size (one word per line), which once made the window at least 2470pt tall. Give
  any such container a `minWidth`, and keep scrolling areas inside `labScrollSizing()`.
