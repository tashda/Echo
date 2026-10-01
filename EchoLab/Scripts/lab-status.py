#!/usr/bin/env python3
"""Move a round to a new status, with a history note, as an agent.

    python3 EchoLab/Scripts/lab-status.py <page-id> "In Echo" "Built into Echo: the header tint (commit abc123)"

Statuses: Judging, New feedback, Accepted, In Echo, Decided (the owner moves rounds to Accepted
and Decided; agents normally set In Echo after building, or Judging after a revision, which
lab-revise.py already does). The change releases any claim made with lab-brief.py --take.
Commit EchoLab/State/lab-state.json with your work.
"""
import json, os, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path

if len(sys.argv) < 3: sys.exit(__doc__)
page_id, wanted = sys.argv[1], sys.argv[2]
note = sys.argv[3] if len(sys.argv) > 3 else None
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
item.setdefault("history", []).append({"date": now, "text": note or {"In Echo": "Built into Echo"}.get(status, status)})

tmp = tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, suffix=".tmp")
json.dump(state, tmp, indent=2, sort_keys=True); tmp.write("\n"); tmp.close()
os.replace(tmp.name, path)
print(f"{page_id} is now {status}. Commit EchoLab/State/lab-state.json with your work.")
