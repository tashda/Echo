#!/usr/bin/env python3
"""score.py <trace>... : per labelled group, total main busy ms, window ms, longest block, #>50ms blocks."""
import sys, os, re, collections, importlib.util
spec = importlib.util.spec_from_file_location("parse", os.path.join(os.path.dirname(os.path.abspath(__file__)), "parse.py")); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
for tr in sys.argv[1:]:
    sys.argv = ["x", tr]
    trace, steps, hangs, samples = parse.main()
    main = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running"]
    groups = collections.defaultdict(lambda: [0, 0, 0, 0])
    for i, (st, label) in enumerate(steps):
        en = steps[i+1][0] if i+1 < len(steps) else st + 2e9
        name = re.sub(r"^\d+ ", "", label); name = re.sub(r"[\d\-]+$", "", name).strip()
        name = name.split(" ")[0] + " " + (name.split(" ")[1] if len(name.split(" ")) > 1 else "")
        ts = sorted(s[0] for s in main if st <= s[0] < en)
        busy = len(ts)
        runs=[]; start=None; last=None
        for t in ts:
            if start is None: start=t
            elif t-last>4e6: runs.append((last-start)/1e6+1); start=t
            last=t
        if start is not None: runs.append((last-start)/1e6+1)
        g = groups[name.strip()]; g[0]+=busy; g[1]+=(en-st)/1e6; g[2]=max(g[2],max(runs,default=0)); g[3]+=sum(1 for r in runs if r>50)
    print(f"== {os.path.basename(tr)} hangs={len(hangs)} (max {max([h[1] for h in hangs],default=0)/1e6:.0f} ms)")
    for k,(b,wms,lng,n) in groups.items(): print(f"   {k:28s} busy {b:6.0f} ms of {wms:6.0f}  longest {lng:5.0f}  >50ms x{n}")
