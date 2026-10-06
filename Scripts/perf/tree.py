#!/usr/bin/env python3
"""tree.py <trace> <t0_sec> <t1_sec> [minpct] [depth]: top-down main-thread call tree for a time window (seconds into trace)."""
import sys, re, collections
sys.argv_backup = sys.argv
import importlib.util, os
spec = importlib.util.spec_from_file_location("parse", os.path.join(os.path.dirname(os.path.abspath(__file__)), "parse.py")); parse = importlib.util.module_from_spec(spec); spec.loader.exec_module(parse)
trace, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
minpct = float(sys.argv[4]) if len(sys.argv) > 4 else 3
depth = int(sys.argv[5]) if len(sys.argv) > 5 else 40
sys.argv = [sys.argv[0], trace]
trace, steps, hangs, samples = parse.main()
base = min(s[0] for s in samples)
sel = [s for s in samples if s[1].startswith("Main Thread") and s[3] == "Running" and t0 <= (s[0]-base)/1e9 < t1 and s[4]]
total = sum(s[2] for s in sel) / 1e6
print(f"{len(sel)} samples, {total:.0f} ms main busy in [{t0},{t1}]")
class N:
    def __init__(s): s.w = 0; s.kids = {}
root = N()
MARK = re.compile("|".join(["NSToolbarView layout","_resetDragMargins","NSHostingView.layout","NSHostingView.beginTransaction","CA::Transaction::commit","renderDisplayList","ViewGraph.updateOutputs","NSWindow.*display","NSTableView","NSScrollView","NSTextView","NSLayoutManager","NSTextStorage","CTLine","CTTypesetter","acceptsFirstResponder","AccessibilityNode","NSToolbar","updateConstraints","DynamicBody.updateValue","PreferenceKey","sizeThatFits","placeSubviews","ForEach","AnyView","KeyPath","NSAnimationContext","_NSViewLayout"]))
APPONLY = os.environ.get("APPONLY")
for smp in sel:
    node = root; w = smp[2] / 1e6
    frames = reversed(smp[4])
    if APPONLY: frames = [f for f in frames if parse.is_app(f[1]) or MARK.search(f[0])]
    for name, b in frames:
        node.w += 0
        node = node.kids.setdefault((name, b), N()); node.w += w
def show(n, d, indent):
    for (name, b), k in sorted(n.kids.items(), key=lambda kv: -kv[1].w):
        if k.w < total * minpct / 100: continue
        # collapse single-child chains of uninteresting frames
        print(f"{indent}{k.w:6.0f} {re.sub(r'\s+', ' ', name)[:120]} [{b[:18]}]")
        if d < depth: show(k, d + 1, indent + " ")
show(root, 0, "")
