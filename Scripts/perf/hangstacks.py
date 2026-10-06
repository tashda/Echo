#!/usr/bin/env python3
"""hangstacks.py <dir|file>...: what the main thread was stuck in, from the `sample` files the hang watcher wrote
(ECHO_HANG_SAMPLES). For each: the heaviest call path of the main thread from the run loop down, and where it ends."""
import glob, os, re, sys
def tree(lines):
    nodes = []  # (depth, count, text)
    for line in lines:
        m = re.match(r"^([ +!:|]*?)(\d+) (.*)$", line.rstrip("\n"))
        if m: nodes.append((len(m.group(1)), int(m.group(2)), m.group(3)))
    return nodes
def heaviest(nodes, start):
    path, depth, idx = [], nodes[start][0], start
    path.append(nodes[idx]); i = idx + 1
    while True:
        best = None
        j = i
        while j < len(nodes) and nodes[j][0] > nodes[idx][0]:
            if nodes[j][0] == nodes[idx][0] + 2 and (best is None or nodes[j][1] > nodes[best][1]): best = j
            j += 1
        if best is None: return path
        path.append(nodes[best]); idx = best; i = best + 1
for arg in sys.argv[1:]:
    for f in sorted(glob.glob(os.path.join(arg, "*.txt")) if os.path.isdir(arg) else [arg]):
        lines = open(f, errors="replace").read().split("Call graph:")[-1].split("Total number in stack")[0].splitlines()
        nodes = tree(lines)
        main = next((i for i, n in enumerate(nodes) if "com.apple.main-thread" in n[2]), None)
        if main is None: continue
        path = heaviest(nodes, main)
        # skip the run-loop/boilerplate prefix
        useful = [p for p in path if not re.search(r"^(start|_?_?debug_main|static EchoApp|static App\.main|runApp|specialized runApp|NSApplicationMain|-\[NSApplication run\]|_DPSNextEvent|_CFRunLoop|__CFRunLoop|CFRunLoop|RunCurrentEventLoop|ReceiveNextEvent|_BlockUntil|_DPSBlock|-\[NSApplication\(NSEventRouting\))", p[2])]
        print(f"== {os.path.basename(f)}  (main thread: {path[0][1]} samples)")
        for d, c, t in useful[:14]: print(f"   {c:4d} {re.sub(r'  +', ' ', t)[:150]}")
        print(f"   ... ends in: {re.sub(r'  +', ' ', path[-1][2])[:140]}")
