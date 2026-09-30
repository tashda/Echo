#!/usr/bin/env python3
"""Create and register a new round in Echo Labs, ready to fill in.

    EchoLab/Scripts/new-round.py --slug my-round --title "My round" --area explorer-tree \
        --asked "What the round asks, in a sentence." [--symbol rectangle.stack] [--summary "..."]

It writes Ongoing/<MyRound>/MyRoundRound.swift with a minimal working RoundSpec (one control, an
"Echo today" exhibit and a proposal), and registers the round everywhere it has to appear:
OngoingPages.swift, LabAreas.roundAreas and LabRounds.all (the Rounds page). The round number is
the next free one. Then: fill in the TODOs (see EchoLab/HOW_TO_WRITE_A_ROUND.md), build with
EchoLab/Scripts/open-lab.sh --no-launch, and commit. Areas: foundations, explorer-tree, tabs,
tool-tabs, window, editor, footer-results, inspector, connections, echosense, notifications.
"""
import argparse, os, re, sys
from datetime import date

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("--slug", required=True, help="kebab-case, e.g. server-card")
ap.add_argument("--title", required=True)
ap.add_argument("--area", required=True)
ap.add_argument("--asked", required=True, help="what the round asks, in plain words")
ap.add_argument("--symbol", default="rectangle.stack")
ap.add_argument("--summary", help="page summary; defaults to --asked")
ap.add_argument("--number", type=int, help="round number; defaults to the next free one")
args = ap.parse_args()

root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
src = os.path.join(root, "Sources", "EchoLab")
def read(p): return open(p).read()
def write(p, s): open(p, "w").write(s)

rounds_path = os.path.join(src, "Rounds", "LabRounds.swift")
rounds = read(rounds_path)
number = args.number or (max([int(n) for n in re.findall(r'label: "Round (\d+)"', rounds)] + [0]) + 1)
words = [w for w in re.split(r"[^A-Za-z0-9]+", args.slug) if w]
pascal = "".join(w[:1].upper() + w[1:] for w in words)
camel = pascal[:1].lower() + pascal[1:]
page_id = f"ongoing.{args.slug}-r{number}"
folder = os.path.join(src, "Ongoing", pascal)
file = os.path.join(folder, f"{pascal}Round.swift")
if os.path.exists(file): sys.exit(f"{file} already exists")
today = date.today().strftime("%-d %b %Y")
summary = (args.summary or args.asked).replace('"', '\\"')
asked = args.asked.replace('"', '\\"')
title = args.title.replace('"', '\\"')

os.makedirs(folder)
write(file, f'''import SwiftUI

/// Round {number} · {args.title}. A RoundSpec: see EchoLab/HOW_TO_WRITE_A_ROUND.md for the rules.
/// Fill in every TODO: real exhibits drawn from what Echo does today, real controls, and a
/// recommendation with a reason for every choice the owner decides.
@MainActor
enum {pascal}Round {{
    /// TODO: the choices to compare. Give each a short, stable name.
    enum Style: String, CaseIterable {{
        case proposalA = "A · TODO name"
        case proposalB = "B · TODO name"
    }}

    static let spec = RoundSpec(
        controls: [
            .of("style", "Style", Style.self, default: .proposalA,
                question: "TODO: what to try, then what to decide.",
                recommend: .proposalA,
                why: "TODO: why you would ship this one and what the others cost."),
        ],
        exhibits: [
            .init(id: "today", title: "Echo today", summary: "TODO: as it is built now.", isEchoToday: true,
                  designWidth: 340, designHeight: 240) {{ _ in
                Text("TODO: draw what Echo does today").frame(maxWidth: .infinity, maxHeight: .infinity)
            }},
            .init(id: "proposal", title: "Proposal", summary: "Built from the controls.",
                  designWidth: 340, designHeight: 240) {{ values in
                Text("TODO: draw \\(values["style"])").frame(maxWidth: .infinity, maxHeight: .infinity)
            }},
        ]
    )
}}
''')

# 1. OngoingPages: list + definition
p = os.path.join(src, "Ongoing", "OngoingPages.swift"); s = read(p)
assert "/* ROUNDS-LIST */" in s and "// ROUNDS-DEFINITIONS" in s, "OngoingPages.swift markers are missing"
s = s.replace("/* ROUNDS-LIST */", f", {camel} /* ROUNDS-LIST */")
s = s.replace("    // ROUNDS-DEFINITIONS", f'''    /// Round {number}: {args.title}.
    static let {camel} = LabPage.round(
        id: "{page_id}", group: "{{AREA_TITLE}}", title: "{title} · round {number}", symbol: "{args.symbol}",
        status: .judging,
        summary: "{summary}",
        spec: {pascal}Round.spec)

    // ROUNDS-DEFINITIONS''')
# area title for group (fallback: matches the area's title in LabAreas)
areas = read(os.path.join(src, "Shell", "LabAreas.swift"))
titles = {}
for m in re.finditer(r'(\w+)Area\.area|pending\("([\w-]+)", "([^"]+)"', areas): pass
known = {"foundations":"Foundations","explorer-tree":"Explorer tree","tabs":"Tabs","tool-tabs":"Tool tabs","window":"Window and cards",
         "editor":"Editor and running","footer-results":"Footer and results","inspector":"Inspector","connections":"Connections",
         "echosense":"EchoSense","notifications":"Notifications"}
if args.area not in known: sys.exit("Unknown area. Use one of: " + ", ".join(known))
s = s.replace("{AREA_TITLE}", known[args.area])
write(p, s)

# 2. LabAreas.roundAreas
p = os.path.join(src, "Shell", "LabAreas.swift"); s = read(p)
assert "// ROUND-AREAS" in s, "LabAreas.swift marker is missing"
s = s.replace("        // ROUND-AREAS", f'        "{page_id}": "{args.area}",\n        // ROUND-AREAS', 1)
write(p, s)

# 3. LabRounds.all (newest first)
assert "// ROUND-INFO" in rounds, "LabRounds.swift marker is missing"
entry = f'''        Info(id: "r{number}", label: "Round {number}", title: "{title}", date: "{today}",
             asked: "{asked}",
             outcome: "Being judged.",
             pageIDs: ["{page_id}"]),
'''
marker = re.search(r"        // ROUND-INFO[^\n]*\n", rounds).group(0)
write(rounds_path, rounds.replace(marker, marker + entry, 1))

print(f"Created round {number}: {file}")
print(f"Registered {page_id} in OngoingPages.swift, LabAreas.swift and LabRounds.swift.")
print("Next: fill in the TODOs, run EchoLab/Scripts/open-lab.sh --no-launch, then commit (git commit -- <your paths>).")
print(f"To change it after the owner's feedback: EchoLab/Scripts/lab-revise.py {page_id} \"summary\" \"change\" ...")
