#!/usr/bin/env python3
"""Move a round to a new status, with a history note, as an agent.

    python3 EchoLab/Scripts/lab-status.py <page-id> "In Echo" "Built into Echo: the header tint (commit abc123)"

For "In Echo", say what the owner should check and what it looks like; the Inbox shows it with
Accept and Reject buttons:

    ... "In Echo" "Built into Echo: ..." --summary "One line: what changed" \\
        --check "Open a table: double-click opens its data" --check "..." --shot /path/to/screenshot.png

Statuses: Judging, New feedback, Accepted, In Echo, Decided (the owner moves rounds to Accepted
and Decided; agents normally set In Echo after building, or Judging after a revision, which
lab-revise.py already does). The change releases any claim made with lab-brief.py --take.
Commit EchoLab/State/lab-state.json with your work.
"""
import json, os, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path

args, checks, shots, summary, i = [], [], [], "", 1
while i < len(sys.argv):
    a = sys.argv[i]
    if a == "--check" and i + 1 < len(sys.argv): checks.append(sys.argv[i + 1]); i += 2
    elif a == "--shot" and i + 1 < len(sys.argv): shots.append(sys.argv[i + 1]); i += 2
    elif a == "--summary" and i + 1 < len(sys.argv): summary = sys.argv[i + 1]; i += 2
    else:
        args.append(a); i += 1
if len(args) < 2: sys.exit(__doc__)
page_id, wanted = args[0], args[1]
note = args[2] if len(args) > 2 else None
names = {"newfeedback": "New feedback", "judging": "Judging", "accepted": "Accepted", "inecho": "In Echo", "decided": "Decided"}
status = names.get(wanted.lower().replace(" ", "")) or sys.exit(f"Unknown status {wanted!r}. Use one of: {', '.join(names.values())}")

path = Path(__file__).resolve().parents[1] / "State" / "lab-state.json"
state = json.loads(path.read_text()) if path.exists() else {}
now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
item = state.setdefault(page_id, {"status": status, "comments": [], "history": []})
item["status"] = status
item.pop("takenBy", None)
if item.get("revisions"):
    item["reviewedRevision"] = item["revisions"][-1]["number"]
if status == "In Echo" and (checks or shots or summary):
    import shutil
    shot_dir = path.parent / "shots" / page_id
    names = []
    for n, src in enumerate(shots, 1):
        shot_dir.mkdir(parents=True, exist_ok=True)
        name = f"{n}{Path(src).suffix or '.png'}"
        shutil.copyfile(src, shot_dir / name); names.append(name)
    item["verification"] = {"summary": summary, "checks": checks, "shots": names, "done": []}
elif status != "In Echo":
    item.pop("verification", None)
item.setdefault("history", []).append({"date": now, "text": note or {"In Echo": "Built into Echo"}.get(status, status)})

tmp = tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, suffix=".tmp")
json.dump(state, tmp, indent=2, sort_keys=True); tmp.write("\n"); tmp.close()
os.replace(tmp.name, path)
print(f"{page_id} is now {status}. Commit EchoLab/State/lab-state.json with your work.")
