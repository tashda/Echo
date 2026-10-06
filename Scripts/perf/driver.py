#!/usr/bin/env python3
"""driver.py [--no-trace] [--no-quiet] [--keep-open] <name>=<scenario.json> ...: traced scenarios, with everything measured.

Starts Echo once (isolated, DEBUG automation) connected to the servers the scenarios name, waits until the servers are
quiet (schema prefetch finished), then runs each scenario in turn. While one runs:
  * Instruments' Time Profiler records the process          -> traces/<name>.trace
  * a sampler logs threads, CPU, memory, TCP connections and network bytes twice a second -> out/<name>.sampler.csv
  * the servers' statement counters are read before and after -> out/<name>.server.txt
Steps are fed one at a time through ECHO_AUTOMATION_COMMANDS (each waits for the previous), so a long step never
overlaps the next; every scenario starts by closing all tabs. Read a result with `report.py <name>`.
Environment: PERF_DIR (where traces/ and out/ go), ECHO_APP (the Echo.app to run), ECHO_AUTOMATION_CONFIG.
Echo only creates its window when activated, so the focus is handed straight back to what the person was using."""
import csv, io, contextlib, json, os, signal, subprocess, sys, threading, time

HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import serverstats
PERF = os.environ.get("PERF_DIR", HERE)
APP = os.environ.get("ECHO_APP", "")
CONFIG = os.environ.get("ECHO_AUTOMATION_CONFIG", "/Users/k/Development/Echo/.echo-automation/config.json")
flags = [a for a in sys.argv[1:] if a.startswith("--")]
runs = [a.split("=", 1) for a in sys.argv[1:] if not a.startswith("--")]
trace_on, quiet_on = "--no-trace" not in flags, "--no-quiet" not in flags
for d in ("traces", "out"): os.makedirs(os.path.join(PERF, d), exist_ok=True)
out = lambda name, ext: os.path.join(PERF, "out", f"{name}.{ext}")
scripts = {name: json.load(open(path)) for name, path in runs}
servers = []
for script in scripts.values():
    for s in script.get("connect", []):
        if s not in servers: servers.append(s)
session = f"session-{runs[0][0]}"
cmds, stdout_path = out(session, "cmds"), out(session, "stdout")
open(cmds, "w").close(); open(stdout_path, "w").close()

def pids():
    return [int(x) for x in subprocess.run(["pgrep", "-f", f"{APP}/Contents/MacOS/Echo"], capture_output=True, text=True).stdout.split()]

boot = out(session, "boot.json")
json.dump({"connect": servers, "steps": []}, open(boot, "w"))

def launch():
    """Starts Echo and waits for its script to listen. A launch sometimes comes up with no window and never starts: try again."""
    subprocess.run(["pkill", "-f", f"{APP}/Contents/MacOS/Echo"]); time.sleep(1)
    open(cmds, "w").close(); open(stdout_path, "w").close()
    front = subprocess.run(["osascript", "-e", 'tell application "System Events" to get name of first process whose frontmost is true'], capture_output=True, text=True).stdout.strip()
    subprocess.run(["open", "-n", "-a", APP, "--env", "ECHO_AUTOMATION=1", "--env", "ECHO_AUTOMATION_ISOLATED=1", "--env", f"ECHO_AUTOMATION_SCRIPT={boot}",
                    "--env", f"ECHO_AUTOMATION_COMMANDS={cmds}", "--env", f"ECHO_AUTOMATION_CONFIG={CONFIG}", "--env", "ECHO_KEPT_TABS=6",
                    "--env", f"ECHO_HANG_SAMPLES={os.path.join(PERF, 'out', session + '.hangs')}",
                    "--stdout", stdout_path, "--stderr", out(session, "stderr")])
    # (wait for its window first: leaving earlier leaves it without one)
    for _ in range(120):
        n = subprocess.run(["osascript", "-e", 'tell application "System Events" to tell process "Echo" to get count of windows'], capture_output=True, text=True).stdout.strip()
        if n.isdigit() and int(n) >= 1: break
        time.sleep(0.5)
    time.sleep(1.5)
    if front and front != "Echo": subprocess.run(["osascript", "-e", f'tell application "{front}" to activate'], capture_output=True)
    for _ in range(240):
        if "commands listening" in open(stdout_path, errors="replace").read(): return True
        time.sleep(0.5)
    return False

