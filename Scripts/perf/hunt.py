#!/usr/bin/env python3
"""hunt.py <trace>... : the Echo functions with the most inclusive main-thread time (view-body wrappers, thunks and closures left out)."""
import sys, os, re, collections, importlib.util
spec = importlib.util.spec_from_file_location("parse", os.path.join(os.path.dirname(os.path.abspath(__file__)), "parse.py")); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
skip = re.compile(r"^(thunk for|partial apply|protocol witness|reabstraction|closure #|implicit closure|specialized static EchoApp|static EchoApp|__debug_main|merged |outlined|\$s|@objc|static App\.|runApp|AppDirector.runAutomation|SQLTextView.insertText)|\.body\.getter|\.body$|Collection\.map|Sequence\.|\.modify$|\.setter$|\.getter$|withMutation|ForEach")
agg = collections.Counter()
for tr in sys.argv[1:]:
    sys.argv = ["x", tr]
    trace, steps, hangs, samples = parse.main()
    main = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running"]
    tot = sum(s[2] for s in main) / 1e6
    inc = collections.Counter()
    for s in main:
        seen = set()
        for n, b in s[4]:
            if not parse.is_app(b): continue
            k = re.sub(r"\s+", " ", n)[:110]
            if skip.search(k) or k in seen: continue
            seen.add(k); inc[k] += s[2] / 1e6
    print(f"== {os.path.basename(tr)} main busy {tot:.0f} ms")
    for k, v in inc.most_common(14): print(f"  {v:6.0f} {100*v/tot:4.1f}%  {k}")
