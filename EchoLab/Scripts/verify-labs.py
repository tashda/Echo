#!/usr/bin/env python3
"""Checks that what Echo Labs says about Echo still matches Echo.

    python3 EchoLab/Scripts/verify-labs.py [area-dir ...]      # e.g. Tabs Window; default: all
    python3 EchoLab/Scripts/verify-labs.py --stale-only        # just the areas whose code moved
    python3 EchoLab/Scripts/verify-labs.py --stamp Tabs        # after you checked the page against the code

`--stamp` records today's date and the current commit as the area's verification (`commit:`
in its As built page). Only stamp an area after reading the drifted commits and updating the
page (As built rows and spec elements) to match Echo; the stamp is a claim that it does.

For every area (EchoLab/Sources/EchoLab/Areas/<Area>/) it reports:
  1. MISSING FILE    a code path the spec or As built page names that does not exist.
  2. MISSING TOKEN   a `token:` the page names that is not defined anywhere in Echo or its packages.
  3. DRIFT           commits that touched the area's code files after the page's verification commit.
                     These are the changes the page may not say yet: read them, fix the page, and
                     stamp it again (`verification: commit:` in the area file).
Exit status 1 when anything is missing (drift alone is a warning).
"""
import re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AREAS = ROOT / "EchoLab/Sources/EchoLab/Areas"
CODE_DIRS = [ROOT / "Echo", ROOT / "Packages", ROOT / "EchoLab/Packages"]
PATH_PREFIXES = ("Echo/", "Packages/", "EchoSense/", "Design/")

def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True).stdout

def read_area(directory: Path):
    return {p: p.read_text() for p in sorted(directory.glob("*.swift"))}

def constants(text):
    return dict(re.findall(r'let (\w+) = "([^"]+)"', text))

def paths_in(text):
    consts = constants(text)
    found = set()
    for value in consts.values():
        if value.startswith(PATH_PREFIXES): found.add(value)
    for name, suffix in re.findall(r'(\w+) \+ "([^"]*)"', text):
        if name in consts and consts[name].startswith(PATH_PREFIXES): found.add(consts[name] + suffix)
    for literal in re.findall(r'"((?:Echo|Packages|EchoSense|Design)/[^"]+)"', text):
        found.add(literal)
    return found

def exists(path: str):
    if "..." in path or path.endswith("/") is False and "*" in path:
        pattern = path.replace("...", "*")
        return bool(list(ROOT.glob(pattern))) if "*" in pattern else True
    clean = path.split(" ")[0].split("›")[0]
    return (ROOT / clean).exists()

def token_defined(token, cache={}):
    if token in cache: return cache[token]
    result = subprocess.run(["grep", "-rqw", "--include=*.swift", token, *[str(d) for d in CODE_DIRS if d.exists()]], capture_output=True)
    cache[token] = result.returncode == 0
    return cache[token]

def tokens_in(text):
    out = []
    for raw in re.findall(r'token: "([^"]+)"', text):
        for part in re.split(r" / |; ", raw):
            part = re.sub(r"\(.*?\)", "", part).strip()
            if re.fullmatch(r"[A-Za-z_][\w.]*", part) and ("." in part or re.search(r"[a-z][A-Z]", part)):
                out.append(part)
    return out

def verification_commit(text):
    m = re.search(r'commit: "([^"]+)"', text)
    if not m: return None
    h = re.search(r"\b[0-9a-f]{7,40}\b", m.group(1))
    return h.group(0) if h else None

def stamp(directory: Path):
    import datetime
    sha = git("rev-parse", "--short", "HEAD").strip()
    for path in directory.glob("*Area.swift"):
        text = path.read_text()
        new = re.sub(r'commit: "[^"]*", date: "[^"]*"', f'commit: "{sha}", date: "{datetime.date.today().isoformat()}"', text, count=1)
        if new != text:
            path.write_text(new)
            print(f"{directory.name}: stamped {sha}")
            return
    print(f"{directory.name}: no verification line found in *Area.swift")

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--stamp" in sys.argv:
        for a in args: stamp(AREAS / a)
        return
    stale_only = "--stale-only" in sys.argv
    directories = [AREAS / a for a in args] if args else sorted(d for d in AREAS.iterdir() if d.is_dir())
    problems = 0
    for directory in directories:
        files = read_area(directory)
        text = "\n".join(files.values())
        paths = sorted(paths_in(text))
        lines = []
        for p in paths:
            if not exists(p): lines.append(f"  MISSING FILE   {p}"); problems += 1
        for t in sorted(set(tokens_in(text))):
            if not token_defined(t.split(".")[-1]): lines.append(f"  MISSING TOKEN  {t}"); problems += 1
        commit = verification_commit(text)
        real = [p for p in paths if exists(p) and (ROOT / p.split(" ")[0]).exists()]
        if commit and real:
            log = git("log", "--oneline", f"{commit}..HEAD", "--", *[p.split(" ")[0] for p in real]).strip()
            if log:
                lines.append(f"  DRIFT since {commit}:")
                lines += [f"    {l}" for l in log.splitlines()]
        elif not commit:
            lines.append("  NOT STAMPED    no verification commit")
        if lines or not stale_only:
            print(f"{directory.name}: " + ("ok" if not lines else ""))
            print("\n".join(lines))
    sys.exit(1 if problems else 0)

main()
