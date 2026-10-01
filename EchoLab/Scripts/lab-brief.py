#!/usr/bin/env python3
"""Everything an agent needs to take one Echo Labs round, in one printout.

    python3 EchoLab/Scripts/lab-brief.py <round>            # read the brief
    python3 EchoLab/Scripts/lab-brief.py <round> --take     # read it and take the round
    python3 EchoLab/Scripts/lab-brief.py <round> --take "Kenneth's second agent"

<round> is a page id (ongoing.tab-overview-look-r35), a round number as Echo Labs shows it
(#35.2, 35.2 or 35 for a round with one page), or a unique part of a page id (tab-overview-look).

The owner hands rounds to agents with Echo Labs' "Copy for an agent" button, which copies a
prompt that runs this script. Any agent, in any session, can then do the work: the brief prints
what was asked, the owner's answers (picks, notes, comments, "needs more options"), where the
round's code and its area's As built page live, and the steps for the round's status
(New feedback: revise it; Accepted: build it into Echo; Decided: freeze it).

--take records in EchoLab/State/lab-state.json that an agent is working on the round, so
lab-inbox.py tells other agents to leave it. The claim lapses by itself when the status changes
(lab-revise.py, lab-status.py, or the owner in Echo Labs). Commit the state file with your work.
"""
import json, os, re, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
REPO = LAB.parent
SRC = LAB / "Sources" / "EchoLab"
STATE = LAB / "State" / "lab-state.json"

AREA_FOLDERS = {
    "foundations": "Foundations", "explorer-tree": "ExplorerTree", "tabs": "Tabs", "tool-tabs": "ToolTabs",
    "window": "Window", "editor": "Editor", "footer-results": "FooterResults", "inspector": "Inspector",
    "connections": "Connections", "echosense": "EchoSense", "notifications": "Notifications",
}


def swift_string(s):
    return s.encode().decode("unicode_escape") if "\\" in s else s


def rounds():
    """LabRounds.all, in file order (newest first)."""
    text = (SRC / "Rounds" / "LabRounds.swift").read_text()
    pattern = re.compile(
        r'Info\(id: "([^"]+)", label: "([^"]+)", title: "((?:[^"\\]|\\.)*)", date: "([^"]*)",\s*'
        r'asked: "((?:[^"\\]|\\.)*)",\s*outcome: "((?:[^"\\]|\\.)*)",\s*pageIDs: \[([^\]]*)\]', re.S)
    out = []
    for m in pattern.finditer(text):
        out.append({"id": m[1], "label": m[2], "title": swift_string(m[3]), "date": m[4], "asked": swift_string(m[5]),
                    "outcome": swift_string(m[6]), "pages": re.findall(r'"([^"]+)"', m[7])})
    return out


def tag(page_id, all_rounds):
    """The number Echo Labs shows (#35, #35.2): pages of entries that share a label, oldest first."""
    info = next((r for r in all_rounds if page_id in r["pages"]), None)
    if not info: return None
    m = re.match(r"Rounds? (\d+)", info["label"])
    if not m: return None
    siblings = [p for r in reversed([r for r in all_rounds if r["label"] == info["label"]]) for p in r["pages"]]
    return f"#{m[1]}" if len(siblings) < 2 else f"#{m[1]}.{siblings.index(page_id) + 1}"


def pages():
    """Every round page registered with LabPage.round, with its title, status, summary and spec."""
    out = {}
    for file in [SRC / "Ongoing" / "OngoingPages.swift", *sorted((SRC / "Ported").glob("*.swift"))]:
        text = file.read_text()
        for m in re.finditer(r'LabPage\.round\(\s*id: "([^"]+)",(.*?)spec: (\w+)\.spec\)', text, re.S):
            body = m[2]
            get = lambda key: (re.search(key + r': "((?:[^"\\]|\\.)*)"', body) or [None, ""])[1]
            status = (re.search(r"status: \.(\w+)", body) or [None, "judging"])[1]
            out[m[1]] = {"title": swift_string(get("title")), "group": get("group"), "summary": swift_string(get("summary")),
                         "status": status, "spec": m[3], "registered": str(file.relative_to(REPO))}
    return out


def area_of(page_id, group):
    text = (SRC / "Shell" / "LabAreas.swift").read_text()
    m = re.search(rf'"{re.escape(page_id)}": "([\w-]+)"', text)
    if m: return m[1]
    titles = {"Foundations": "foundations", "Explorer tree": "explorer-tree", "Tabs": "tabs", "Tool tabs": "tool-tabs",
              "Window and cards": "window", "Editor and running": "editor", "Footer and results": "footer-results",
              "Inspector": "inspector", "Connections": "connections", "EchoSense": "echosense", "Notifications": "notifications"}
    return titles.get(group)


