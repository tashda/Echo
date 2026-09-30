# How we design Echo

The loop every design question goes through. Anyone (a person or an agent) can pick up any step.

## 1. Find what needs deciding

- Items marked **Open** or **Leaning** in the rule files and in `decisions.md`.
- New features: before building UI, write down which existing rules apply and what is new.

## 2. Make it judgeable

Anything visual or animated gets a page in **Echo Labs** (`EchoLab/`, Ongoing work; see the Echo Labss workflow in `CLAUDE.md`).

- A playground is a plain SwiftUI view with sample data and a control bar (see `LabStage`, `LabPicker` in `EchoLab/Sources/EchoLab/Ported/DesignLabKit.swift`). It must not depend on app state.
- Register the page in `EchoLab/Sources/EchoLab/Ported/PortedPages.swift` and in `DesignLabWindow.swift` there (a `DesignLabPage` case, its intro, its questions and its playground).
- Every question says exactly which control to use and what to look at.
- Keep the playground's frame flexible (`minWidth`, not a fixed width) so its controls never overflow.
- Animations go through `LabSpeed.spring(…)`, the stand-in for Echo's house spring.

Non-visual or broad questions can go straight to a review page (step 3).

## 3. Collect the verdict

Either:

- **the Feedback panel in Echo Labss**: the owner accepts, comments or reopens, and it is saved in `EchoLab/State/lab-state.json`; or
- **a review page**: an interactive artifact in the same format as the earlier rounds (listed in `reviews.md`), where each option is marked Yes, Maybe or No with notes. Answers are stored in the page's database; read them with the artifact data tools.

## 4. Record the decision

- Update the rule in the matching file (`01`–`06`), changing its marker to **Decided**.
- Add an entry at the top of `decisions.md`: what was decided and where the rule now lives. Never rewrite older entries; a changed rule gets a new entry.
- If a Decided rule is replaced, say so in both places ("replaces the earlier … rule").
- Update the lab's defaults to the decided values.
- Set the Echo Labs page to `In Echo`. When the owner has confirmed it on the real app, freeze it into `Decided/Library/` as live code and remove it from Ongoing.

## 5. Build it

- Follow `plan.md`: pick the next task, mark it in progress, build it, and meet its acceptance criteria.
- Before finishing, check the change against the rules: tokens only, glass only on controls, motion through the house spring, Reduce Motion, Increase Contrast.
- Mark the task done in `plan.md`, with the commit.

## 6. Verify on a Mac

Visual work can't be verified in a Linux container. Say so plainly, and ask the owner to check it on their Mac against the task's acceptance criteria. Where a task needs the owner's eye, the plan says so.
