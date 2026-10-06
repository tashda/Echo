#!/usr/bin/env python3
"""driver.py <name> <scenario.json> [--no-trace] [--no-quiet]: one traced scenario, with everything measured.

Starts Echo (isolated, DEBUG automation, connected to the scenario's servers), waits until the servers are quiet
(schema prefetch finished), then, while the steps run:
  * Instruments' Time Profiler records the process          -> traces/<name>.trace
  * a sampler logs threads, CPU, memory, TCP connections and network bytes twice a second -> out/<name>.sampler.csv
  * the servers' statement counters are read before and after -> out/<name>.server.txt
Steps are fed one at a time through ECHO_AUTOMATION_COMMANDS (each waits for the previous), so a long step never
overlaps the next. Read the result with `report.py <name>`. Environment: PERF_DIR (default: scratch dir of this
checkout's Scripts/perf), ECHO_APP (the Echo.app to run)."""
import csv, json, os, signal, subprocess, sys, threading, time

HERE = os.path.dirname(os.path.abspath(__file__))
PERF = os.environ.get("PERF_DIR", HERE)
APP = os.environ.get("ECHO_APP", "")
CONFIG = os.environ.get("ECHO_AUTOMATION_CONFIG", "/Users/k/Development/Echo/.echo-automation/config.json")
name, scenario = sys.argv[1], sys.argv[2]
trace_on, quiet_on = "--no-trace" not in sys.argv, "--no-quiet" not in sys.argv
for d in ("traces", "out"): os.makedirs(os.path.join(PERF, d), exist_ok=True)
out = lambda ext: os.path.join(PERF, "out", f"{name}.{ext}")
script = json.load(open(scenario))
cmds = out("cmds"); open(cmds, "w").close()
stdout_path = out("stdout"); open(stdout_path, "w").close()

def pids():
    r = subprocess.run(["pgrep", "-f", f"{APP}/Contents/MacOS/Echo"], capture_output=True, text=True)
    return [int(x) for x in r.stdout.split()]

subprocess.run(["pkill", "-f", f"{APP}/Contents/MacOS/Echo"]); time.sleep(1)
boot = os.path.join(PERF, "out", f"{name}.boot.json")
json.dump({"connect": script.get("connect", []), "steps": []}, open(boot, "w"))
subprocess.run(["open", "-g", "-n", "-a", APP, "--env", "ECHO_AUTOMATION=1", "--env", "ECHO_AUTOMATION_ISOLATED=1", "--env", f"ECHO_AUTOMATION_SCRIPT={boot}",
                "--env", f"ECHO_AUTOMATION_COMMANDS={cmds}", "--env", f"ECHO_AUTOMATION_CONFIG={CONFIG}", "--env", "ECHO_KEPT_TABS=6",
                "--stdout", stdout_path, "--stderr", out("stderr")])
for _ in range(240):
    if "commands listening" in open(stdout_path, errors="replace").read(): break
    time.sleep(0.5)
pid = pids()[0]
print(f"[{name}] app pid {pid}")

def server_total():
    import serverstats
    snap = serverstats.snapshot()
    n = 0
    for v in snap.values():
        if v.get("type") == "mssql": n += sum(s["n"] for s in v["statements"].values())
        elif v.get("type") == "postgresql": n += v["xacts"]
    return n, snap

sys.path.insert(0, HERE)
if quiet_on:
    last, calm, started = None, 0, time.time()
    while calm < 3 and time.time() - started < 480:
        total, _ = server_total()
        calm = calm + 1 if last is not None and total - last <= 3 else 0
        last = total
        time.sleep(6)
    print(f"[{name}] servers quiet after {time.time() - started:.0f}s (calm={calm})")
_, before = server_total()
json.dump(before, open(out("server.before.json"), "w"))

# Time Profiler (one at a time on this machine: the kernel's profiler is shared)
xctrace = None
if trace_on:
    while subprocess.run(["pgrep", "-f", "xctrace record"], capture_output=True).returncode == 0: time.sleep(5)
    trace = os.path.join(PERF, "traces", f"{name}.trace")
    subprocess.run(["rm", "-rf", trace])
    xctrace = subprocess.Popen(["xcrun", "xctrace", "record", "--template", "Time Profiler", "--output", trace, "--time-limit", "3000s", "--no-prompt",
                                "--attach", str(pid)], stdout=open(out("xctrace.log"), "w"), stderr=subprocess.STDOUT)
    time.sleep(4)

# Sampler: threads, cpu, rss, connections, network bytes
stop = threading.Event()
def sampler():
    nettop = subprocess.Popen(["nettop", "-P", "-L", "0", "-s", "1", "-J", "bytes_in,bytes_out"], stdout=subprocess.PIPE, text=True)
    net = {"in": 0, "out": 0}
    def read_net():
        for line in nettop.stdout:
            if line.startswith(f"Echo.{pid},"):
                parts = line.split(",")
                net["in"], net["out"] = int(parts[1]), int(parts[2])
    threading.Thread(target=read_net, daemon=True).start()
    with open(out("sampler.csv"), "w", newline="") as f:
        w = csv.writer(f); w.writerow(["t", "threads", "cpu_pct", "rss_mb", "tcp", "bytes_in", "bytes_out"])
        tcp, tick = 0, 0
        while not stop.is_set():
            ps = subprocess.run(["ps", "-M", "-p", str(pid)], capture_output=True, text=True).stdout.strip().splitlines()
            cpu = subprocess.run(["ps", "-o", "%cpu=,rss=", "-p", str(pid)], capture_output=True, text=True).stdout.split()
            if tick % 4 == 0:
                tcp = len([l for l in subprocess.run(["lsof", "-nP", "-a", "-p", str(pid), "-i", "TCP"], capture_output=True, text=True).stdout.splitlines() if "ESTABLISHED" in l])
            w.writerow([f"{time.time():.2f}", max(len(ps) - 1, 0), cpu[0] if cpu else "", int(cpu[1]) // 1024 if len(cpu) > 1 else "", tcp, net["in"], net["out"]]); f.flush()
            tick += 1; time.sleep(0.5)
    nettop.terminate()
threading.Thread(target=sampler, daemon=True).start()

# Steps, one at a time
t0 = time.time()
print(f"automation-script start {t0:.3f}", flush=True)
for step in script["steps"]:
    with open(cmds, "a") as f: f.write(json.dumps(step) + "\n")
    expected = sum(1 for _ in open(cmds))
    deadline = time.time() + 600
    while time.time() < deadline:
        if f"commands done {expected}\n" in open(stdout_path, errors="replace").read(): break
        time.sleep(0.1)
    else:
        print(f"[{name}] step {expected} did not finish: {step}")
time.sleep(3)
stop.set()
if xctrace:
    xctrace.send_signal(signal.SIGINT)
    try: xctrace.wait(timeout=180)
    except subprocess.TimeoutExpired: xctrace.kill()
_, after = server_total()
json.dump(after, open(out("server.after.json"), "w"))
with open(out("server.txt"), "w") as f:
    import io, contextlib, serverstats
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf): serverstats.diff(before, after, 40)
    f.write(buf.getvalue())
with open(cmds, "a") as f: f.write('{"action":"quit"}\n')
time.sleep(2)
subprocess.run(["pkill", "-f", f"{APP}/Contents/MacOS/Echo"])
print(f"[{name}] done in {time.time() - t0:.0f}s")
