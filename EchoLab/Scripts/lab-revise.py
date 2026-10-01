#!/usr/bin/env python3
"""Record a new revision of a round, so the owner sees what to look for.

    EchoLab/Scripts/lab-revise.py <page-id> "<one-line summary>" ["<change>" ...] [--status Judging]

Run it every time you change a round in response to feedback. It adds a revision to
EchoLab/State/lab-state.json (the Inbox shows "Rev N" and "New since rev M", and the round's
decision panel shows a "New since your last review" card at the top), sets the status back to
`Judging`, and adds a history event. Then, in the round's code, mark anything new with
`addedIn: N` (a control, exhibit, question, or `newChoices:`) so it gets a NEW badge, and commit.
"""
import json, os, sys, tempfile
from datetime import datetime, timezone

args = [a for a in sys.argv[1:]]
status = "Judging"   # the state file spells statuses as display names
if "--status" in args:
    i = args.index("--status"); status = args[i + 1]; del args[i:i + 2]
if len(args) < 2:
    sys.exit(__doc__)
page_id, summary, changes = args[0], args[1], args[2:]
names = {"newfeedback": "New feedback", "judging": "Judging", "accepted": "Accepted", "inecho": "In Echo", "decided": "Decided"}
status = names.get(status.lower().replace(" ", ""), None) or sys.exit(f"Unknown status {status!r}. Use one of: {', '.join(names.values())}")

here = os.path.dirname(os.path.abspath(__file__))
path = os.path.join(here, "..", "State", "lab-state.json")
state = json.load(open(path)) if os.path.exists(path) else {}
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
item = state.setdefault(page_id, {"status": status, "comments": [], "history": []})
revisions = item.setdefault("revisions", [])
number = (revisions[-1]["number"] if revisions else 1) + 1
revisions.append({"number": number, "date": now, "summary": summary, "changes": changes})
item["status"] = status
item.pop("takenBy", None)  # a claim from lab-brief.py --take ends with the revision
item.setdefault("history", []).append({"date": now, "text": f"Revision {number}: {summary}"})

tmp = tempfile.NamedTemporaryFile("w", dir=os.path.dirname(path), delete=False, suffix=".tmp")
json.dump(state, tmp, indent=2, sort_keys=True); tmp.write("\n"); tmp.close()
os.replace(tmp.name, path)
print(f"Revision {number} of {page_id} recorded ({len(changes)} change(s)); status is now {status}.")
print(f"Next: mark what is new in the round's code with `addedIn: {number}`, then commit the code and EchoLab/State/lab-state.json.")
