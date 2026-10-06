#!/usr/bin/env python3
"""overview.py <name>...: one block per traced scenario: hangs, the worst steps, threads, memory, network, server work."""
import csv, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
PERF = os.environ.get("PERF_DIR", HERE)
import parse
for name in sys.argv[1:]:
    path = os.path.join(PERF, "traces", f"{name}.trace")
    if not os.path.exists(path): continue
    sys.argv = ["x", path]
    trace, steps, hangs, samples = parse.main()
    base = min(s[0] for s in samples)
    run = [s for s in samples if s[3] == "Running"]
    main = [s for s in run if s[1].startswith("Main Thread")]
    seen, hang_list = set(), []
    for s, d, ty in sorted(hangs):
        if (s, d) not in seen: seen.add((s, d)); hang_list.append((d / 1e6, ty, (s - base) / 1e9))
    # worst stretches of main-thread work per step
    rows = []
    for i, (st, label) in enumerate(steps):
        en = steps[i + 1][0] if i + 1 < len(steps) else st + 2e9
        ts = sorted(s[0] for s in main if st <= s[0] < en)
        runs, start, last = [], None, None
        for t in ts:
            if start is None: start = t
            elif t - last > 4e6: runs.append((last - start) / 1e6 + 1); start = t
            last = t
        if start is not None: runs.append((last - start) / 1e6 + 1)
        rows.append((max(runs, default=0), sum(s[2] for s in main if st <= s[0] < en) / 1e6, label))
    sp = os.path.join(PERF, "out", f"{name}.sampler.csv")
    smp = list(csv.DictReader(open(sp))) if os.path.exists(sp) else []
    smp = [{k: float(v or 0) for k, v in r.items()} for r in smp]
    first = next((x for x in smp if x["bytes_in"] > 0), None)
    mb_in = (smp[-1]["bytes_in"] - first["bytes_in"]) / 1048576 if first and smp else 0
    wall = (smp[-1]["t"] - smp[0]["t"]) if len(smp) > 1 else 0
    thr = collections = None
    import collections as C
    per_thread = C.Counter()
    for s in run:
        if not s[1].startswith("Main Thread"): per_thread[re.sub(r"\s*\(Echo, pid: \d+\)", "", s[1])[:30]] += s[2] / 1e6
    server = ""
    server_path = os.path.join(PERF, "out", f"{name}.server.txt")
    if os.path.exists(server_path):
        server = " | ".join(l.strip()[:150] for l in open(server_path) if re.match(r"\s+\d+ statements|\s+transactions", l))
    print(f"## {name}: {len(steps)} steps, {wall:.0f}s")
    print(f"   main-thread: busy {sum(s[2] for s in main) / 1e9:.1f} s, hangs>=500ms: {[f'{d:.0f}ms@{t:.0f}s' for d, ty, t in hang_list if d >= 500]}, microhangs {sum(1 for d, ty, t in hang_list if d < 500)}")
    for longest, busy, label in sorted(rows, reverse=True)[:4]:
        print(f"     worst: longest {longest:5.0f} ms, step busy {busy:5.0f} ms  {label[:50]}")
    print(f"   process: threads {min((x['threads'] for x in smp), default=0):.0f}..{max((x['threads'] for x in smp), default=0):.0f}, rss {min((x['rss_mb'] for x in smp), default=0):.0f}..{max((x['rss_mb'] for x in smp), default=0):.0f} MB, tcp max {max((x['tcp'] for x in smp), default=0):.0f}, "
          f"network in {mb_in:.1f} MB ({mb_in * 1024 / max(wall, 1):.0f} KB/s)")
    print(f"   other-thread CPU: " + ", ".join(f"{k}={v / 1000:.1f}s" for k, v in per_thread.most_common(3)))
    if server: print(f"   servers: {server}")
