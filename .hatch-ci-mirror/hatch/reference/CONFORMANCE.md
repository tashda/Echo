# Checking Echo against an accepted round (conformance)

When a round is accepted, the owner's picks say exactly what Echo should look like: the round's
exhibit drawn with those picks. A conformance check captures that once as the **reference**, then
captures Echo's real view the same way and compares the two. The agent runs it itself before
setting a round to **In Echo**; the owner still confirms in the running app.

```
python3 EchoLab/Scripts/verify-round.py <page-id> --reference   # once, when the round is accepted; commit the result
python3 EchoLab/Scripts/verify-round.py <page-id> --app <Echo.app>   # after building it into Echo (Debug build)
python3 EchoLab/Scripts/verify-round.py <page-id> --no-capture --app x   # compare the last Echo capture again
```

Pilot: round 18, `ongoing.notification-toast-r18`.

## What is compared

| Check | How | Fails when |
|---|---|---|
| **PARTS** | Every part tagged with `.conformanceTag("name")`, relative to the round's `subject` part | a part is missing in Echo, or its x, y, width or height differs by more than 0.5pt |
| **TIMELINE** | When each tagged part appears and goes away, watched for `observe` seconds | a part goes away more than 0.25s earlier or later (a toast's timeout), or only on one side |
| **PIXELS** | The subject cropped from both screenshots, light and dark | never fails; over 2% different pixels is a warning: look at `compare.png` |

Differences the round lists in `knownDifferences` are reported as expected: a part name exempts
that part (a gap in Echo's specimen), `pixels:<part>` only leaves its pixels out of the score and
still checks its frame (a known rendering difference, such as tashda/Echo#32: selectable text on
glass draws with more contrast in Echo Labs than in Echo). The result also goes to
`References/<page-id>/last-check.json` (commit it); the round's info box in Echo Labs shows it as
"Checked against Echo", with Open Comparison. The report and `compare.png` (accepted | Echo | diff, for every state and
appearance) go to `EchoLab/.build/conformance/<page-id>/`. Exit status 1 when parts or timelines differ.

## Making a round checkable

1. **In the round** (`RoundSpec`), add `conformance:` with the states to capture, the subject tag
   and any known differences:
   ```swift
   conformance: RoundConformance(
       states: [.init(id: "rest", title: "…", observe: 4.5), .init(id: "hovered", title: "…")],
       subject: "toast.stack",
       knownDifferences: ["toast.error.actions": "Why it is expected to differ."]),
   ```
   The exhibit reads `@Environment(\.labConformanceState)` on appear and puts itself in that state
   (hover a row, open a menu). It must be deterministic: same sample data, same order.
2. **Tag the parts** in the exhibit with `.conformanceTag("…")`: the subject, each element whose
   size or place was decided, and anything with a timeline. Names are `area.thing.part`
   (`toast.error.title`). Tags do nothing outside a capture.
3. **In Echo**, tag the same parts with the same names in the real view, and add a specimen for the
   page id to `ConformanceSpecimens` (`Echo/Sources/Features/AppHost/Conformance/`): Echo's real
   view with the same sample data, posted through Echo's real code paths (the toast specimen posts
   through a real `NotificationEngine`), in the same states. DEBUG only.
4. Capture the reference with `--reference` and commit `EchoLab/State/References/<page-id>/`.

## When other work breaks the build

Other sessions edit Echo and Echo Labs at the same time, so the shared checkout may not build.
Then check from a clean worktree: `git worktree add --detach <scratch>/echo-verify HEAD`, copy in
your changed files plus the gitignored build inputs (`Echo/Configuration/Secrets.xcconfig`,
`Tools/PostgresTools`), build Echo there (XcodeBuildMCP with that project and its own DerivedData),
run `verify-round.py` from the worktree, copy `EchoLab/State/References/<page-id>/` back, and remove
the worktree.

## How it works

Echo Labs is captured as the app bundle `open-lab.sh --no-launch` builds, the way the owner runs
it. Both apps capture through `ConformanceCapture` in `Packages/EchoDesignSystem` (`Conformance/`), so
they are measured the same way: the script writes a request and launches the app's executable
directly with `ECHO_CONFORMANCE=<request>` (directly, not with `open`, so it uses the terminal's
screen-recording permission). The app shows the specimen in a bare floating window at the
exhibit's design size, per state and appearance, waits `settle` seconds, screenshots the window
with `screencapture -l` (so Liquid Glass and AppKit views are drawn), records the tagged parts,
and quits. Echo Labs draws the accepted exhibit with `RoundValues(fixed:)`, which never touches
the owner's saved knobs; Echo starts its capture from `EchoApp.init`, before (and without) loading
the user's data. Each shot pins both the window's and the app's appearance, puts the app's other
windows away, and records whether the app was active. A failed capture is tried once more.

The reference records the exhibit as the owner saw it, quirks included. If the check shows that
the exhibit itself was wrong (the pilot found text squeezed by the exhibit's layout), do not copy
the quirk into Echo: ask the owner, fix the exhibit, record a revision and capture the reference again.
