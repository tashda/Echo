#!/usr/bin/env python3
"""scoreboard.py <name>...: the frame-meter lines of runs grouped by kind of interaction: how many times, the worst p95 and max gap, and the share of
frames that were late (jank = later than 25 ms). One line per kind, worst first."""
import os, re, sys, collections
PERF = os.environ.get("PERF_DIR", os.getcwd())
import subprocess
if subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "verify.py")] + sys.argv[1:], env={**os.environ, "PERF_DIR": PERF}).returncode: print("^^ a run above did not connect: its numbers mean nothing\n")
kinds = [("connect", r"connect "), ("section switch", r"section "), ("open folder", r"open |folder"), ("tree scroll", r"scroll (tables|down|up|tree)"),
         ("query 20k", r"query"), ("results scroll", r"scroll results"), ("structure tab", r"structure"), ("tool tab", r"activity monitor|tool"),
         ("tool page", r"next page|page "), ("tab switch", r"tab switch|next tab"), ("sidebar toggle", r"(hide|show) sidebar"),
         ("inspector toggle", r"(show|hide) inspector"), ("tab overview", r"overview"), ("resize", r"resize"), ("minimize/restore", r"minimize|restore")]
agg = collections.defaultdict(list)
for name in sys.argv[1:]:
    for line in open(os.path.join(PERF, "out", f"{name}.stdout"), errors="replace"):
        m = re.match(r"automation-frames \d+ (.+?) frames=(\d+) fps=(\d+) p50=([\d.]+) p95=([\d.]+) max=([\d.]+) hitches=(\d+) lostMs=(\d+)(?: jank=(\d+))?", line)
        if not m: continue
        label = m.group(1)
        for kind, pattern in kinds:
            if re.search(pattern, label): agg[kind].append((label, int(m.group(2)), int(m.group(3)), float(m.group(5)), float(m.group(6)), int(m.group(9) or 0), int(m.group(8)))); break
print(f"{'interaction':18s} {'n':>3s} {'fps(min)':>8s} {'fps(avg)':>8s} {'p95 worst':>9s} {'max gap':>8s} {'jank%':>6s} {'lost ms':>8s}  worst step")
rows = []
for kind, items in agg.items():
    frames = sum(i[1] for i in items); jank = sum(i[5] for i in items)
    worst = max(items, key=lambda i: i[6])
    rows.append((sum(i[6] for i in items), f"{kind:18s} {len(items):3d} {min(i[2] for i in items):8d} {sum(i[2] for i in items)/len(items):8.0f} {max(i[3] for i in items):9.0f} {max(i[4] for i in items):8.0f} {100*jank/max(frames,1):6.1f} {sum(i[6] for i in items):8d}  {worst[0][:38]}"))
for _, r in sorted(rows, reverse=True): print(r)
