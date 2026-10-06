#!/usr/bin/env python3
"""verify.py <name>...: did the run really talk to the servers? Reads out/<name>.server.txt (what the test servers saw while Echo ran).
A connected run opens at least 5 new SQL Server sessions and sends Postgres thousands of transactions; a run where every server
showed 'Failed' opens one session and about a hundred transactions. Prints VALID or NOT CONNECTED per run; exit code 1 if any is not connected."""
import os, re, sys
bad = 0
for name in sys.argv[1:]:
    text = open(os.path.join(os.environ.get("PERF_DIR", "."), "out", f"{name}.server.txt"), errors="replace").read()
    m = re.search(r"sessions (\d+) -> (\d+)", text)
    opened = int(m.group(2)) - int(m.group(1)) if m else 0
    t = re.search(r"transactions (\d+)", text)
    tx = int(t.group(1)) if t else 0
    ok = opened >= 5 and tx >= 1000
    bad += not ok
    print(f"{'VALID' if ok else 'NOT CONNECTED'}  {name}: {opened} SQL Server sessions opened, {tx} Postgres transactions")
sys.exit(1 if bad else 0)
