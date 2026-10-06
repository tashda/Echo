#!/usr/bin/env python3
"""diffwin.py <traceA> <traceB> <step label substring> [top]: inclusive main-thread ms per frame name in the step's window (the step to the next one), A against B, biggest difference first."""
import sys, re, collections, importlib.util
spec = importlib.util.spec_from_file_location("parse", "parse.py"); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
a, b, label = sys.argv[1], sys.argv[2], sys.argv[3]
top = int(sys.argv[4]) if len(sys.argv) > 4 else 40
def inclusive(path):
    sys.argv = ["x", path]
    trace, steps, hangs, samples = parse.main()
    base = min(s[0] for s in samples)
    t0 = t1 = None
    for i, (t, name) in enumerate(steps):
        if label in name:
            t0 = (t - base) / 1e9 if t > 1e12 else t / 1e9
            t1 = ((steps[i + 1][0] - base) / 1e9 if steps[i + 1][0] > 1e12 else steps[i + 1][0] / 1e9) if i + 1 < len(steps) else t0 + 5
            break
    sel = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running" and t0 <= (s[0] - base) / 1e9 < t1 and s[4]]
    inc = collections.Counter()
    for s in sel:
        seen = set()
        for n, bn in s[4]:
            k = re.sub(r"\s+", " ", n)[:110] + f" [{bn[:12]}]"
            if k not in seen: seen.add(k); inc[k] += s[2] / 1e6
    return inc, sum(s[2] for s in sel) / 1e6, t1 - t0
A, ta, wa = inclusive(a); B, tb, wb = inclusive(b)
print(f"A busy {ta:.0f} ms in {wa:.1f}s, B busy {tb:.0f} ms in {wb:.1f}s")
rows = sorted(((A[k] - B.get(k, 0), A[k], B.get(k, 0), k) for k in A), reverse=True)
for d, x, y, k in rows[:top]:
    if "<dedup" in k: continue
    print(f"{d:6.0f} {x:6.0f} {y:6.0f}  {k}")
