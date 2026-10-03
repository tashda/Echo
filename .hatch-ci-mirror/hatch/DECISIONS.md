# Hatch: complete decision record

Generated from the design page (https://claude.ai/artifact/STGbCJYZxTST7zHXzntxyN) and the answers saved on it. **99 decisions, all answered.** For each decision: the question, every option, the one you chose (✔), the one I recommended (★), and my reason.

Where your choice differs from my recommendation it is marked **DIFFERENT FROM RECOMMENDATION**.

## Where you chose differently from my recommendation

- **C5 How much can you do from the Desk list itself?**: you chose **Full triage**; I recommended **Navigate, open, park, drop**.
- **E7 Should each type have a template?**: you chose **One free-form body**; I recommended **Required fields per type**.
- **V1 What is the vetting agent called?**: you chose **Iris**; I recommended **Tally**.

## Index of choices

| ID | Decision | Chosen |
|---|---|---|
| A1 | Which ticket types should exist? | Six types |
| A2 | What should the old "Round" be called? | Proposal |
| A3 | How should tickets be numbered? | Plain #151 |
| A4 | How many statuses? | 16 statuses in 5 phases |
| A5 | How should "whose turn" be shown? | Colour plus text |
| A6 | How do type, status and project appear on GitHub? | Labels |
| B1 | How is the sidebar organized? | Work and reference groups |
| B2 | How do you switch project? | Popup at the top of the sidebar |
| B3 | What does the Desk show when you have several projects? | Everything, with a project chip |
| B4 | Where does "Ask Hatch" live? | Side panel |
| B5 | How is sync with GitHub shown? | Footer status plus Log |
| B6 | How do you get notified? | Dock badge plus macOS notification |
| C1 | What is the Desk layout? | List and brief, open takes the window |
| C2 | How is the Desk grouped? | By what is needed from you |
| C3 | What does each Desk row show? | Type, number, title, what to do and how long it takes |
| C4 | What about tickets waiting on agents? | Collapsed group at the bottom |
| C5 | How much can you do from the Desk list itself? | Full triage (differs) |
| C6 | What does an empty Desk show? | All clear plus what agents are doing |
| D1 | What does the Tickets screen look like? | Table with filters and saved views |
| D2 | How are the Board columns defined? | Five phases |
| D3 | How do filters and saved views work? | Token filter bar plus saved views |
| D4 | What does a Theme (parent ticket) look like? | Progress header and child list |
| E1 | How do you create a ticket? | One form with a check panel |
| E2 | When does the check run? | Local search while typing, agent check on Submit |
| E3 | How do screenshots get into a ticket? | Drop or paste, capture the Echo window, simple annotation |
| E4 | How do the agent's questions reach you? | Answer cards in the ticket |
| E5 | Which kinds of links exist between tickets? | Five kinds |
| E6 | What happens when the check finds a likely duplicate? | Offer Merge, Link, or Keep separate |
| E7 | Should each type have a template? | One free-form body (differs) |
| E8 | The vetting agent rewrites your ticket: how does the rewrite reach you? | Suggested rewrite with a diff: Accept, Edit or Keep mine |
| E9 | The agent checks whether the ticket type is right | Suggest a type change with the reason, you decide |
| V1 | What is the vetting agent called? | Iris (differs) |
| F1 | How is a ticket page structured? | Header and banner, then tabs |
| F2 | How prominent is "whose turn it is"? | A banner with the main action |
| F3 | How is the thread shown? | One timeline with filters |
| F4 | How do you talk to the agent from a ticket? | Three message kinds: Note, Ask, Instruction |
| F5 | How much history do you see? | Every event in History |
| G1 | How are variants arranged? | Side by side, with a one-at-a-time mode |
| G2 | How do you give feedback on a variant? | Pinned comments |
| G3 | How are Sketches drawn? | HTML styled like macOS, clearly marked as a concept |
| G4 | How does a Sketch end? | Choose a direction, mix parts, Make it real |
| H1 | Stage layout: where do controls, specimens and the decision sit? | Stage first, panels fold away |
| H2 | How do you switch between specimens? | Adaptive: side by side up to three, filmstrip beyond |
| H3 | Which compare modes exist? | All four plus Matrix |
| H4 | How is Echo today shown? | A pinned specimen with a Match badge |
| H5 | How are scenarios (states) tested? | Strip plus Matrix view |
| H6 | Which scenarios must every Proposal include? | A standard set, extendable |
| H7 | Appearance controls: what and where? | Always-visible bar: appearance, contrast, corners, text size, motion |
| H8 | Measurements: how do you see exact spacing and sizes? | Redlines overlay |
| H9 | Zoom and sizing | 100% means Echo's real size, fit when too wide, with a label |
| H10 | Controls panel: how are the knobs organized? | Decision controls first, Playground folded, presets on top |
| H11 | The decision panel | Keep the card per question, add "Use recommendation" and "Use what's in preview" |
| H12 | Verdicts on options | Pick, Maybe, No on each option, plus a note |
| H13 | Notes on the stage | Pin a note on the specimen |
| H14 | Asking a question while judging | Ask button in the stage toolbar |
| H15 | Revisions after you send it back | Keep old options, mark new ones, revision switcher, compare revisions |
| H16 | What happens when you press Accept? | A confirmation sheet |
| H17 | What happens when you press Send back? | Choose a reason, then write what to change |
| H18 | How are animated specimens judged? | Transport bar |
| H19 | A quality gate before a Proposal reaches you | Hatch validates the Proposal in code on hatch offer |
| H20 | Keyboard on the stage | Full map |
| H21 | When a specimen fails or is out of date | Show the failure on the specimen |
| H22 | Testing several options at the same time | Add a live Mix column, pinnable into extra columns |
| S1 | Where do Swift Proposals run? | A separate Stage app per Proposal |
| S2 | What does the Stage app contain? | The whole stage, from a shared StageKit, plus the round |
| S3 | How do Hatch and the Stage app talk to each other? | Local API, Hatch is the only writer |
| S4 | Where does the code of a Swift round live? | A per-project specimens repo |
| S5 | How do the Stage windows behave? | One Stage window per Proposal |
| S6 | When is the Stage built and checked? | Before it reaches you |
| S7 | What if a Stage crashes, or Hatch is not running? | Contain it |
| I1 | How is a build shown? | Steps with results and a live log |
| I2 | When must you approve the agent's plan? | Only for Bugs and large changes |
| I3 | Which tests run? | Tests mapped to the area; the repo's CI runs the full suite |
| I4 | How is the Match check shown? | Parts table plus image comparison |
| I5 | What can you do while an agent is working? | Stop, take over in Terminal or Xcode, send an instruction |
| I6 | Where do merged tickets go, and what tests them? | A hatch integration branch checked by CI, then promoted |
| J1 | How do tickets get into a Preview? | You select them |
| J2 | What happens when two tickets conflict? | Tell you which pair, offer drop, stack or ask the agent to resolve |
| J3 | How do you verify? | Per ticket: Looks right or Needs work |
| J4 | How does the Preview app run? | A separate copy, labelled Preview 03 |
| J5 | How are approved tickets merged? | Merge plan shown first, one button |
| J6 | What if one ticket in a Preview fails? | Others still merge |
| K1 | Is there an Agents screen? | Yes: runs, claims, queue and cost |
| K2 | How many agents run at once? | Default 3, configurable |
| K3 | What happens when two tickets want the same files? | Queue by default, offer Stack |
| K4 | How are agents named? | By ticket: "Agent on #144" |
| K5 | Do you see token use? | Per run, per ticket and per day |
| L1 | How is a project set up? | Settings screen that writes .hatch/project.json into the app repo |
| L2 | How is the area index created? | An agent drafts it, you review |
| L3 | Where do Specs live? | Markdown files in the project repo |
| L4 | What happens to the existing Echo Labs rounds? | Import: decided rounds become Done and Decisions, open ones become Proposals |
| L5 | How does the Specs section work in Hatch? | Text in Hatch, plus a per-project Spec app launched by Hatch |
| M1 | Who wins when GitHub and Hatch disagree? | Hatch owns status, GitHub owns text |
| M2 | What happens offline? | Queue and retry with backoff |
| M3 | Where are screenshots stored? | Committed to the private tickets repo |
| M4 | How does search work? | SQLite full-text over tickets, comments, Specs and decisions |
| N1 | What do Specs and Decisions look like? | Specs by area with IDs and linked tickets, Decisions as read-only frozen results |
| N2 | What does the Log show? | Every Hatch action with its GitHub sync result |
| O1 | What do we build first? | Spike the Stage first, then the foundation |


---

## A. Names, ticket types and statuses

### A1. Which ticket types should exist?

The types decide which screens, statuses and agent instructions exist. Fewer types are simpler to learn, more types make each one sharper.

- ✔ ★ **A · Six types**: Question, Sketch, Proposal, Tweak, Bug, Theme.
- **B · Three types**: Discuss, Design, Fix. Sketch and Proposal become two modes of Design.
- **C · One type plus labels**: Every ticket is the same, labels say what it is.

**Chosen:** Six types

**My recommendation and reason:** Six types. Each of the six has a different path and a different main screen. A Sketch needs no Swift and a Proposal does, and you asked for exactly that split. With three types the difference hides inside a mode, and with one type the agent has to remember the rules for each label.

### A2. What should the old "Round" be called?

The Swift-specimen comparison with options is the heart of Echo Labs today.

- ✔ ★ **A · Proposal**: "Proposal #151, 3 options".
- **B · Trial**: Suggests testing options out.
- **C · Study**: A design word, less clear for newcomers.
- **D · Keep "Round"**: No migration of vocabulary.

**Chosen:** Proposal

**My recommendation and reason:** Proposal. It reads naturally in a sentence and states what the ticket is for: something proposed that you judge. "Round" says nothing to a new agent or a new project, and "Trial" implies the change is being tested rather than chosen.

### A3. How should tickets be numbered?

GitHub gives every issue a number in its repo.

- ✔ ★ **A · Plain #151**: The GitHub issue number, project shown as a chip.
- **B · Project prefix**: ECHO-151, with the project name in the ID.
- **C · Own counter**: Hatch numbers tickets itself.

**Chosen:** Plain #151

**My recommendation and reason:** Plain #151. The number is the one thing you cannot change on GitHub, so using it directly means no mapping table and no way for the two to disagree. One shared tickets repo keeps numbers unique across projects. A prefix is easy to add later as display only.

### A4. How many statuses?

Every status must say whose turn it is. The Desk sorts on that.

- ✔ ★ **A · 16 statuses in 5 phases**: Draft to Done, grouped as Intake, Exploring, Building, Landed, Off.
- **B · 8 coarse statuses**: Merges agent and your turns into the same status.
- **C · Different statuses per type**: Each type has its own list.

**Chosen:** 16 statuses in 5 phases

**My recommendation and reason:** 16 statuses in 5 phases. The Desk needs to know who has the ball, so your turn and the agent's turn cannot share a status. The 5 phases keep the Board readable even though there are 15 statuses. Per-type lists would mean learning six vocabularies.

### A5. How should "whose turn" be shown?

This appears on rows, cards, banners and the Board.

- ✔ ★ **A · Colour plus text**: Amber for you, teal for agents, slate for Hatch, green finished, grey paused. The status name always sits beside the colour.
- **B · Avatars**: A small avatar for the person or agent holding the ticket.
- **C · Position only**: No colour, only the grouping on the Desk.

**Chosen:** Colour plus text

**My recommendation and reason:** Colour plus text. Colour is read at a glance in a long list, and the text beside it keeps it usable without relying on colour alone. Avatars suit teams, and this is a one-person tool with agents.

### A6. How do type, status and project appear on GitHub?

Tickets are GitHub issues in a private repo.

- ✔ ★ **A · Labels**: type:proposal, status:your-call, project:echo.
- **B · GitHub Projects fields**: Custom fields on a project board.
- **C · Issue types**: Native issue types, where the repo supports them.

**Chosen:** Labels

**My recommendation and reason:** Labels. Labels work in every repo, in the list view, on the phone and through the plain API. Projects fields need a separate API and extra sync. Native issue types depend on the repo being owned by an organization, so I would use them only for the type, later, if you move.


---

## B. Navigation and shell

### B1. How is the sidebar organized?

The sidebar is the map of the whole app.

- ✔ ★ **A · Work and reference groups**: Desk, Tickets, Board, Previews on top. Specs, Decisions on a second group. Agents, Log at the bottom.
- **B · Few sections, views inside**: Desk and Tickets only. Board and Previews become views inside Tickets.
- **C · Top tabs**: A tab bar instead of a sidebar.

**Chosen:** Work and reference groups

**My recommendation and reason:** Work and reference groups. You move between Desk, Board and Previews several times a day, so they should be one click away. The groups separate things you act on from things you look up. It also matches Echo's own sidebar conventions on macOS.

### B2. How do you switch project?

Echo is the first project, others will follow.

- ✔ ★ **A · Popup at the top of the sidebar**: Shows project and branch. Includes "All projects".
- **B · One window per project**: Each project opens its own window.
- **C · Projects as sidebar sections**: Every project expands in the same sidebar.

**Chosen:** Popup at the top of the sidebar

**My recommendation and reason:** Popup at the top of the sidebar. It keeps one window and one Desk across projects, which matters because "your turn" does not care which project a ticket belongs to. Separate windows split your attention, and expanding every project in the sidebar gets long quickly.

### B3. What does the Desk show when you have several projects?

- ✔ ★ **A · Everything, with a project chip**: All projects at once, filter available.
- **B · Current project only**: Switch project to see another Desk.

**Chosen:** Everything, with a project chip

**My recommendation and reason:** Everything, with a project chip. Your turn is your turn. If a Question in another project waits for you, hiding it behind a switch is how tickets get forgotten. A filter handles the day you want to focus.

### B4. Where does "Ask Hatch" live?

A way to ask Claude about the current ticket or screen without leaving it.

- ✔ ★ **A · Side panel**: Opens on the right, keeps the current ticket as context. Toggle with a shortcut.
- **B · Separate window**: A floating chat window.
- **C · Only inside tickets**: Via the thread of each ticket.

**Chosen:** Side panel

**My recommendation and reason:** Side panel. The panel lets you look at the specimen and talk about it at the same time. A separate window loses the context, and thread-only misses the questions that are not about one ticket. Everything asked in the panel about a ticket is also saved to its thread.

### B5. How is sync with GitHub shown?

Sync is automatic, but you should know when it is not working.

- ✔ ★ **A · Footer status plus Log**: A small status at the bottom of the sidebar, details in Log, a banner only when something fails.
- **B · Toolbar badge**: A sync icon in the toolbar.
- **C · Hidden**: Only visible in the Log.

**Chosen:** Footer status plus Log

**My recommendation and reason:** Footer status plus Log. It is always visible without taking toolbar space. A failure becomes a banner you cannot miss, which matters because a failed sync means GitHub and Hatch disagree.

### B6. How do you get notified?

Agents work while you are elsewhere.

- ✔ ★ **A · Dock badge plus macOS notification**: Badge counts your-turn tickets. Notification when something new needs you, grouped.
- **B · Badge only**: No notifications.
- **C · Email or push**: Through GitHub.

**Chosen:** Dock badge plus macOS notification

**My recommendation and reason:** Dock badge plus macOS notification. The badge is the quiet default and the notification is what pulls you back when a Proposal is ready. GitHub notifications can still be turned on separately for the phone.


---

## C. Desk (replaces the Inbox)

### C1. What is the Desk layout?

The old Inbox used a list and a reading pane. For judging work the reading pane was too small to be useful.

- ✔ ★ **A · List and brief, open takes the window**: The right pane is a short brief. Return opens the ticket full width.
- **B · Classic three panes**: Sidebar, list and a large reading pane that shows the work itself.
- **C · One card at a time**: Triage mode: a single large card, next and previous.

**Chosen:** List and brief, open takes the window

**My recommendation and reason:** List and brief, open takes the window. The Desk exists to decide what to do next. The actual judging needs the full window anyway, so squeezing it into a pane serves neither job. The brief pane still tells you how big the task is before you open it.

### C2. How is the Desk grouped?

- ✔ ★ **A · By what is needed from you**: Your call, Needs answers, To verify, then Waiting on agents.
- **B · By project**: One group per project.
- **C · By age**: Oldest first, one list.

**Chosen:** By what is needed from you

**My recommendation and reason:** By what is needed from you. The groups map to different kinds of effort: judge, answer, verify. You can do them in batches. Age is shown on each row, so you can still spot what has waited longest.

### C3. What does each Desk row show?

- ✔ ★ **A · Type, number, title, what to do and how long it takes**: Plus project chip and age. For Proposals, the recommendation.
- **B · Title only**: Minimal.
- **C · With thumbnails**: A small preview of the options in the row.

**Chosen:** Type, number, title, what to do and how long it takes

**My recommendation and reason:** Type, number, title, what to do and how long it takes. "What to do and about how long" is what lets you choose between ten items. Thumbnails look nice but add cost on every row and are too small to judge, so they belong in the brief pane.

### C4. What about tickets waiting on agents?

- ✔ ★ **A · Collapsed group at the bottom**: With a count, expand when you want.
- **B · Only on the Board**: Not on the Desk at all.
- **C · Always expanded**: Everything visible.

**Chosen:** Collapsed group at the bottom

**My recommendation and reason:** Collapsed group at the bottom. You want to know that work is happening, but it should never push your own tickets out of sight. Collapsed with a count gives you both.

### C5. How much can you do from the Desk list itself?

Keyboard triage is fast, but a decision made without seeing the options is risky.

- ★ **A · Navigate, open, park, drop**: Decisions are made inside the ticket.
- ✔ **B · Full triage**: Accept the recommendation straight from the list.
- **C · Mouse only**: No keyboard shortcuts.

**Chosen:** Full triage  **(DIFFERENT FROM RECOMMENDATION)**

**My recommendation and reason:** Navigate, open, park, drop. Accepting triggers an agent run that costs tokens and time, so it should follow a look at the options. Parking and dropping are safe to do from the list.

### C6. What does an empty Desk show?

- ✔ ★ **A · All clear plus what agents are doing**: A calm message and a summary of running work.
- **B · Plain empty state**: Just "nothing to do".
- **C · Suggestions**: Prompts to create tickets or revisit parked ones.

**Chosen:** All clear plus what agents are doing

**My recommendation and reason:** All clear plus what agents are doing. Knowing that three agents are building is what makes "nothing for you" reassuring instead of suspicious. Parked tickets are linked at the bottom without pushing them.


---

## D. Tickets, Board and Themes

### D1. What does the Tickets screen look like?

- ✔ ★ **A · Table with filters and saved views**: Columns for type, status, turn, project, age. Toggle to group by Theme.
- **B · Outline by Theme**: Themes expand into their children.
- **C · Cards**: A grid of ticket cards.

**Chosen:** Table with filters and saved views

**My recommendation and reason:** Table with filters and saved views. You will search and sort a lot, and a table is the clearest way to do that. The Theme grouping is one toggle away when you want the outline view.

### D2. How are the Board columns defined?

- ✔ ★ **A · Five phases**: Intake, Exploring, Building, Landed, Off. Cards show their exact status chip.
- **B · One column per status**: Sixteen columns.
- **C · Swimlanes by project**: Rows per project, columns by phase.

**Chosen:** Five phases

**My recommendation and reason:** Five phases. Sixteen columns do not fit on a window, and the phases tell the story of where work is. The chip on each card keeps the detail. Swimlanes can be added once there are several active projects.

### D3. How do filters and saved views work?

- ✔ ★ **A · Token filter bar plus saved views**: type:bug status:to-verify, saved by name in the sidebar.
- **B · Sidebar filters**: Checkboxes in a panel.
- **C · Search only**: Type words.

**Chosen:** Token filter bar plus saved views

**My recommendation and reason:** Token filter bar plus saved views. Token filters are fast with the keyboard and map directly to the SQLite columns and GitHub labels. Saved views give you "Everything waiting on agents" in one click.

### D4. What does a Theme (parent ticket) look like?

- ✔ ★ **A · Progress header and child list**: "3 of 7 done", children grouped by phase.
- **B · Tree**: A nested tree on the Tickets screen only.

**Chosen:** Progress header and child list

**My recommendation and reason:** Progress header and child list. A Theme is a place to see how a body of work is going, so progress comes first. The tree is still available as the grouped view of the Tickets table.


---

## E. New ticket, the check, the vetting agent (Iris)

### E1. How do you create a ticket?

- ✔ ★ **A · One form with a check panel**: Type, title, description, screenshots, links. Hatch check on the right. A quick-capture shortcut makes a Draft with only a title.
- **B · Step-by-step wizard**: One question per step.
- **C · Quick capture only**: A title and a screenshot, Hatch asks the rest.

**Chosen:** One form with a check panel

**My recommendation and reason:** One form with a check panel. You can see everything at once and fill what you know. The quick-capture shortcut covers the case where you only have time for a line and a screenshot, and Hatch then asks for the rest.

### E2. When does the check run?

Free local search can run while you type. The agent check costs tokens.

- ✔ ★ **A · Local search while typing, agent check on Submit**: Related tickets and Spec items appear instantly. Questions come after you submit.
- **B · Agent check while typing**: Questions appear as you write.
- **C · Manual "Check" button**: Only when you press it.

**Chosen:** Local search while typing, agent check on Submit

**My recommendation and reason:** Local search while typing, agent check on Submit. It gives you the useful hints for free and spends tokens only once, on a ticket you decided to send. Checking while typing would re-run the agent on every pause.

### E3. How do screenshots get into a ticket?

- ✔ ★ **A · Drop or paste, capture the Echo window, simple annotation**: Box, arrow and note on the image.
- **B · Drop or paste only**: Annotate in another app.
- **C · Capture only**: Window capture, nothing else.

**Chosen:** Drop or paste, capture the Echo window, simple annotation

**My recommendation and reason:** Drop or paste, capture the Echo window, simple annotation. Pointing at the exact element is what makes a screenshot useful to an agent, and capture-and-mark is the fastest way to do that. The annotation is only three tools, so it is small to build.

### E4. How do the agent's questions reach you?

- ✔ ★ **A · Answer cards in the ticket**: Each question has suggested answers as buttons and a free text field. They also appear on the Desk.
- **B · Comments only**: Questions are posted as thread comments.
- **C · A dialog**: A modal shows all questions.

**Chosen:** Answer cards in the ticket

**My recommendation and reason:** Answer cards in the ticket. Structured answers are what lets the agent read your reply exactly. Suggested answers make most questions one click. Everything is mirrored to the GitHub thread for the record.

### E5. Which kinds of links exist between tickets?

- ✔ ★ **A · Five kinds**: Related, Parent (Theme), Blocks, Duplicates, Supersedes.
- **B · Three kinds**: Related, Parent, Blocks.
- **C · Free text**: Mention #numbers.

**Chosen:** Five kinds

**My recommendation and reason:** Five kinds. Supersedes matters here: a new decision that replaces an old one should say so, so the old Spec item is flagged. Duplicates lets the check offer to merge. Both are small to add and hard to reconstruct later.

### E6. What happens when the check finds a likely duplicate?

- ✔ ★ **A · Offer Merge, Link, or Keep separate**: You decide.
- **B · Close automatically**: The newer ticket is closed.

**Chosen:** Offer Merge, Link, or Keep separate

**My recommendation and reason:** Offer Merge, Link, or Keep separate. Similar is not the same. A new ticket may be about the same area but a different change, and closing it silently would lose that.

### E7. Should each type have a template?

- ★ **A · Required fields per type**: Bug: steps, expected, actual. Tweak: element and change. Sketch: goal and constraints. Proposal: what, why, scope.
- ✔ **B · One free-form body**: Write what you like.

**Chosen:** One free-form body  **(DIFFERENT FROM RECOMMENDATION)**

**My recommendation and reason:** Required fields per type. The fields are what the agent will ask about anyway. Having them in the form means fewer round trips. You can leave a field short, and Hatch will ask only about what is missing.

> **Your note:** The agent that vets the ticket also rewrites it and suggest the ticket to me and I accept or have notes or can edit it
>
> **My reply:** Agreed, and I added decision E8 for exactly this. The vetting agent rewrites your free-form text into the structure of the ticket type and shows it as a diff beside the questions. You choose Accept, Edit or Keep mine, and your original is always kept in the history. That is also why free-form input (your pick on E7) works: you write loosely and Hatch does the structuring.

### E8. The vetting agent rewrites your ticket: how does the rewrite reach you?

From your note on E7: the agent that vets the ticket also rewrites it, and you accept it, add notes or edit it. Your free-form text stays the starting point.

- ✔ ★ **A · Suggested rewrite with a diff: Accept, Edit or Keep mine**: Hatch shows your original and the rewrite side by side, structured for the type (for a Bug: steps, expected, actual), with changed passages marked and the questions beside it. Accept publishes the rewrite to GitHub. Edit opens it for changes. Keep mine publishes your text. Your original is always kept in the history.
- **B · The agent edits the ticket directly, you review afterwards**: The issue on GitHub is already rewritten when you see it.
- **C · Questions only, no rewrite**: The agent asks, and you fix the text yourself.

**Chosen:** Suggested rewrite with a diff: Accept, Edit or Keep mine

**My recommendation and reason:** Suggested rewrite with a diff: Accept, Edit or Keep mine. The rewrite is the same pass as the check, so it costs almost nothing extra, and it is why free-form input (E7) works: you write loosely and Hatch does the structuring. Showing it as a diff with Accept, Edit or Keep mine means the text on GitHub is always something you approved, and keeping your original in the history means a rewrite can never lose what you meant.

> **Your note:** Vetting agent should also see if it really is a bug or a question or…
>
> **My reply:** Yes, and I added decision E9 for it. In the same review as the rewrite, the agent also says whether the type looks wrong, with its reason, and you decide. For example: a Bug with no steps to reproduce may really be a Question. A Tweak with several reasonable fixes should be a Proposal. A Question about how something should look may be a Sketch. A ticket that spans several areas may be a Theme with child tickets. Accept changes the type, Keep mine leaves it. I recommend suggesting and not changing it automatically, because the type decides the whole path and you know the intent better than the agent can from the text.

### E9. The agent checks whether the ticket type is right

From your note on E8: the vetting agent should also check whether a ticket really is a Bug, a Question or something else.

- ✔ ★ **A · Suggest a type change with the reason, you decide**: Shown in the same review as the rewrite: "This reads as a Question, not a Bug: there are no steps to reproduce." Accept changes the type, Keep mine leaves it. Signals it looks for: a Bug without steps or an expected result may be a Question. A Tweak with several reasonable fixes should be a Proposal. A Question about how something should look may be a Sketch. A ticket that spans several areas may be a Theme with child tickets.
- **B · Change the type automatically**: The agent re-types the ticket and tells you afterwards.
- **C · Never change the type**: It stays as you chose it.

**Chosen:** Suggest a type change with the reason, you decide

**My recommendation and reason:** Suggest a type change with the reason, you decide. The type decides the whole path: a Bug goes straight to build and a Question never does, so a wrong type wastes real work. But the agent is guessing from text and you know the intent, so the final call stays with you. Putting it in the same review as the rewrite costs no extra step, and the reason it gives makes a wrong suggestion easy to refuse.

### V1. What is the vetting agent called?

The agent that checks, questions, rewrites and re-types your tickets should feel like one consistent colleague. The name appears in the Desk ("Tally asks 2 questions"), in the ticket thread and in the rewrite review.

- ★ **A · Tally**: A tally clerk checks what comes aboard against the manifest, which is what vetting does against the Spec and other tickets. Short, friendly, reads like a first name.
- **B · Quill**: A pen. Fits the rewriting, but says less about checking.
- **C · Latch**: It holds the hatch shut until the ticket is ready. Ties to the app name, but sounds more like a gate than a colleague.
- ✔ **D · Iris**: A person's name, and also the ring that controls an opening, like a hatch. Warm, but the link to vetting is indirect.
- **E · No name, "Hatch check"**: Keep it as a function of the app.

**Chosen:** Iris  **(DIFFERENT FROM RECOMMENDATION)**

**My recommendation and reason:** Tally. The agent does something specific: it checks a ticket against the manifest of what already exists, and asks about what is missing. "Tally" says that in one word, is easy to say in a sentence ("Tally wants to know if this replaces #118"), and works as a first name without pretending to be a person. It is also not a word that appears elsewhere in Hatch, so it stays recognisable. I would use the same name for every vetting step: questions, rewrite and type check.


---

## F. Ticket view

### F1. How is a ticket page structured?

- ✔ ★ **A · Header and banner, then tabs**: Overview, Options (or Variants), Thread, Work, History.
- **B · One long scroll**: All sections on one page.
- **C · Thread always visible**: Main content left, thread always on the right.

**Chosen:** Header and banner, then tabs

**My recommendation and reason:** Header and banner, then tabs. Each tab is a different kind of work: judging, discussing, watching a build. Tabs keep the Options tab free for the full width the stage needs. The thread is one click away, and the banner always shows what is expected.

### F2. How prominent is "whose turn it is"?

- ✔ ★ **A · A banner with the main action**: A coloured bar at the top: what is expected, and the button for it.
- **B · A status chip only**: Small chip in the header.

**Chosen:** A banner with the main action

**My recommendation and reason:** A banner with the main action. The most common question on opening a ticket is "what do I do here". A banner answers it with a button, so you do not hunt for the next step.

### F3. How is the thread shown?

GitHub comments, agent messages and system events all belong to the ticket.

- ✔ ★ **A · One timeline with filters**: Comments, agent messages and events together. Toggle events on or off.
- **B · Separate Thread and History tabs**: Conversation apart from system events.

**Chosen:** One timeline with filters

**My recommendation and reason:** One timeline with filters. The order of events is the story, for example "you sent it back, then rev 2 arrived". Filters give the clean conversation view when you want it.

### F4. How do you talk to the agent from a ticket?

A comment from you can mean different things.

- ✔ ★ **A · Three message kinds: Note, Ask, Instruction**: Note adds context. Ask expects an answer and moves the turn to the agent. Instruction changes the work.
- **B · A single comment box**: The agent decides what you meant.

**Chosen:** Three message kinds: Note, Ask, Instruction

**My recommendation and reason:** Three message kinds: Note, Ask, Instruction. The kind decides what Hatch does next, so it should not be guessed. An Ask moves the turn, a Note does not, and an Instruction creates a revision. That is code, not agent memory.

### F5. How much history do you see?

- ✔ ★ **A · Every event in History**: Status changes, picks, syncs, commits, token use. Searchable.
- **B · Status changes only**: A short list.

**Chosen:** Every event in History

**My recommendation and reason:** Every event in History. It is already recorded in SQLite, so showing it costs nothing, and it is the answer to "why is this in that status" and "did that reach GitHub".


---

## G. Sketch

### G1. How are variants arranged?

- ✔ ★ **A · Side by side, with a one-at-a-time mode**: Up to three in a row, a carousel for more.
- **B · Carousel only**: One variant at a time.
- **C · Stacked list**: Variants one below the other.

**Chosen:** Side by side, with a one-at-a-time mode

**My recommendation and reason:** Side by side, with a one-at-a-time mode. You choose by comparing, and side by side is the quickest way to compare layouts. The one-at-a-time mode covers four or more variants and detail checks.

### G2. How do you give feedback on a variant?

- ✔ ★ **A · Pinned comments**: Click on the variant to drop a numbered pin with a note.
- **B · A note per variant**: One text box under each variant.
- **C · Rating**: Stars or thumbs.

**Chosen:** Pinned comments

**My recommendation and reason:** Pinned comments. "Too much scrolling here" is more useful to an agent than "B is worse". The pin records the position, and you can still add a general note per variant.

### G3. How are Sketches drawn?

No Swift is compiled for a Sketch.

- ✔ ★ **A · HTML styled like macOS, clearly marked as a concept**: Appears in seconds, cheap in tokens.
- **B · Static images**: Generated pictures.
- **C · SwiftUI right away**: No Sketch type, only Proposals.

**Chosen:** HTML styled like macOS, clearly marked as a concept

**My recommendation and reason:** HTML styled like macOS, clearly marked as a concept. It answers the layout and flow questions without a compile, which is the point of a Sketch. The Concept label is permanent so nobody mistakes it for a faithful render.

### G4. How does a Sketch end?

- ✔ ★ **A · Choose a direction, mix parts, Make it real**: "Header from A, list from C". Make it real creates a Proposal or Tweak, prefilled.
- **B · Pick one variant**: The chosen variant is the result.

**Chosen:** Choose a direction, mix parts, Make it real

**My recommendation and reason:** Choose a direction, mix parts, Make it real. Real choices mix: you like the header of one and the list of another. A recorded mix gives the next ticket a precise starting point.


---

## H. Proposal stage (today's Rounds page)

### H1. Stage layout: where do controls, specimens and the decision sit?

Try the prototype above. The old Rounds page had three fixed columns, which left the specimens the least room.

- **A · Three fixed columns**: Controls left, specimens in the middle, decision right. Today's layout.
- ✔ ★ **B · Stage first, panels fold away**: Specimens get the width. Controls and Decision are side panels you can fold, open by default on wide windows and folded on narrow ones.
- **C · Stacked**: Specimens on top, controls and decision below.

**Chosen:** Stage first, panels fold away

**My recommendation and reason:** Stage first, panels fold away. Judging is about looking, so the specimens should get the width. Folding panels gives you a full-width view when comparing and brings the controls back when tuning. The prototype has both panels so you can feel it. Three fixed columns waste space at 2 or 3 options, and stacking loses the view of the specimen while you decide.

### H2. How do you switch between specimens?

Proposals have 2 to 5 options plus Echo today.

- **A · All side by side, solo button on each**: Everything visible, and a button shows one large. This is today's behaviour.
- **B · Tabs, one at a time**: Select an option, flip back and forth with a key.
- ✔ ★ **C · Adaptive: side by side up to three, filmstrip beyond**: With 4 or more, a filmstrip of thumbnails at the bottom and two shown large. Space always flips with Echo today.

**Chosen:** Adaptive: side by side up to three, filmstrip beyond

**My recommendation and reason:** Adaptive: side by side up to three, filmstrip beyond. Side by side is the best way to compare, until it gets too narrow to judge. At four or five options a filmstrip keeps every option one click away while two stay large. Space as a flip key means you can always check an option against Echo today without moving the mouse.

### H3. Which compare modes exist?

Try each one in the prototype: Side by side, Overlay, Flip, Wipe, Matrix.

- **A · Side by side only**: Simple, as today.
- **B · Side by side, Overlay, Flip, Wipe**: Four ways to compare one option against Echo today.
- ✔ ★ **C · All four plus Matrix**: Matrix shows every scenario for every option in a grid.

**Chosen:** All four plus Matrix

**My recommendation and reason:** All four plus Matrix. Different differences show up in different modes: Flip reveals small shifts, Wipe shows alignment, Overlay shows spacing, and Matrix shows what changes across states. They are cheap to build because the specimens are the same views, only arranged differently. The default stays Side by side.

### H4. How is Echo today shown?

Every proposal is judged against how Echo looks now.

- ✔ ★ **A · A pinned specimen with a Match badge**: First in the list. A badge says when it was last checked against the real Echo, and warns if Echo changed since.
- **B · A screenshot of the real Echo**: Captured from the running Echo for each scenario.
- **C · Not shown**: Judge on the options alone.

**Chosen:** A pinned specimen with a Match badge

**My recommendation and reason:** A pinned specimen with a Match badge. A specimen can be switched across scenarios, appearances and zoom, which a screenshot cannot. The Match badge keeps it honest: if Echo changed after the specimen was written, you see a warning instead of judging against stale ground. The real-Echo screenshot remains available in the Match check after build.

### H5. How are scenarios (states) tested?

This is the part of the old page that was hardest to use.

- **A · Scenario strip**: Named states in a row, one click each. Applies to all specimens at once.
- ✔ ★ **B · Strip plus Matrix view**: The strip, and a grid of every scenario by every option for spotting differences.
- **C · Controls panel only**: States are knobs among the other controls.

**Chosen:** Strip plus Matrix view

**My recommendation and reason:** Strip plus Matrix view. The strip answers "how does it look when it errors". The Matrix answers "where do my options differ across all states", and flags the cells that differ from Echo today. Having states as knobs hides them among tuning controls and makes you set them one by one on each specimen.

> **Your note:** Sometimes I need to test several options at the same time. Please think of how this would be handled best
>
> **My reply:** I may have read this narrowly, so tell me if I got it wrong. Looking at several options at once is covered by your picks on H2 (all side by side) and H5 (scenarios and the matrix). What side by side does not give you is mixing parts of different options, such as the spacing from A with the icon from B. I added H22 for that: a live Mix column driven by your answers to the questions, which you can pin into extra columns and compare next to the original options in the same scenarios and appearances. If you meant something else, for example several options running with real interaction at the same time, tell me and I will add it as another option.

### H6. Which scenarios must every Proposal include?

The agent decides what to test unless there is a standard set.

- ✔ ★ **A · A standard set, extendable**: Rest, Hover, Pressed, Focus, Disabled, Empty, Error, Long text, Many items, Loading. A Proposal marks a state as not applicable with a reason.
- **B · The agent chooses**: Whatever seems relevant.
- **C · A short set**: Rest, Hover, Error.

**Chosen:** A standard set, extendable

**My recommendation and reason:** A standard set, extendable. Most regressions live in the states nobody looked at, such as long text or empty. A standard set makes them part of every judgment, and the "not applicable, because" note makes skipping a deliberate choice. Hatch checks this in code (see the quality gate).

### H7. Appearance controls: what and where?

- ✔ ★ **A · Always-visible bar: appearance, contrast, corners, text size, motion**: Light, Dark, Increase Contrast; Corners 10 or 26; text size; Reduce Motion. Applies to all specimens, remembered per ticket.
- **B · A menu in the toolbar**: Hidden behind one button.
- **C · Show all appearances at once**: Each specimen rendered in light and dark together.

**Chosen:** Always-visible bar: appearance, contrast, corners, text size, motion

**My recommendation and reason:** Always-visible bar: appearance, contrast, corners, text size, motion. You check light and dark constantly, and Corners 10 versus 26 matters in Echo, so these must be one click. A bar that is always visible makes them part of every look. A "both at once" toggle can be offered from the same bar, but doubling every specimen all the time costs width.

### H8. Measurements: how do you see exact spacing and sizes?

Turn on Redlines in the prototype.

- ✔ ★ **A · Redlines overlay**: A toggle draws padding, gaps and sizes on the specimens in the specimen's units.
- **B · A measurements table**: Numbers listed beside the specimens.
- **C · None**: Judge by eye.

**Chosen:** Redlines overlay

**My recommendation and reason:** Redlines overlay. Spacing is the thing you keep deciding, and numbers drawn on the specimen tie each value to the place it applies. It is also the same data the Match check compares afterwards, so the specimens already know their measurements. A table can come later as a detail view.

### H9. Zoom and sizing

Specimens have a real design size.

- ✔ ★ **A · 100% means Echo's real size, fit when too wide, with a label**: Zoom steps up to 200%. A note says when a specimen is scaled down.
- **B · Always fit to the available width**: Specimens scale to the window.

**Chosen:** 100% means Echo's real size, fit when too wide, with a label

**My recommendation and reason:** 100% means Echo's real size, fit when too wide, with a label. You judge spacing and type at their real size, and scaling by stealth would make 12pt look like 9pt without telling you. Fit-to-width is still one click for overview.

### H10. Controls panel: how are the knobs organized?

- ✔ ★ **A · Decision controls first, Playground folded, presets on top**: Controls with a question come first with the recommended star. Knobs without a question are in a folded Playground. A Recommended preset sets everything.
- **B · One flat list**: All controls together.
- **C · No controls**: Only fixed options.

**Chosen:** Decision controls first, Playground folded, presets on top

**My recommendation and reason:** Decision controls first, Playground folded, presets on top. Controls with a question are the decision, and playground knobs like speed are not. Keeping them apart stops a speed slider looking like a design question. The Recommended preset lets you try my whole answer in one click.

### H11. The decision panel

Today: one card per question with a recommendation, reason, radio choices and a note.

- ✔ ★ **A · Keep the card per question, add "Use recommendation" and "Use what's in preview"**: Every card shows what I recommend and why. Bottom: Accept or Send back.
- **B · Single choice**: Choose one option as a whole, no per-question answers.
- **C · Ranking**: Order the options by preference.

**Chosen:** Keep the card per question, add "Use recommendation" and "Use what's in preview"

**My recommendation and reason:** Keep the card per question, add "Use recommendation" and "Use what's in preview". Your decisions are rarely "all of B". You choose the spacing from one and the placement from another, and per-question answers capture that. The recommendation with its reason is a requirement you set, so it is part of every card.

### H12. Verdicts on options

- ✔ ★ **A · Pick, Maybe, No on each option, plus a note**: Shown on the specimen header (see prototype) and summarized in the decision panel.
- **B · Pick only**: One selected option.
- **C · Star rating**: 1 to 5.

**Chosen:** Pick, Maybe, No on each option, plus a note

**My recommendation and reason:** Pick, Maybe, No on each option, plus a note. "Maybe" is the verdict that tells the agent what to keep refining, and "No" tells it what not to bring back. Both are lost with pick-only. It already works this way in Echo Labs.

### H13. Notes on the stage

A note should say what you were looking at.

- ✔ ★ **A · Pin a note on the specimen**: Click a spot to drop a pin. It stores the scenario, appearance, corners and zoom you had on. Also notes per option, per question and general.
- **B · Text notes only**: No position.

**Chosen:** Pin a note on the specimen

**My recommendation and reason:** Pin a note on the specimen. "Spacing too tight" means something different in dark mode with Large text than in light. A pin that records the state it was written in lets the agent reproduce what you saw, and re-opens the stage in that state when you click it.

### H14. Asking a question while judging

- ✔ ★ **A · Ask button in the stage toolbar**: Sends your question with a picture of the current view and the state. The answer arrives in the thread and in the Ask panel.
- **B · Ask through the thread only**: Leave the stage to write.

**Chosen:** Ask button in the stage toolbar

**My recommendation and reason:** Ask button in the stage toolbar. The question is usually about what you are looking at. Sending the current view and state with it means the agent sees what you see, with no explanation needed.

### H15. Revisions after you send it back

- ✔ ★ **A · Keep old options, mark new ones, revision switcher, compare revisions**: NEW badges, a "New since your last review" summary, and a way to view revision 1 or overlay 1 on 2.
- **B · Only the latest**: Replace the options.

**Chosen:** Keep old options, mark new ones, revision switcher, compare revisions

**My recommendation and reason:** Keep old options, mark new ones, revision switcher, compare revisions. It keeps the existing rule that old options are never removed, because your earlier picks refer to them. Overlaying revisions shows exactly what changed.

### H16. What happens when you press Accept?

Accepting starts an agent run that costs tokens.

- ✔ ★ **A · A confirmation sheet**: Lists your choices, the repos and branches that will change, the tests that will run and a token estimate. Then Accept.
- **B · Immediate**: Accept and start.

**Chosen:** A confirmation sheet

**My recommendation and reason:** A confirmation sheet. Accept starts work and spends money, so it is the one place worth one more look. The sheet is also where you notice that the wrong repo or branch is selected.

### H17. What happens when you press Send back?

- ✔ ★ **A · Choose a reason, then write what to change**: Needs more options, Change an option, or Different direction. A note is required.
- **B · Free note only**: Write whatever you like.

**Chosen:** Choose a reason, then write what to change

**My recommendation and reason:** Choose a reason, then write what to change. The reason picks what the agent does: add options and keep the old ones, edit one option, or start from a new angle. Saying so in a field is faster and less error-prone than expecting the agent to infer it from prose.

### H18. How are animated specimens judged?

Toasts, sheets and transitions move.

- ✔ ★ **A · Transport bar**: Play, scrub, step one frame, speed 0.25x to 2x, loop, and Reduce Motion preview. The timeline of tagged parts is drawn under it.
- **B · Play button only**: Plays at normal speed.

**Chosen:** Transport bar

**My recommendation and reason:** Transport bar. Motion decisions are about timing you cannot judge at 1x, such as when the toast goes away. Scrubbing and slow speed let you see it, and the timeline is the same data the Match check compares against Echo afterwards.

### H19. A quality gate before a Proposal reaches you

- ✔ ★ **A · Hatch validates the Proposal in code on hatch offer**: Echo today present, standard scenarios covered or marked not applicable, every question has a recommendation and reason, specimens render, design sizes set. If not, it goes back to the agent.
- **B · The agent follows the guide**: As HOW_TO_WRITE_A_ROUND.md today.

**Chosen:** Hatch validates the Proposal in code on hatch offer

**My recommendation and reason:** Hatch validates the Proposal in code on hatch offer. This is your rule of doing as much as possible in code. A missing recommendation is currently an assertion that fails in the app, after the agent has finished. The gate catches it while the agent can still fix it, and you never see a half-finished Proposal.

### H20. Keyboard on the stage

- ✔ ★ **A · Full map**: Space flip, ← → switch specimen, 1–5 compare modes, L/D light and dark, R redlines, S scenario next, ⌘↩ Accept, ⌘⇧↩ Send back. A help overlay on ?
- **B · Mouse only**: No shortcuts.

**Chosen:** Full map

**My recommendation and reason:** Full map. You will switch and compare hundreds of times. The shortcuts are single keys, and ⌘↩ for Accept can be a confirm sheet (see above), so a stray key never starts a build.

### H21. When a specimen fails or is out of date

- ✔ ★ **A · Show the failure on the specimen**: A clear message in the place of the specimen, a button to report it to the agent, and the rest of the stage keeps working. A banner says when a specimen is older than the latest code.
- **B · Blank or crash**: Whatever the code does.

**Chosen:** Show the failure on the specimen

**My recommendation and reason:** Show the failure on the specimen. One broken specimen must not stop you judging the others. The report button turns the failure into an instruction to the agent.

### H22. Testing several options at the same time

From your note on H5. This can mean three things: (1) looking at several options side by side, (2) mixing parts of different options, such as spacing from A with the icon from B, (3) comparing all options across every state. Your picks on H2 and H5 already cover 1 and 3. The open question is mixing.

- **A · Choose which options are shown, side by side only**: Checkboxes pick up to five columns. Scenarios and appearance apply to all of them at once.
- ✔ ★ **B · Add a live Mix column, pinnable into extra columns**: A Mix column is drawn from your current answers to the decision questions. Pin a Mix to keep it as its own column (Mix 1, Mix 2) and try other combinations next to the original options.
- **C · One Stage window per option**: Open each option in its own window, as in S5.

**Chosen:** Add a live Mix column, pinnable into extra columns

**My recommendation and reason:** Add a live Mix column, pinnable into extra columns. Your decisions are rarely "all of B". They are the spacing from one option and the placement from another, and a Mix lets you see that combination before you accept it instead of imagining it. Pinned Mixes sit next to the original options in the same scenarios and appearances, so you compare them the same way. Separate windows work, but they make state-by-state comparison harder.


---

## S. Swift rounds as separate apps

### S1. Where do Swift Proposals run?

Your idea: open a separate application for a Swift round, so Hatch is not rebuilt for every new round.

- **A · Inside Hatch**: Echo's specimens are compiled into Hatch. Every new round rebuilds and relaunches Hatch, as Echo Labs does today.
- ✔ ★ **B · A separate Stage app per Proposal**: Hatch launches a small app that contains the stage and that round only. Prebuilt kits are reused, only the round is compiled.
- **C · One long-running Stage that loads rounds as plug-ins**: No relaunch at all, but compiled SwiftUI is loaded into a running app.

**Chosen:** A separate Stage app per Proposal

**My recommendation and reason:** A separate Stage app per Proposal. Hatch is rebuilt only when Hatch itself changes, and a broken round cannot take Hatch down, which is the failure you hit with the Rebuild button today. Only the round is compiled because the stage kit, the specimens and the design system are prebuilt and cached. Option C would remove even the relaunch, but loading compiled SwiftUI into a running app is fragile, so I would measure B first and consider C only if the relaunch feels slow.

### S2. What does the Stage app contain?

The compare modes, scenarios and decision panel need to sit next to the specimens.

- ✔ ★ **A · The whole stage, from a shared StageKit, plus the round**: Everything in the prototype above runs inside the Stage app.
- **B · Specimens only**: Hatch captures pictures of them and draws the stage around the pictures.

**Chosen:** The whole stage, from a shared StageKit, plus the round

**My recommendation and reason:** The whole stage, from a shared StageKit, plus the round. One app cannot draw live SwiftUI views from another app, so the stage and the specimens have to live in the same process. With pictures only, you would lose hover, motion, scrubbing and the exact sizes, and that is what judging a Swift round is for.

### S3. How do Hatch and the Stage app talk to each other?

Every pick, note and verdict has to end up in SQLite and, through the sync, on GitHub.

- ✔ ★ **A · Local API, Hatch is the only writer**: The Stage sends each pick and note to Hatch. If Hatch is not running, the Stage keeps them and delivers them later.
- **B · Both write to the SQLite file**: Shared database access.
- **C · The Stage writes files that Hatch reads**: JSON files in a folder.

**Chosen:** Local API, Hatch is the only writer

**My recommendation and reason:** Local API, Hatch is the only writer. You set the rule that the app owns the bookkeeping. With one writer there are no lock conflicts, and every change goes through the same status rules and the sync record. Two processes writing to one SQLite file is where corrupted or half-synced state comes from.

### S4. Where does the code of a Swift round live?

Rounds are Swift packages that depend on the design system and on Echo's shared "today" specimens.

- ✔ ★ **A · A per-project specimens repo**: echo-specimens: the shared Echo-today views, plus one folder per round.
- **B · In the Echo repo**: Next to the app code.
- **C · In the private tickets repo**: Next to the issue.

**Chosen:** A per-project specimens repo

**My recommendation and reason:** A per-project specimens repo. It keeps experiments out of Echo, which was your goal in splitting Labs out. Rounds share the Echo-today views instead of copying them, and the repo has real Swift versions and tags. An accepted round is archived into Decisions with a tag. The tickets repo is meant for text, and mixing code into it makes both harder to read.

### S5. How do the Stage windows behave?

- ✔ ★ **A · One Stage window per Proposal**: Hatch shows its status and a Focus button. A new revision offers Reload. It closes when the ticket leaves Your call, after a confirmation.
- **B · One reusable Stage window**: Opening another Proposal replaces the first.

**Chosen:** One Stage window per Proposal

**My recommendation and reason:** One Stage window per Proposal. You may want to compare two Proposals, or keep one open while writing a note in Hatch. State is stored per ticket in SQLite, so closing and reopening a Stage loses nothing.

### S6. When is the Stage built and checked?

- ✔ ★ **A · Before it reaches you**: Hatch builds the Stage and runs it headless for the quality gate before the ticket becomes Your call. The build log is on the ticket.
- **B · The agent builds it and Hatch trusts it**: No check by Hatch.
- **C · When you press Open**: Build on demand.

**Chosen:** Before it reaches you

**My recommendation and reason:** Before it reaches you. The quality gate (H19) needs the specimens to run, and a round that does not compile should go back to the agent, not to you. It also means Open is instant, because the Stage is already built.

### S7. What if a Stage crashes, or Hatch is not running?

- ✔ ★ **A · Contain it**: Hatch shows "Stage closed unexpectedly" with Relaunch and Send crash report to agent. The Stage keeps your picks until Hatch is back.
- **B · Nothing special**: Whatever happens, happens.

**Chosen:** Contain it

**My recommendation and reason:** Contain it. Separate processes only help if one failing does not lose the other's work. Keeping your picks in the Stage until they are delivered means a crash never costs you a judgement, and the crash report turns into an instruction for the agent.


---

## I. Building, tests and merging

### I1. How is a build shown?

- ✔ ★ **A · Steps with results and a live log**: Plan, Claim, Implement, Build, Tests, Match check, Ready.
- **B · Status and log only**: A chip and a text stream.

**Chosen:** Steps with results and a live log

**My recommendation and reason:** Steps with results and a live log. You can see in one glance where it is and where it failed. The log stays one click away for details.

### I2. When must you approve the agent's plan?

The plan lists the files it will touch and the tests it will run.

- ✔ ★ **A · Only for Bugs and large changes**: Auto-proceeds for accepted Proposals and Tweaks. Asks when more than a set number of files.
- **B · Always**: Every build waits for you.
- **C · Never**: Plan is shown, not approved.

**Chosen:** Only for Bugs and large changes

**My recommendation and reason:** Only for Bugs and large changes. An accepted Proposal already says what to build, so asking again is friction. A Bug fix or a plan that spreads over many files is where surprises happen, so that is where you get a say.

### I3. Which tests run?

- ✔ ★ **A · Tests mapped to the area; the repo's CI runs the full suite**: The project config says which test plan belongs to which area. Hatch runs only that in the ticket's workspace. The full suite is left to CI (see I6).
- **B · Always the full suite**: Every ticket.
- **C · None until merge**: Only build.

**Chosen:** Tests mapped to the area; the repo's CI runs the full suite

**My recommendation and reason:** Tests mapped to the area; the repo's CI runs the full suite. It keeps the loop fast while you iterate. You said the testing must stay limited, and that the repo should cover the rest, so Hatch does not run a full build before merge. CI does that (see I6).

> **Your note:** I don’t think we need a full build before merge - if we merge to Echo, the repo should cover the testing part, right? Maybe a separate branch in Echo (or whichever project) which is coming from Hatch, so there is a hatch branch?
>
> **My reply:** You are right, and Echo already has CI: CI (Light) runs Build & Test on every push to dev, and CI (Full) runs on main and on pull requests to it, both on your xcode-27 runner. I reworded I3 so Hatch only runs the area-mapped tests in the ticket's workspace. Your answer to I3 still stands, only the words 'full suite before merge' are gone. I added I6: approved tickets merge into a hatch branch, CI checks it, and Hatch promotes it to dev when it is green. The cost is a small change to ci-light.yml so it also triggers on the hatch branch. Hatch reads the check results from GitHub and shows them on the ticket.

### I4. How is the Match check shown?

- ✔ ★ **A · Parts table plus image comparison**: Per part pass or fail, and the accepted | Echo | diff image for each state.
- **B · Pass or fail only**: A single result.

**Chosen:** Parts table plus image comparison

**My recommendation and reason:** Parts table plus image comparison. It is the evidence that Echo looks like what you accepted. If it fails, you want to see which part and how far off.

### I5. What can you do while an agent is working?

- ✔ ★ **A · Stop, take over in Terminal or Xcode, send an instruction**: Take over opens the workspace.
- **B · Stop only**: End the run.

**Chosen:** Stop, take over in Terminal or Xcode, send an instruction

**My recommendation and reason:** Stop, take over in Terminal or Xcode, send an instruction. Sometimes you want to finish the last bit yourself. Because each ticket has its own workspace, handing it to you does not disturb any other agent.

### I6. Where do merged tickets go, and what tests them?

From your note on I3: no full build before merge, the repo's CI should cover testing. Echo already has CI: "CI (Light)" runs Build & Test on every push to dev, and "CI (Full)" runs on main and on pull requests to it, both on your xcode-27 runner.

- **A · Straight to dev**: Approved tickets merge to dev. CI (Light) tests them afterwards. If it fails, the ticket reopens.
- ✔ ★ **B · A hatch integration branch checked by CI, then promoted**: Approved tickets merge into a hatch branch. CI runs on it. When it is green, Hatch promotes it to dev. Hatch reads the check results from GitHub and shows them on each ticket.
- **C · Full local suite before merge**: Hatch runs all the tests on your Mac.

**Chosen:** A hatch integration branch checked by CI, then promoted

**My recommendation and reason:** A hatch integration branch checked by CI, then promoted. It uses the testing you already maintain, so Hatch does not duplicate it, and nothing reaches dev until CI is green. The cost is a small change to ci-light.yml so it also runs on the hatch branch. A failing ticket is named on the Board. Straight to dev is faster, but a red dev then blocks whatever else you are working on, and a full local run is the slow thing you wanted to avoid.


---

## J. Preview and verify

### J1. How do tickets get into a Preview?

- ✔ ★ **A · You select them**: Checkboxes on Previews. Hatch builds that set.
- **B · Automatic**: Everything To verify is merged into one Preview.
- **C · One Preview per ticket**: Separate builds.

**Chosen:** You select them

**My recommendation and reason:** You select them. You choose what you want to look at together, and a ticket that is not ready stays out. Automatic previews change under you, and per-ticket builds are the slow thing you wanted to avoid.

### J2. What happens when two tickets conflict?

- ✔ ★ **A · Tell you which pair, offer drop, stack or ask the agent to resolve**
- **B · Fail the build**: Show an error.

**Chosen:** Tell you which pair, offer drop, stack or ask the agent to resolve

**My recommendation and reason:** Tell you which pair, offer drop, stack or ask the agent to resolve. A conflict is information about which tickets overlap. Naming the pair and offering the next step turns an error into a decision.

### J3. How do you verify?

- ✔ ★ **A · Per ticket: Looks right or Needs work**: With a checklist of what to look at, notes and screenshots.
- **B · Approve all**: One button for the whole Preview.

**Chosen:** Per ticket: Looks right or Needs work

**My recommendation and reason:** Per ticket: Looks right or Needs work. You will often find two good and one wrong. Per-ticket verdicts let the good ones merge while the third goes back. The checklist comes from the accepted option so you know what to look at.

### J4. How does the Preview app run?

The Preview is a separate build of Echo.

- ✔ ★ **A · A separate copy, labelled Preview 03**: Runs next to your normal Echo. A banner in the window says it is a Preview.
- **B · Replaces your running Echo**: Quit and relaunch.

**Chosen:** A separate copy, labelled Preview 03

**My recommendation and reason:** A separate copy, labelled Preview 03. You can compare with the Echo you use every day and nothing you rely on is replaced. The banner needs a small DEBUG addition in Echo.

### J5. How are approved tickets merged?

- ✔ ★ **A · Merge plan shown first, one button**: Design system first, tag, then Echo bumps and merges.
- **B · Manual**: You merge each branch yourself.

**Chosen:** Merge plan shown first, one button

**My recommendation and reason:** Merge plan shown first, one button. The order matters and is easy to get wrong by hand. Showing the plan first keeps you in control, and one button does the safe sequence.

### J6. What if one ticket in a Preview fails?

- ✔ ★ **A · Others still merge**: The failed one goes to Fixing.
- **B · All or nothing**: The Preview is rejected.

**Chosen:** Others still merge

**My recommendation and reason:** Others still merge. Tickets are independent changes. Holding good ones back for a bad one only slows you down. The merge plan is recomputed without the failed ticket.


---

## K. Agents and claims

### K1. Is there an Agents screen?

- ✔ ★ **A · Yes: runs, claims, queue and cost**: One table of running work with queue and claims.
- **B · Only inside tickets**: No overview.

**Chosen:** Yes: runs, claims, queue and cost

**My recommendation and reason:** Yes: runs, claims, queue and cost. With several agents in parallel you need one place that shows what is running, what is waiting for files, and what it costs. It is also where conflicts are resolved.

### K2. How many agents run at once?

- ✔ ★ **A · Default 3, configurable**: Slots shown on the Agents screen.
- **B · Unlimited**: Start everything.
- **C · One at a time**: A queue.

**Chosen:** Default 3, configurable

**My recommendation and reason:** Default 3, configurable. Three parallel Swift builds is about what a Mac does comfortably, and it limits how many token streams run at the same time. A setting lets you raise it.

### K3. What happens when two tickets want the same files?

- ✔ ★ **A · Queue by default, offer Stack**: The later ticket waits. A button stacks both on one branch in order.
- **B · Always ask you**: A prompt every time.
- **C · Stack automatically**: One agent, one branch.

**Chosen:** Queue by default, offer Stack

**My recommendation and reason:** Queue by default, offer Stack. Queueing is the safest default because the second ticket then builds on the first one's finished work. Stacking is faster but couples two tickets, so it should be a choice you make.

### K4. How are agents named?

- ✔ ★ **A · By ticket: "Agent on #144"**: No persistent identity.
- **B · Agent 1, 2, 3**: Fixed slots.

**Chosen:** By ticket: "Agent on #144"

**My recommendation and reason:** By ticket: "Agent on #144". Agent sessions are temporary, and the ticket is the useful label. Slot numbers would suggest an identity that does not exist.

### K5. Do you see token use?

- ✔ ★ **A · Per run, per ticket and per day**: Shown on the Agents screen and ticket sidebar.
- **B · Hidden**: Not shown.

**Chosen:** Per run, per ticket and per day

**My recommendation and reason:** Per run, per ticket and per day. You said cost matters, and seeing which kinds of tickets are expensive is how you learn where to simplify.


---

## L. Projects, setup and Specs

### L1. How is a project set up?

- ✔ ★ **A · Settings screen that writes .hatch/project.json into the app repo**: Agents and CI can read it too.
- **B · Settings stored only in Hatch**: A database record.
- **C · Config file only**: No settings UI.

**Chosen:** Settings screen that writes .hatch/project.json into the app repo

**My recommendation and reason:** Settings screen that writes .hatch/project.json into the app repo. You get a friendly screen, and the config is versioned and readable by any agent, even outside Hatch. The file can be committed with the code it describes.

### L2. How is the area index created?

The index maps each area to files and Spec IDs so agents read only the relevant part of a large app.

- ✔ ★ **A · An agent drafts it, you review**: On setup and on Re-scan.
- **B · You write it by hand**

**Chosen:** An agent drafts it, you review

**My recommendation and reason:** An agent drafts it, you review. It is a one-time reading job that an agent does well and you can correct in minutes. The index is the biggest single saving in tokens per ticket.

### L3. Where do Specs live?

Today they are Swift code in Echo Labs.

- ✔ ★ **A · Markdown files in the project repo**: Under .hatch/spec/, indexed into SQLite for search.
- **B · Inside the Hatch database**: Edited in the app.
- **C · Stay as Swift**: Keep the current files.

**Chosen:** Markdown files in the project repo

**My recommendation and reason:** Markdown files in the project repo. Plain text is searchable, readable by every agent and reviewable in a diff. Swift-encoded specs are hard to search and tie Hatch to the old code.

> **Your question:** The specs section is amazing in Echo Labs so I can chose e.g. tab bar and see what we have done for that. It is quite heavy to include in Hatch, but maybe offer a blueprint to build that app for the project or something along those lines. Needs suggestions from you
>
> **My reply:** I added decision L5 with three options. My suggestion is B: Hatch holds the searchable Spec text with links to tickets and decisions, and a separate Spec app per project, built the same way as the Stage, shows each element as a live specimen so you can still pick the tab bar and see what has been decided and how it looks. A blueprint action has an agent scaffold that Spec app for a new project from its area index, and you review it. That keeps the heavy specimen code out of Hatch. A ticket also cannot reach Done until its Spec pages are updated or marked unchanged, which Hatch checks in code.

### L4. What happens to the existing Echo Labs rounds?

- ✔ ★ **A · Import: decided rounds become Done and Decisions, open ones become Proposals**: Keeps history and your decisions.
- **B · Start fresh**: Old Echo Labs stays as an archive.

**Chosen:** Import: decided rounds become Done and Decisions, open ones become Proposals

**My recommendation and reason:** Import: decided rounds become Done and Decisions, open ones become Proposals. Your decisions are the most valuable thing in Echo Labs, and the Spec depends on them. Open rounds continue in the new flow without being re-created.

### L5. How does the Specs section work in Hatch?

From your note on L3: the Specs section in Echo Labs is great, because you can pick e.g. the tab bar and see what has been decided and how it looks. It is heavy to include in Hatch, so you asked for suggestions, maybe a blueprint to build it per project.

- **A · Text only in Hatch**: Spec items as searchable text, linked to tickets and decisions, with reference screenshots. No live specimens.
- ✔ ★ **B · Text in Hatch, plus a per-project Spec app launched by Hatch**: Hatch holds the searchable Spec text and the links. A separate Spec app per project, built like the Stage, shows each element as a live specimen. "Open in Spec app" jumps to the element. A blueprint action has an agent scaffold the Spec app for a new project from its area index, and you review it.
- **C · Live specimen pages inside Hatch**: As in Echo Labs today.

**Chosen:** Text in Hatch, plus a per-project Spec app launched by Hatch

**My recommendation and reason:** Text in Hatch, plus a per-project Spec app launched by Hatch. It keeps the part you love, picking an element and seeing what is decided and how it looks, and keeps the heavy specimen code out of Hatch, which is the point of S1. The text layer gives search and links to tickets and decisions. The blueprint means a new project starts from a generated skeleton instead of hand-built pages. A ticket then cannot reach Done until its Spec text and Spec app pages are updated or marked unchanged, which Hatch checks in code and an agent no longer has to remember.


---

## M. Data, sync and the agent contract

### M1. Who wins when GitHub and Hatch disagree?

- ✔ ★ **A · Hatch owns status, GitHub owns text**: Edits to title, body and comments on GitHub are accepted. A hand-edited status label is flagged, not obeyed.
- **B · GitHub wins everything**: Always pull.

**Chosen:** Hatch owns status, GitHub owns text

**My recommendation and reason:** Hatch owns status, GitHub owns text. Status transitions have rules (claims, checks) that live in Hatch. Text is free-form and benefits from editing on the phone. Flagging a changed label tells you without breaking the flow.

### M2. What happens offline?

- ✔ ★ **A · Queue and retry with backoff**: A banner shows pending items. Nothing is lost.
- **B · Block changes**: Require a connection.

**Chosen:** Queue and retry with backoff

**My recommendation and reason:** Queue and retry with backoff. Work should never stop because the network does. Every change is recorded in sync_log as pending first, so it survives a quit.

### M3. Where are screenshots stored?

GitHub's API does not support uploading images to issues.

- ✔ ★ **A · Committed to the private tickets repo**: attachments/<ticket>/. Linked from the issue.
- **B · Local only**: Not on GitHub.

**Chosen:** Committed to the private tickets repo

**My recommendation and reason:** Committed to the private tickets repo. It keeps screenshots next to the ticket on every device and for cloud sessions, and it stays private. The cost is repo size, which is small for screenshots.

### M4. How does search work?

- ✔ ★ **A · SQLite full-text over tickets, comments, Specs and decisions**: Behind Search (⌘K), instant and offline.
- **B · GitHub search**: Through the API.

**Chosen:** SQLite full-text over tickets, comments, Specs and decisions

**My recommendation and reason:** SQLite full-text over tickets, comments, Specs and decisions. It is instant, offline and covers Specs and decisions that are not on GitHub. The same index feeds the free similar-ticket hints in the composer.


---

## N. Specs, Decisions and Log

### N1. What do Specs and Decisions look like?

- ✔ ★ **A · Specs by area with IDs and linked tickets, Decisions as read-only frozen results**: Each Decision links the ticket, picks and the Spec items it changed.
- **B · One combined Library**: Specs and Decisions together.

**Chosen:** Specs by area with IDs and linked tickets, Decisions as read-only frozen results

**My recommendation and reason:** Specs by area with IDs and linked tickets, Decisions as read-only frozen results. A Spec says what is true now and a Decision says why. They change at different speeds, and keeping them apart is how Echo Labs already works.

### N2. What does the Log show?

- ✔ ★ **A · Every Hatch action with its GitHub sync result**: Filter by failed. Retry from the row.
- **B · Only errors**: A shorter list.

**Chosen:** Every Hatch action with its GitHub sync result

**My recommendation and reason:** Every Hatch action with its GitHub sync result. You asked that syncs are recorded. A full log makes "did it reach GitHub" answerable in seconds, and errors are one filter away.


---

## O. Build order

### O1. What do we build first?

Nothing has been built yet. The order matters because the biggest assumption is S1: that a Stage app per round builds quickly.

- **A · Foundation first**: SQLite, GitHub sync, projects and the hatch command, then screens, then the Stage.
- ✔ ★ **B · Spike the Stage first, then the foundation**: Build one real round (the toast) as a Stage app with the specimens kit and measure the build time. Then the foundation.
- **C · Screens first with fake data**: Build the Desk and ticket screens against sample data.

**Chosen:** Spike the Stage first, then the foundation

**My recommendation and reason:** Spike the Stage first, then the foundation. S1 is what the rest of the design leans on, and it is also the part you most want to try. The spike needs no GitHub and no database, only the existing toast round and the design system, so it is small. If the build time disappoints, S1 changes, and that is far cheaper to learn before the core is built on top of it.

