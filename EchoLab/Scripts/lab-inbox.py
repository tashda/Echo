#!/usr/bin/env python3
"""What the owner has sent the agent, straight from EchoLab/State/lab-state.json.

    python3 EchoLab/Scripts/lab-inbox.py            # everything waiting for the agent
    python3 EchoLab/Scripts/lab-inbox.py --all      # also what waits for the owner

"Send back" and "Accept" in Echo Labs only write that file (status, comment, history). Nothing
tells a running agent, so run this at the start of any design work and again after each task.
  New feedback = the owner sent feedback: read the comment, change the round, then use
                 lab-revise.py (it records the revision and sets the status back to Judging).
  Accepted     = the owner accepted the verdict: build it into Echo, then set In Echo.

It also lists the owner's answers in Test › Scenarios (the EchoSense scenario files):
  Flagged      = "this is not what should happen": change the scenario from the note, then set
                 its review back to "imported" so the owner sees it again.
  Approved but failing (known issue) = the scenario is right: fix EchoSense, clear knownIssue.
"""
import os
import json, sys
from pathlib import Path

state = json.loads((Path(__file__).resolve().parents[1] / "State/lab-state.json").read_text())
show_all = "--all" in sys.argv
groups = {"New feedback": "SENT BACK (feedback to act on)", "Accepted": "ACCEPTED (build it into Echo)"}
if show_all:
    groups |= {"Judging": "JUDGING (waiting for the owner)", "In Echo": "IN ECHO (waiting for the owner to check)"}
found = False
for status, title in groups.items():
    items = {k: v for k, v in state.items() if v.get("status") == status}
    if not items: continue
    found = True
    print(f"\n== {title}: {len(items)}")
    for page_id, item in sorted(items.items()):
        print(f"\n- {page_id}")
        comments = item.get("comments", [])
        if comments:
            last = comments[-1]
            print(f"  last comment ({last.get('date','')[:16]}"+(f", about {last['element']}" if last.get("element") else "")+"):")
            for line in last.get("text", "").splitlines(): print("    " + line)
        for key in ("needsMore", "generalNote"):
            if item.get(key): print(f"  {key}: {item[key]}")
        history = item.get("history", [])
        if history: print(f"  history: {history[-1].get('text','')} ({history[-1].get('date','')[:16]})")

# Scenario reviews, from the EchoSense checkout next to this repository.
scenario_dir = Path(os.environ.get("ECHOSENSE_SCENARIOS") or Path(__file__).resolve().parents[3] / "EchoSense/Sources/EchoSenseScenarios/Scenarios")
scenarios = []
for file in sorted(scenario_dir.glob("*.json")):
    scenarios += json.loads(file.read_text())
flagged = [s for s in scenarios if s.get("review") == "flagged"]
to_fix = [s for s in scenarios if s.get("review") == "approved" and s.get("knownIssue")]
if flagged:
    found = True
    print(f"\n== SCENARIOS FLAGGED (change the scenario from the note): {len(flagged)}")
    for s in flagged:
        print(f"\n- {s['id']} {s.get('title','')}  [{s.get('group','')}]")
        print(f"  sql: {s.get('sql','')}")
        print("  note: " + (s.get("notes") or "(no note)"))
if to_fix:
    found = True
    print(f"\n== SCENARIOS APPROVED BUT FAILING (fix EchoSense, then clear knownIssue): {len(to_fix)}")
    for s in to_fix:
        print(f"- {s['id']} {s.get('title','')}: {s['knownIssue']}")
if not found:
    print("Nothing is waiting for the agent.")
