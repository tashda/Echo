#!/usr/bin/env python3
"""Write a fast round: the owner's feedback and your analysis of it, text only, no build.

    python3 EchoLab/Scripts/new-fast-round.py --slug tab-close-hover --title "Close button on hover" \\
        --area tabs --feedback "The owner's words, as they said them." \\
        --summary "One or two sentences: what is going on and what you suggest." \\
        --analysis "What Echo Labs says today" "TABS-2.7 and round 11 say ..." \\
        --analysis "What the code does" "TabCloseButton ... (file:line)" \\
        --recommendation "What you would do, and why." \\
        --change "TabItemView: show the close button on hover only" --change "Update the Tabs As built page"

Writes EchoLab/State/fast-rounds/<slug>.json. Echo Labs reads that folder while it runs, so the
fast round shows in the Inbox ("For you") within a second, with Accept, Reject and a note, and
needs no rebuild. Commit the file. Running it again with the same slug rewrites the file (use
that to revise after a Reject, then `lab-status.py fast.<slug> Judging "Revised: ..."`).
Areas: foundations, explorer-tree, tabs, tool-tabs, window, editor, footer-results, inspector,
connections, echosense, notifications. --analysis and --change may be repeated; text takes inline
Markdown (**bold**, `code`). Optional: --date YYYY-MM-DD (default today).

Write the analysis from the code and Echo Labs (the area's As built page, its rounds, `verify-labs.py`),
not from memory. Say what you checked. A fast round is words only: if the answer needs a picture,
make a normal round (new-round.py) instead.
"""
import argparse, json, sys
from datetime import date
from pathlib import Path

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("--slug", required=True)
ap.add_argument("--title", required=True)
ap.add_argument("--area", default="")
ap.add_argument("--feedback", required=True)
ap.add_argument("--summary", default="")
ap.add_argument("--analysis", nargs=2, action="append", default=[], metavar=("HEADING", "BODY"))
ap.add_argument("--recommendation", default="")
ap.add_argument("--change", action="append", default=[])
ap.add_argument("--date", default=date.today().isoformat())
a = ap.parse_args()

areas = {"foundations", "explorer-tree", "tabs", "tool-tabs", "window", "editor", "footer-results", "inspector",
         "connections", "echosense", "notifications"}
if a.area and a.area not in areas: sys.exit(f"Unknown area '{a.area}'. Use one of: {', '.join(sorted(areas))}")
if not a.summary: sys.exit("Give a --summary: the verdict in a sentence or two.")
folder = Path(__file__).resolve().parents[1] / "State" / "fast-rounds"
folder.mkdir(parents=True, exist_ok=True)
file = folder / f"{a.slug}.json"
data = {"title": a.title, "area": a.area, "date": a.date, "feedback": a.feedback, "summary": a.summary,
        "analysis": [{"heading": h, "body": b} for h, b in a.analysis], "recommendation": a.recommendation, "changes": a.change}
file.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print(f"Wrote {file}\nPage id: fast.{a.slug}. It is in the Inbox under 'For you' (no rebuild). Commit the file.")
