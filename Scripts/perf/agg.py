#!/usr/bin/env python3
"""agg.py <trace> pattern...  : inclusive main-thread ms (and share of main busy) for frames containing each pattern."""
import sys, os, importlib.util
spec = importlib.util.spec_from_file_location("parse", os.path.join(os.path.dirname(os.path.abspath(__file__)), "parse.py")); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
trace = sys.argv[1]; pats = sys.argv[2:]
sys.argv = [sys.argv[0], trace]
trace, steps, hangs, samples = parse.main()
main = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running"]
import re
STEP = os.environ.get("STEP")
if STEP:
    wins = []
    for i, (st, label) in enumerate(steps):
        en = steps[i+1][0] if i+1 < len(steps) else st + 2e9
        if re.search(STEP, label): wins.append((st, en))
    main = [s for s in main if any(a <= s[0] < b for a, b in wins)]
tot = sum(s[2] for s in main) / 1e6
print(f"{os.path.basename(trace)} main busy {tot:.0f} ms")
for p in pats:
    w = sum(s[2] for s in main if any(p in n for n, b in s[4])) / 1e6
    print(f"  {w:7.0f} ms {100*w/max(tot,1):4.1f}%  {p}")
