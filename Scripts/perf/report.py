#!/usr/bin/env python3
"""report.py <name> [--steps]: the whole picture of one driver.py run, per step and in total.

  main thread: busy ms, longest unbroken stretch, stretches over 50 ms
  all threads: CPU ms by thread, with the nearest Echo function each spent it in (thread over-use)
  process:     threads (avg, max), CPU %, TCP connections, network KB in and out
  servers:     what the databases were asked (out/<name>.server.txt)
Reads traces/<name>.trace, out/<name>.stdout, out/<name>.sampler.csv. PERF_DIR as for driver.py."""
import collections, csv, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
PERF = os.environ.get("PERF_DIR", HERE)
name = sys.argv[1]
import parse
sys.argv = ["x", os.path.join(PERF, "traces", f"{name}.trace")]
trace, steps, hangs, samples = parse.main()
base = min(s[0] for s in samples)

# step epochs from the app's stdout, matched in order with the signposted steps
epochs = []
for line in open(os.path.join(PERF, "out", f"{name}.stdout"), errors="replace"):
    m = re.match(r"automation-step (\d+\.\d+) (\d+) (.*)", line)
    if m: epochs.append((float(m.group(1)), m.group(3)))
sampler = []
path = os.path.join(PERF, "out", f"{name}.sampler.csv")
if os.path.exists(path):
    for r in csv.DictReader(open(path)):
        try: sampler.append({k: float(v) if v not in ("", None) else 0.0 for k, v in r.items()})
        except ValueError: pass

# nettop reports bytes since the process started: count from the first reading
first = next((x for x in sampler if x["bytes_in"] > 0), None)
if first:
    b_in, b_out = first["bytes_in"], first["bytes_out"]
    for x in sampler:
        x["bytes_in"] = max(x["bytes_in"] - b_in, 0); x["bytes_out"] = max(x["bytes_out"] - b_out, 0)

def thread_label(t):
    t = re.sub(r"\s*\(Echo, pid: \d+\)", "", t)
    return t[:34]

windows = []
for i, (st, label) in enumerate(steps):
    en = steps[i + 1][0] if i + 1 < len(steps) else st + 2e9
    windows.append((st, en, label, epochs[i][0] if i < len(epochs) else None))

def runs_of(ts):
    runs, start, last = [], None, None
    for t in sorted(ts):
        if start is None: start = t
        elif t - last > 4e6: runs.append((last - start) / 1e6 + 1); start = t
        last = t
    if start is not None: runs.append((last - start) / 1e6 + 1)
    return runs

running = [s for s in samples if s[3] == "Running"]
print(f"== {name}: {len(steps)} steps, {(max(s[0] for s in samples) - base) / 1e9:.0f}s traced, {len(hangs)} hangs")
for s, d, ty in hangs: print(f"   HANG {ty} {d / 1e6:.0f} ms at {(s - base) / 1e9:.1f}s")
print(f"{'step':34s} {'sec':>5s} {'main':>6s} {'long':>5s} {'>50':>3s} {'allCPU':>7s} {'thr':>7s} {'cpu%':>9s} {'tcp':>3s} {'KBin':>6s} {'KBout':>6s}  busiest other threads (ms)")
tot_threads = collections.Counter(); tot_where = collections.defaultdict(collections.Counter)
for a, b, label, epoch in windows:
    inwin = [s for s in running if a <= s[0] < b]
    main = [s for s in inwin if s[1].startswith("Main Thread")]
    others = collections.Counter(); where = collections.defaultdict(collections.Counter)
    for s in inwin:
        if s[1].startswith("Main Thread"): continue
        label_t = thread_label(s[1]); w = s[2] / 1e6
        others[label_t] += w
        near = next((f"{n}" for n, bn in s[4] if parse.is_app(bn)), None) or (s[4][0][0] if s[4] else "?")
        where[label_t][re.sub(r"\s+", " ", near)[:60]] += w
    for k, v in others.items():
        tot_threads[k] += v
        for fn, w in where[k].items(): tot_where[k][fn] += w
    sec = (b - a) / 1e9
    busy = sum(s[2] for s in main) / 1e6
    rs = runs_of([s[0] for s in main])
    allcpu = sum(s[2] for s in inwin) / 1e6
    smp = [x for x in sampler if epoch and epoch <= x["t"] < epoch + sec] if epoch else []
    thr = f"{sum(x['threads'] for x in smp) / len(smp):.0f}/{max(x['threads'] for x in smp):.0f}" if smp else "-"
    cpu = f"{sum(x['cpu_pct'] for x in smp) / len(smp):.0f}/{max(x['cpu_pct'] for x in smp):.0f}" if smp else "-"
    tcp = f"{max(x['tcp'] for x in smp):.0f}" if smp else "-"
    kin = (smp[-1]["bytes_in"] - smp[0]["bytes_in"]) / 1024 if len(smp) > 1 else 0
    kout = (smp[-1]["bytes_out"] - smp[0]["bytes_out"]) / 1024 if len(smp) > 1 else 0
    top = ", ".join(f"{k.split(' (')[0]}={v:.0f}" for k, v in others.most_common(3))
    print(f"{label[:34]:34s} {sec:5.1f} {busy:6.0f} {max(rs, default=0):5.0f} {sum(1 for r in rs if r > 50):3d} {allcpu:7.0f} {thr:>7s} {cpu:>9s} {tcp:>3s} {kin:6.0f} {kout:6.0f}  {top}")
print("\n-- CPU by thread over the whole run (ms) and where it went")
for k, v in tot_threads.most_common(10):
    print(f"  {v:7.0f}  {k}")
    for fn, w in tot_where[k].most_common(3): print(f"            {w:6.0f}  {fn}")
if sampler:
    print(f"\n-- process: threads {min(x['threads'] for x in sampler):.0f}..{max(x['threads'] for x in sampler):.0f}, rss {min(x['rss_mb'] for x in sampler):.0f}..{max(x['rss_mb'] for x in sampler):.0f} MB, "
          f"tcp up to {max(x['tcp'] for x in sampler):.0f}, network in {(sampler[-1]['bytes_in'] - sampler[0]['bytes_in']) / 1048576:.1f} MB out {(sampler[-1]['bytes_out'] - sampler[0]['bytes_out']) / 1048576:.1f} MB")
sp = os.path.join(PERF, "out", f"{name}.server.txt")
if os.path.exists(sp): print("\n-- what the servers were asked\n" + open(sp).read())
