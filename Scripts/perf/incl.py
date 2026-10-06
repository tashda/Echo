#!/usr/bin/env python3
"""incl.py <trace> t0 t1 [lo%] [hi%] [top]: inclusive main-thread ms per frame name (any module) in a window, keeping frames between lo% and hi% of busy time."""
import sys, os, re, collections, importlib.util
spec = importlib.util.spec_from_file_location("parse", os.path.join(os.path.dirname(os.path.abspath(__file__)), "parse.py")); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
trace, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
lo = float(sys.argv[4]) if len(sys.argv) > 4 else 4; hi = float(sys.argv[5]) if len(sys.argv) > 5 else 70; top = int(sys.argv[6]) if len(sys.argv) > 6 else 50
sys.argv = [sys.argv[0], trace]
trace, steps, hangs, samples = parse.main()
base = min(s[0] for s in samples)
sel = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running" and t0 <= (s[0]-base)/1e9 < t1 and s[4]]
tot = sum(s[2] for s in sel) / 1e6
inc = collections.Counter()
for s in sel:
    seen = set()
    for n, b in s[4]:
        k = re.sub(r"\s+", " ", n)[:130] + f" [{b[:14]}]"
        if k not in seen: seen.add(k); inc[k] += s[2] / 1e6
print(f"{tot:.0f} ms busy")
n = 0
for k, v in inc.most_common():
    p = 100 * v / tot
    if p < lo: break
    if p > hi: continue
    if "<deduplicated" in k or "closure #" in k and "[Echo" not in k or "thunk for" in k or "partial apply" in k: continue
    print(f"{v:6.0f} {p:4.0f}%  {k}")
    n += 1
    if n >= top: break
