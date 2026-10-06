#!/usr/bin/env python3
"""stepincl.py <trace> <step label substring> [lo%] [top] [grep]: inclusive main-thread ms per frame name over one step (to the next step)."""
import sys, re, collections, importlib.util
spec = importlib.util.spec_from_file_location("parse", "parse.py"); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
trace, label = sys.argv[1], sys.argv[2]
lo = float(sys.argv[3]) if len(sys.argv) > 3 else 4; top = int(sys.argv[4]) if len(sys.argv) > 4 else 45; pat = sys.argv[5] if len(sys.argv) > 5 else None
sys.argv = ["x", trace]
t, steps, hangs, samples = parse.main()
base = min(s[0] for s in samples)
i = [k for k, (tt, n) in enumerate(steps) if label in n][0]
t0 = (steps[i][0] - base) / 1e9; t1 = (steps[i + 1][0] - base) / 1e9
sel = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running" and t0 <= (s[0] - base) / 1e9 < t1 and s[4]]
tot = sum(s[2] for s in sel) / 1e6
inc = collections.Counter()
for s in sel:
    seen = set()
    for n, b in s[4]:
        k = re.sub(r"\s+", " ", n)[:120] + f" [{b[:12]}]"
        if k not in seen: seen.add(k); inc[k] += s[2] / 1e6
print(f"{steps[i][1]}: window {t1-t0:.1f}s, main thread busy {tot:.0f} ms")
n = 0
for k, v in inc.most_common():
    if 100 * v / tot < lo: break
    if "<dedup" in k or re.search(r"runApp|NSApplication|CFRunLoop|HIToolbox|DPSNext|_dispatch|dyld|\bmain\b|start \[|thunk|partial apply|closure #", k) and "[Echo" not in k: continue
    if pat and not re.search(pat, k): continue
    print(f"{v:6.0f} {100*v/tot:3.0f}%  {k}"); n += 1
    if n >= top: break