def spec_files(spec):
    """The folder of the file that declares `enum <spec>`, and every file in it."""
    for file in SRC.rglob("*.swift"):
        if re.search(rf"\benum {re.escape(spec)}\b", file.read_text()):
            return file, sorted(file.parent.glob("*.swift"))
    return None, []


def resolve(query, all_pages, all_rounds):
    if query in all_pages: return query
    q = query.lstrip("#")
    tags = {tag(pid, all_rounds): pid for pid in all_pages}
    if f"#{q}" in tags: return tags[f"#{q}"]
    hits = [pid for pid in all_pages if q in pid]
    if len(hits) == 1: return hits[0]
    if hits: sys.exit(f"'{query}' matches several rounds:\n  " + "\n  ".join(f"{tag(h, all_rounds) or ''} {h}" for h in hits))
    sys.exit(f"No round matches '{query}'. Give a page id, a number like 35.2, or part of a page id.")


STATUS_NAMES = {"judging": "Judging", "newFeedback": "New feedback", "accepted": "Accepted", "inEcho": "In Echo", "decided": "Decided"}


def steps(status, page_id, area_folder, round_file):
    lab = "EchoLab/Scripts"
    area = area_folder or "<Area>"
    where = round_file or "the round's file"
    if status == "Judging":
        return [
            "The owner is still judging this round: there is nothing to build yet.",
            "If the owner asked you to change the round anyway, change it, record it with",
            f"  python3 {lab}/lab-revise.py {page_id} \"what changed\" \"New option: …\" (mark additions `addedIn: N`),",
            f"  build the lab ({lab}/open-lab.sh --no-launch) and commit only your paths.",
        ]
    if status == "New feedback":
        return [
            "The owner sent feedback. Act on every comment, note and \"needs more options\" below.",
            f"1. Change the round in {where}. Keep the old options; add new ones and mark them `addedIn: N`",
            "   (N = the next revision). Treat notes as instructions. Follow EchoLab/HOW_TO_WRITE_A_ROUND.md:",
            "   every new choice carries your recommendation and why; Echo today stays the first exhibit.",
            f"2. Record the revision: python3 {lab}/lab-revise.py {page_id} \"one-line summary\" \"change\" …",
            f"3. Build the lab: {lab}/open-lab.sh --no-launch (compile check only; no tests for lab pages).",
            "4. Commit only your paths (git commit -- <paths> EchoLab/State/lab-state.json), then tell the owner",
            "   what to look at. The owner's Raycast build only sees what is committed.",
        ]
    if status == "Accepted":
        return [
            "The owner accepted this round. Build the picks below into Echo.",
            f"1. Before touching Echo: python3 {lab}/verify-labs.py {area}. Fix any DRIFT in the As built page first",
            f"   (values from the code), then python3 {lab}/verify-labs.py --stamp {area}.",
            "2. Record the verdict: an entry at the top of Design/decisions.md, the rule file under Design/ marked",
            "   Decided, and a task in Design/plan.md.",
            f"3. If the round has a `conformance:`, capture the accepted reference first:",
            f"   python3 {lab}/verify-round.py {page_id} --reference (commit it).",
            "4. Build it into Echo following AGENTS.md: design tokens only, file size limits, Swift 6 concurrency rules,",
            "   XcodeBuildMCP build_macos (fix errors in files you changed only), tests for any logic.",
            "   A pick that conflicts with what Echo Labs records elsewhere: ask the owner (AskUserQuestion).",
            f"5. With a conformance: python3 {lab}/verify-round.py {page_id} --app <Debug Echo.app>; it must pass or",
            "   each difference must be explained in the status note below.",
            f"6. Trim the round page to the chosen option, and update the {area} As built page so it says what Echo",
            f"   does now; stamp it (verify-labs.py --stamp {area}).",
            f"7. python3 {lab}/lab-status.py {page_id} \"In Echo\" \"Built into Echo: what changed (commit)\"",
            "8. Commit only your paths, then ask the owner to check it in the running app.",
        ]
    if status == "In Echo":
        return [
            "Built into Echo; the owner has not confirmed it in the running app yet. Nothing to do unless the owner",
            "reopens it with feedback (it then shows as New feedback).",
        ]
    if status == "Decided":
        return [
            "The owner confirmed it in the running app. Freeze it (AGENTS.md, Echo Labs workflow step 3):",
            "1. Move the page's files to EchoLab/Sources/EchoLab/Decided/Library/<Slug>/ and add <Slug>Decision.swift",
            "   with a LabDecision (question, reasoning including why each loser lost, shipped links, options).",
            "2. Register it in DecidedPages.library, remove the page from OngoingPages, update LabRounds.all's outcome,",
            "   and add a one-line \"confirmed\" note to Design/decisions.md.",
            f"3. Update the {area} As built page and Spec in the same change; stamp it.",
            "4. Build the lab and commit only your paths.",
        ]
    return [f"Unknown status {status!r}."]