for attempt in range(3):
    if launch(): break
    print(f"[{session}] launch {attempt + 1} did not start its script; trying again", flush=True)
else:
    sys.exit("Echo never started its script")
pid = pids()[0]
print(f"[{session}] app pid {pid}, servers {servers}", flush=True)

def server_total():
    snap = serverstats.snapshot()
    n = 0
    for v in snap.values():
        if v.get("type") == "mssql": n += sum(s["n"] for s in v["statements"].values())
        elif v.get("type") == "postgresql": n += v["xacts"]
    return n, snap

if quiet_on:
    last, calm, started = None, 0, time.time()
    while calm < 3 and time.time() - started < 600:
        total, _ = server_total()
        # our own snapshot adds a few statements each time
        calm = calm + 1 if last is not None and total - last <= 14 else 0
        last = total
        time.sleep(8)
    print(f"[{session}] servers quiet after {time.time() - started:.0f}s (calm={calm})", flush=True)

fed = 0
def feed(step):
    global fed
    with open(cmds, "a") as f: f.write(json.dumps(step) + "\n")
    fed += 1
    deadline = time.time() + 600
    while time.time() < deadline:
        if f"commands done {fed}\n" in open(stdout_path, errors="replace").read(): return True
        time.sleep(0.1)
    print(f"[{session}] step {fed} did not finish: {step}", flush=True)
    return False

for name, _ in runs:
    script = scripts[name]
    feed({"action": "closeAllTabs", "wait": 2, "label": "reset"})
    _, before = server_total()
    xctrace = None
    if trace_on:
        while subprocess.run(["pgrep", "-f", "xctrace record"], capture_output=True).returncode == 0: time.sleep(5)
        trace = os.path.join(PERF, "traces", f"{name}.trace")
        subprocess.run(["rm", "-rf", trace])
        xctrace = subprocess.Popen(["xcrun", "xctrace", "record", "--template", "Time Profiler", "--output", trace, "--time-limit", "3000s", "--no-prompt",
                                    "--attach", str(pid)], stdout=open(out(name, "xctrace.log"), "w"), stderr=subprocess.STDOUT)
        time.sleep(4)
    stop = threading.Event()
    def sampler():
        nettop = subprocess.Popen(["nettop", "-P", "-L", "0", "-s", "1", "-J", "bytes_in,bytes_out"], stdout=subprocess.PIPE, text=True)
        net = {"in": 0, "out": 0}  # (nettop counts since the process started; report.py counts from the first reading)
        def read_net():
            for line in nettop.stdout:
                if line.startswith(f"Echo.{pid},"):
                    parts = line.split(",")
                    net["in"], net["out"] = int(parts[1]), int(parts[2])
        threading.Thread(target=read_net, daemon=True).start()
        with open(out(name, "sampler.csv"), "w", newline="") as f:
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
    t0 = time.time()
    print(f"[{name}] start", flush=True)
    # the app's own step lines for this scenario go to its own file
    mark = os.path.getsize(stdout_path)
    for step in script["steps"]: feed(step)
    time.sleep(3)
    stop.set()
    if xctrace:
        xctrace.send_signal(signal.SIGINT)
        try: xctrace.wait(timeout=240)
        except subprocess.TimeoutExpired: xctrace.kill()
    _, after = server_total()
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf): serverstats.diff(before, after, 40)
    open(out(name, "server.txt"), "w").write(buf.getvalue())
    with open(stdout_path, errors="replace") as f:
        f.seek(mark); open(out(name, "stdout"), "w").write("".join(l for l in f if l.startswith("automation-")))
    print(f"[{name}] done in {time.time() - t0:.0f}s", flush=True)

if "--keep-open" not in flags:
    feed({"action": "quit"}) if False else open(cmds, "a").write('{"action":"quit"}\n')
    time.sleep(2)
    subprocess.run(["pkill", "-f", f"{APP}/Contents/MacOS/Echo"])
