#!/usr/bin/env python3
"""hangs.py <name>... [--min ms]: every hang of a trace with the step it fell in and what the main thread was doing:
the Echo functions (and the system frame under them) with the most inclusive time inside the hang."""
import collections, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
PERF = os.environ.get("PERF_DIR", HERE)
import parse
names = [a for a in sys.argv[1:] if not a.startswith("--")]
minimum = float(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 400
names = [n for n in names if n != str(minimum).rstrip("0").rstrip(".")]
skip = re.compile(r"^(thunk for|partial apply|protocol witness|reabstraction|closure #|implicit closure|specialized static EchoApp|static EchoApp|__debug_main|merged |outlined|\$s|@objc|static App\.|runApp)|\.body\.getter|\.body$|\.getter$|\.setter$|\.modify$")
for name in names:
    sys.argv = ["x", os.path.join(PERF, "traces", f"{name}.trace")]
    trace, steps, hangs, samples = parse.main()
    base = min(s[0] for s in samples)
    main = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running"]
    seen = set()
    for start, dur, kind in sorted(hangs):
        if dur / 1e6 < minimum or (start, dur) in seen: continue
        seen.add((start, dur))
        label = next((l for t, l in reversed(steps) if t <= start), "-")
        inside = [s for s in main if start <= s[0] < start + dur]
        incl, leaf = collections.Counter(), collections.Counter()
        for s in inside:
            w = s[2] / 1e6; used = set()
            for n, b in s[4]:
                if parse.is_app(b):
                    k = re.sub(r"\s+", " ", n)[:90]
                    if not skip.search(k) and k not in used: used.add(k); incl[k] += w
            if s[4]: leaf[re.sub(r"\s+", " ", s[4][0][0])[:70] + f" [{s[4][0][1]}]"] += w
        print(f"== {name}: {kind} {dur / 1e6:.0f} ms at {(start - base) / 1e9:.1f}s, in step '{label}' ({sum(s[2] for s in inside) / 1e6:.0f} ms busy)")
        for k, v in incl.most_common(6): print(f"     {v:6.0f}  {k}")
        print("     leaf:", "; ".join(f"{v:.0f} {k}" for k, v in leaf.most_common(3)))