FAST = LAB / "State" / "fast-rounds"


def fast_brief(query, take, force):
    """A fast round (State/fast-rounds/<slug>.json): text only; the brief is its file and the owner's words."""
    slug = query.removeprefix("fast.")
    file = FAST / f"{slug}.json"
    if not file.exists():
        hits = [f for f in FAST.glob("*.json") if slug in f.stem]
        if len(hits) != 1: sys.exit(f"No fast round matches '{query}'. Files: " + ", ".join(f.stem for f in FAST.glob("*.json")))
        file = hits[0]
    page_id = f"fast.{file.stem}"
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    item = state.get(page_id, {})
    status = item.get("status") or "Judging"
    claim = item.get("takenBy")
    if take:
        if claim and claim.get("status") == status and not force:
            sys.exit(f"{page_id} was taken by {claim.get('agent')} while {status}. Ask the owner, or pass --force.")
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        entry = state.setdefault(page_id, {"status": status, "comments": [], "history": []})
        entry["status"] = status
        entry["takenBy"] = {"agent": take, "date": now, "status": status}
        entry.setdefault("history", []).append({"date": now, "text": f"Taken by {take}"})
        tmp = tempfile.NamedTemporaryFile("w", dir=STATE.parent, delete=False, suffix=".tmp")
        json.dump(state, tmp, indent=2, sort_keys=True); tmp.write("\n"); tmp.close()
        os.replace(tmp.name, STATE)
        item = entry
    data = json.loads(file.read_text())
    print("=" * 78); print(f"ECHO LABS FAST ROUND  {data.get('title', '')}"); print("=" * 78)
    print(f"Page id: {page_id}\nStatus:  {status}\nFile:    {file.relative_to(REPO)}\nArea:    {data.get('area', '')}")
    print(f"\nWhat the owner said:\n  {data.get('feedback', '')}")
    if data.get("summary"): print(f"\nYour analysis, in short:\n  {data['summary']}")
    for sec in data.get("analysis", []): print(f"\n[{sec.get('heading')}]\n  {sec.get('body')}")
    if data.get("recommendation"): print(f"\nRecommendation:\n  {data['recommendation']}")
    for c in data.get("changes", []): print(f"  - {c}")
    for c in item.get("comments", []):
        print(f"\nOwner's note ({c.get('date','')[:16]}):\n  " + c.get("text", "").replace("\n", "\n  "))
    lab = "EchoLab/Scripts"
    print("\nWhat to do for this status:")
    if status == "New feedback":
        print(f"  The owner rejected or commented: read the note above, rewrite the analysis in {file.relative_to(REPO)}")
        print("  (Echo Labs shows the change within a second, no rebuild), then")
        print(f"  python3 {lab}/lab-status.py {page_id} Judging \"Revised: <what changed>\" and commit your paths.")
    elif status == "Accepted":
        print("  The owner accepted the analysis (their note, if any, is above). Build it into Echo as described under")
        print("  'changes'. Before you touch Echo, look the area up in Echo Labs (As built page, rounds) as CLAUDE.md says;")
        print("  if the change differs from what Echo Labs records, ask the owner first. Then update the area's As built page,")
        print(f"  and set it: python3 {lab}/lab-status.py {page_id} \"In Echo\" \"Built into Echo: ...\" --summary \"...\" --check \"...\"")
    elif status == "In Echo":
        print("  Built; waiting for the owner to check it in the running app. Nothing to do.")
    elif status == "Judging":
        print("  Waiting for the owner's Accept or Reject in the Inbox. Nothing to do.")
    else:
        print("  Decided: nothing to do. A fast round is not frozen into the library.")


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"): sys.exit(__doc__)
    take = None
    if "--take" in args:
        i = args.index("--take")
        named = i + 1 < len(args) and not args[i + 1].startswith("--") and i > 0
        take = args[i + 1] if named else "an agent"
        del args[i:i + (2 if named else 1)]
    force = "--force" in args
    args = [a for a in args if a != "--force"]

    if args[0].startswith("fast"):
        return fast_brief(args[0], take, force)

    all_rounds, all_pages = rounds(), pages()
    page_id = resolve(args[0], all_pages, all_rounds)
    page = all_pages[page_id]
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    item = state.get(page_id, {})
    status = item.get("status") or STATUS_NAMES.get(page["status"], page["status"])
    info = next((r for r in all_rounds if page_id in r["pages"]), None)
    area = area_of(page_id, page["group"])
    area_folder = AREA_FOLDERS.get(area or "")
    round_file, files = spec_files(page["spec"])
    number = tag(page_id, all_rounds) or ""

    # Claims
    claim = item.get("takenBy")
    claim_live = claim and claim.get("status") == status
    if take:
        if claim_live and not force:
            sys.exit(f"{number} {page_id} was taken by {claim.get('agent')} on {claim.get('date','')[:16]} while {status}.\n"
                     "Ask the owner before working on it, or pass --force if the owner gave it to you.")
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        entry = state.setdefault(page_id, {"status": status, "comments": [], "history": []})
        entry["status"] = status
        entry["takenBy"] = {"agent": take, "date": now, "status": status}
        entry.setdefault("history", []).append({"date": now, "text": f"Taken by {take}"})
        tmp = tempfile.NamedTemporaryFile("w", dir=STATE.parent, delete=False, suffix=".tmp")
        json.dump(state, tmp, indent=2, sort_keys=True); tmp.write("\n"); tmp.close()
        os.replace(tmp.name, STATE)
        item, claim, claim_live = entry, entry["takenBy"], True

    rule = "=" * 78
    print(rule)
    print(f"ECHO LABS ROUND {number}  {page['title']}".strip())
    print(rule)
    print(f"Page id:   {page_id}")
    print(f"Status:    {status}")
    print(f"Area:      {area or 'none'}" + (f"  (As built: EchoLab/Sources/EchoLab/Areas/{area_folder}/)" if area_folder else ""))
    if claim_live:
        print(f"Taken by:  {claim.get('agent')} since {claim.get('date','')[:16]}" + ("  ← you" if take else "  (another agent: ask the owner before you work on it)"))
    if info:
        print(f"Round:     {info['label']} · {info['title']} · {info['date']}")
        print(f"\nWhat the owner asked:\n  {info['asked']}")
        print(f"\nWhere it stands (LabRounds.all):\n  {info['outcome']}")
    if page["summary"]:
        print(f"\nThis page:\n  {page['summary']}")

    print("\nCode:")
    print(f"  registered in {page['registered']} ({page['spec']}.spec)")
    for f in files:
        print(f"  {f.relative_to(REPO)}")

    print("\n" + "-" * 78 + "\nTHE OWNER'S ANSWERS\n" + "-" * 78)
    if not item or not any(item.get(k) for k in ("picks", "comments", "pickNotes", "optionNotes", "verdicts", "needsMore", "generalNote")):
        print("  Nothing yet: the owner has not answered this round.")
    comments = item.get("comments", [])
    for n, c in enumerate(comments):
        about = f", about {c['element']}" if c.get("element") else ""
        latest = "  ← the latest: this is what counts" if n == len(comments) - 1 and len(comments) > 1 else ""
        print(f"\n  Comment ({c.get('date','')[:16]}{about}):{latest}")
        for line in c.get("text", "").splitlines(): print("    " + line)
    if item.get("picks"):
        print("\n  Current picks (topic → choice):")
        for k, v in sorted(item["picks"].items()): print(f"    {k} → {v}")
    for key, title in (("pickNotes", "Notes on topics"), ("optionNotes", "Notes on options (topic/option)"), ("verdicts", "Maybe / No (topic/option)")):
        if item.get(key):
            print(f"\n  {title}:")
            for k, v in sorted(item[key].items()): print(f"    {k}: {v}")
    if item.get("needsMore"):
        print(f"\n  NEEDS MORE OPTIONS (add new choices, keep the old ones): {', '.join(item['needsMore'])}")
    if item.get("generalNote"):
        print(f"\n  General note: {item['generalNote']}")
    if item.get("revisions"):
        print("\n  Revisions:")
        for r in item["revisions"]: print(f"    Rev {r['number']} ({r.get('date','')[:10]}): {r['summary']}")
    if item.get("history"):
        print("\n  History:")
        for h in item["history"][-8:]: print(f"    {h.get('date','')[:16]}  {h.get('text','')}")

    print("\n" + "-" * 78 + f"\nWHAT TO DO NOW ({status})\n" + "-" * 78)
    rel = str(round_file.relative_to(REPO)) if round_file else None
    for line in steps(status, page_id, area_folder, rel): print("  " + line)
    print("\nRules that always apply: read AGENTS.md (project rules, Echo Labs workflow) and")
    print("EchoLab/HOW_TO_WRITE_A_ROUND.md. Other agents work in this checkout at the same time: never")
    print("commit, revert or reformat files you did not change; commit with `git commit -- <your paths>`.")
    if not take and not claim_live and status in ("New feedback", "Accepted", "Decided"):
        print(f"\nTo take it: python3 EchoLab/Scripts/lab-brief.py {page_id} --take \"<who you are>\"")


if __name__ == "__main__":
    main()
