#!/usr/bin/env python3
"""under.py <trace> <step substring> <regex>...: main-thread ms in the step with the regex anywhere in the stack, and the step's busy total."""
import sys, re, importlib.util
spec = importlib.util.spec_from_file_location("parse", "parse.py"); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
trace, label, pats = sys.argv[1], sys.argv[2], sys.argv[3:]
sys.argv = ["x", trace]
t, steps, hangs, samples = parse.main()
base = min(s[0] for s in samples)
i = [k for k, (tt, n) in enumerate(steps) if label in n][0]
t0 = (steps[i][0] - base) / 1e9; t1 = (steps[i + 1][0] - base) / 1e9
sel = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running" and t0 <= (s[0] - base) / 1e9 < t1 and s[4]]
print(f"{trace}: {t1-t0:.1f}s window, busy {sum(s[2] for s in sel)/1e6:.0f} ms")
for p in pats:
    print(f"  {sum(s[2] for s in sel if any(re.search(p, n) for n, b in s[4]))/1e6:6.0f} ms  {p}")
