#!/usr/bin/env python3
"""frames.py <name> [--all]: how smoothly Echo drew in each step of a run (frame meter), worst first; with the process's CPU and threads from the sampler.
fps = frames per second while the step ran; p95/max = the gap between frames in ms; hit = frames later than 1.5 refresh periods;
lost = milliseconds beyond the refresh period summed over all frames."""
import csv, os, re, sys
PERF = os.environ.get("PERF_DIR", os.path.dirname(os.path.abspath(__file__)))
name = sys.argv[1]
rows = []
for line in open(os.path.join(PERF, "out", f"{name}.stdout"), errors="replace"):
    m = re.match(r"automation-frames (.+?) frames=(\d+) fps=(\d+) p50=([\d.]+) p95=([\d.]+) max=([\d.]+) hitches=(\d+) lostMs=(\d+)(?: jank=(\d+))?", line)
    if m: rows.append((m.group(1), int(m.group(2)), int(m.group(3)), float(m.group(4)), float(m.group(5)), float(m.group(6)), int(m.group(7)), int(m.group(8)), int(m.group(9) or 0)))
    elif line.startswith("automation-frames-meter"): print(line.strip())
total_lost = sum(r[7] for r in rows)
print(f"{len(rows)} steps, {sum(r[1] for r in rows)} frames, {sum(r[6] for r in rows)} hitches, {sum(r[8] for r in rows)} janky frames (over 25 ms), {total_lost} ms lost in all")
print(f"{'step':52s} {'frames':>6s} {'fps':>4s} {'p50':>5s} {'p95':>5s} {'max':>6s} {'hit':>4s} {'lost':>6s} {'jank':>4s}")
shown = rows if "--all" in sys.argv else sorted(rows, key=lambda r: -r[7])[:int(os.environ.get("TOP", 30))]
for r in shown: print(f"{r[0][:52]:52s} {r[1]:6d} {r[2]:4d} {r[3]:5.1f} {r[4]:5.1f} {r[5]:6.0f} {r[6]:4d} {r[7]:6d} {r[8]:4d}")
