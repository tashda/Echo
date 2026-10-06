#!/usr/bin/env python3
"""parse.py <trace> [--win a,b] : summarize a Time Profiler trace of Echo, per automation step."""
import sys, subprocess, collections, re, os
import xml.etree.ElementTree as ET

def export(trace, schema):
    out = subprocess.run(["xcrun","xctrace","export","--input",trace,"--xpath",
        f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'],capture_output=True)
    return out.stdout

def parse_rows(data):
    refs = {}
    def resolve(e):
        if e is None: return None
        r = e.get("ref")
        if r is not None: return refs.get(r)
        i = e.get("id")
        if i is not None: refs[i] = e
        return e
    root = ET.fromstring(data)
    for row in root.iter("row"):
        # register all ids first in document order
        for e in row.iter():
            i = e.get("id")
            if i is not None and e.get("ref") is None: refs[i] = e
        yield row, refs

def val(e, refs):
    if e is None: return None
    if e.get("ref") is not None: e = refs.get(e.get("ref"))
    return e

def main():
    trace = sys.argv[1]
    import pickle
    pk = trace + '.pkl'
    if os.path.exists(pk): return pickle.load(open(pk,'rb'))
    r = _main(trace)
    pickle.dump(r, open(pk,'wb'))
    return r

def _main(trace):
    win = None
    # steps
    steps = []
    for row, refs in parse_rows(export(trace, "PointsOfInterestEvents")):
        t = val(row.find("event-time"), refs); n = val(row.find("signpost-name"), refs)
        m = val(row.find("os-log-metadata"), refs)
        if n is not None and n.get("fmt") == "step":
            steps.append((int(t.text), m.get("fmt") if m is not None else ""))
    steps.sort()
    hangs = []
    for row, refs in parse_rows(export(trace, "potential-hangs")):
        s = val(row.find("start-time"), refs); d = val(row.find("duration"), refs); ty = val(row.find("hang-type"), refs)
        hangs.append((int(s.text), int(d.text), ty.get("fmt")))
    # samples
    data = export(trace, "time-profile")
    samples = []  # (t, thread_is_main, thread_fmt, weight, [frames leaf-first as (name,bin)])
    frame_cache = {}
    bt_cache = {}
    root = ET.fromstring(data)
    refs = {}
    for row in root.iter("row"):
        for e in row.iter():
            i = e.get("id")
            if i is not None and e.get("ref") is None: refs[i] = e
        t = val(row.find("sample-time"), refs)
        th = val(row.find("thread"), refs)
        w = val(row.find("weight"), refs)
        st = val(row.find("thread-state"), refs)
        bt = val(row.find("tagged-backtrace"), refs)
        frames = []
        if bt is not None:
            for f in bt.iter("frame"):
                f = val(f, refs)
                b = f.find("binary")
                b = val(b, refs) if b is not None else None
                frames.append((f.get("name"), b.get("name") if b is not None else "?"))
        samples.append((int(t.text), th.get("fmt") if th is not None else "?", int(w.text), st.get("fmt") if st is not None else "", frames))
    return trace, steps, hangs, samples

SYS = {"libsystem_kernel.dylib","libsystem_platform.dylib","libsystem_pthread.dylib","libdispatch.dylib","dyld","libsystem_malloc.dylib",
       "CoreFoundation","Foundation","AppKit","SwiftUI","SwiftUICore","AttributeGraph","libswiftCore.dylib","QuartzCore","CoreGraphics","libswift_Concurrency.dylib","HIToolbox","CoreText","libobjc.A.dylib","?"}
def is_app(b): return b.startswith("Echo") or b in ("PostgresKit","MySQLKit","SQLServerKit","SQLServerKitTDS")

def short(n, w=110):
    n = re.sub(r"\s+", " ", n)
    return n if len(n) <= w else n[:w-1] + "…"

def report(trace, steps, hangs, samples, only=None, top=14):
    t0 = min((s[0] for s in samples), default=0)
    dur = (max((s[0] for s in samples), default=0) - t0) / 1e9
    print(f"== {os.path.basename(trace)}  samples={len(samples)}  span={dur:.1f}s  hangs={len(hangs)}")
    for s, d, ty in hangs:
        print(f"   HANG {ty} {d/1e6:.0f} ms at {s/1e9:.2f}s")
    main = [s for s in samples if s[1].startswith("Main Thread")]
    wins = []
    for i, (st, label) in enumerate(steps):
        en = steps[i+1][0] if i+1 < len(steps) else st + 2e9
        wins.append((st, en, label))
    allw = [(0, 1e18, "ALL")] if not wins or only == "all" else []
    for (a, b, label) in allw + wins:
        ms = [s for s in main if a <= s[0] < b]
        busy = sum(s[2] for s in ms if s[3] == "Running") / 1e6
        span = (min(b, steps[-1][0]+2e9 if steps else b) - a) / 1e6 if a else dur * 1000
        other = collections.Counter()
        for s in samples:
            if a <= s[0] < b and not s[1].startswith("Main Thread") and s[3] == "Running":
                other[s[1][:40]] += s[2] / 1e6
        # continuous busy stretches (a gap over 4 ms ends one): the longest and how many exceed 50 ms
        ts = sorted(x[0] for x in ms if x[3] == "Running")
        runs, start, last = [], None, None
        for t in ts:
            if start is None: start = t
            elif t - last > 4e6: runs.append((last - start) / 1e6 + 1); start = t
            last = t
        if start is not None: runs.append((last - start) / 1e6 + 1)
        longest = max(runs, default=0); long50 = sum(1 for r in runs if r > 50)
        print(f"{'' if os.environ.get('SUMMARY') else chr(10)}-- [{label}] @{(a-t0)/1e9:.1f}s window {span:.0f} ms: main busy {busy:.0f} ms ({100*busy/max(span,1):.0f}%) longest {longest:.0f} ms, >50ms x{long50}  other threads: " +
              ", ".join(f"{k}={v:.0f}" for k, v in other.most_common(3)))
        if os.environ.get('SUMMARY'): continue
        if busy < (float(os.environ.get('MIN_BUSY', 60))): continue
        selfc = collections.Counter(); incl = collections.Counter(); app_self = collections.Counter()
        for s in ms:
            if s[3] != "Running" or not s[4]: continue
            w = s[2] / 1e6
            selfc[(s[4][0][0], s[4][0][1])] += w
            seen = set()
            for n, bn in s[4]:
                if is_app(bn) and n not in seen:
                    seen.add(n); incl[(n, bn)] += w
            for n, bn in s[4]:
                if is_app(bn): app_self[(n, bn)] += w; break
        print("   top self (leaf):")
        for (n, b), w in selfc.most_common(8): print(f"     {w:6.0f}  {short(n)}  [{b}]")
        print("   nearest Echo frame to leaf:")
        for (n, b), w in app_self.most_common(8): print(f"     {w:6.0f}  {short(n)}  [{b}]")
        print("   inclusive app frames:")
        skip = ("thunk for","partial apply","protocol witness","specialized","closure #","$main","entry_point","reabstraction","outlined","merged")
        shown = 0
        for (n, b), w in incl.most_common(200):
            if n.startswith(skip) and "body" not in n: continue
            print(f"     {w:6.0f}  {short(n)}  [{b}]"); shown += 1
            if shown >= top: break

if __name__ == "__main__":
    only = None
    if len(sys.argv) > 2: only = sys.argv[2]
    tr = main()
    report(*tr, only=only)
