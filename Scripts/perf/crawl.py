#!/usr/bin/env python3
"""crawl.py <name> --open '<json step>' [--server NAME] [--window workspace|settings|manage]
Explores one place of Echo in a running session (sess.sh start) the way a person would look around it, and writes the
steps that repeat it as scenarios/crawl-<name>.json, with a log of what each control did.

Per page (a tool tab's page chips; one pass when there are none): its own toolbar buttons, every safe button, menu and
checkbox, the first table (click rows, double-click, right-click, sort by column headers), a search field, scrolling
down and up, and any sheet that opens (scrolled, then closed). Nothing that deletes, stops, applies or runs is pressed.
Layout comes from the accessibility tree (axdump); the recorded steps are plain clicks at points, so a traced replay
(driver.py) needs no accessibility."""
import json, os, re, subprocess, sys

P = os.environ.get("PERF_DIR", os.path.dirname(os.path.abspath(__file__)))
SESS, AXDUMP = os.path.join(P, "sess.sh"), os.path.join(P, "axdump")
UNSAFE = re.compile(r"delete|drop|remove|kill|stop|shutdown|restart|disable|truncate|detach|apply|execute|failover|run now|start|clear|reset|purge|shrink|"
                    r"rebuild|reorganize|repair|restore|vacuum|disconnect|close|quit|sidebar width|new tab|connect to|hide sidebar|show inspector|"
                    r"notifications|search|tab overview|quick connect|recent|default project|backup now|import|sign out|log out|cancel|revert|discard|undo|"
                    r"rollback|enter full screen|minimize|zoom|test mssql|test postgres|export|save|ok$|^yes$|confirm|commit|submit|send|create$", re.I)
CHROME = {"Hide Sidebar", "Quick Connect", "Search", "Show Tab Overview", "Notifications", "Show Inspector", "Default Project", "Recent Connections", "New Tab"}
LINE = re.compile(r"^( *)(\w+) (.*?)\[(-?\d+),(-?\d+) (\d+)x(\d+) @(-?\d+),(-?\d+)\]$")
args = sys.argv[1:]
opt = lambda k, d=None: args[args.index(k) + 1] if k in args else d
name, server, window = args[0], opt("--server", "Test MSSQL"), opt("--window", "0")
openers = [args[i + 1] for i, a in enumerate(args) if a == "--open"]
# --win settings|manage|workspace: which window the steps address (the default: the sheet or front window)
win = opt("--win")
MAX_BUTTONS = int(opt("--max-buttons", "10"))

def sh(*a): return subprocess.run(a, capture_output=True, text=True).stdout
def pid(): return sh("pgrep", "-f", os.environ.get("ECHO_APP", "DD/Build/Products/Debug/Echo.app") + "/Contents/MacOS/Echo").split()[0]

def ax():
    env = dict(os.environ, AXSKIP="workspace-sidebar", AXROWS="2")
    text = subprocess.run([AXDUMP, pid(), "40", window if window.isdigit() else "0"], capture_output=True, text=True, env=env).stdout
    items = []
    for line in text.splitlines():
        m = LINE.match(line)
        if not m: continue
        depth, role, label, x, y, w, h, cx, cy = m.groups()
        desc = re.search(r"(?:Description|Title)='([^']*)'", label) or re.search(r"Value='([^']*)'", label)
        ident = re.search(r"Identifier='([^']*)'", label)
        items.append(dict(depth=len(depth), role=role, text=desc.group(1) if desc else "", ident=ident.group(1) if ident else "",
                          x=int(x), y=int(y), w=int(w), h=int(h), cx=int(cx), cy=int(cy)))
    return items

steps, log = [], []
def do(step, note=None):
    if win and step.get("action") in ("click", "key", "fieldType", "press") and "window" not in step: step["window"] = win
    if win in ("settings", "manage") and step.get("action") == "scroll" and step.get("target") == "content": step["target"] = win
    steps.append(step); sh(SESS, "cmd", json.dumps(step))
    if note: log.append(note)

def sheet_items(items=None):
    items = items or ax()
    for i, it in enumerate(items):
        if it["role"] == "Sheet":
            out = []
            for j in items[i + 1:]:
                if j["depth"] <= it["depth"]: break
                out.append(j)
            return out
    return []

def settle_sheet(why):
    """If a sheet is open: look at it, scroll it, press a few of its safe controls, close it."""
    sheet = sheet_items()
    if not sheet: return False
    controls = [s for s in sheet if s["role"] in ("Button", "TextField", "PopUpButton", "CheckBox", "RadioButton", "MenuButton", "ComboBox", "TextArea") and s["text"] or s["role"] in ("TextField", "TextArea")]
    log.append(f"      -> sheet after {why}: {[ (c['role'], c['text'][:24]) for c in controls][:16]}")
    do({"action": "scroll", "target": "sheet", "distance": 700, "seconds": 1.0, "wait": 0.4, "label": "scroll sheet"})
    do({"action": "scroll", "target": "sheet", "distance": -700, "seconds": 0.8, "wait": 0.4, "label": "scroll sheet up"})
    for field in [c for c in controls if c["role"] in ("TextField", "TextArea")][:2]:
        do({"action": "click", "x": field["cx"], "y": field["cy"], "window": "sheet", "wait": 0.5, "label": "sheet field"})
        do({"action": "fieldType", "target": "perf", "seconds": 0.08, "wait": 0.3, "label": "type in sheet field"})
    for toggle in [c for c in controls if c["role"] in ("CheckBox", "RadioButton") and not UNSAFE.search(c["text"])][:3]:
        do({"action": "click", "x": toggle["cx"], "y": toggle["cy"], "window": "sheet", "wait": 0.6, "label": f"sheet {toggle['text'][:20]}"})
    for menu in [c for c in controls if c["role"] in ("PopUpButton", "MenuButton")][:2]:
        do({"action": "click", "x": menu["cx"], "y": menu["cy"], "window": "sheet", "wait": 0.8, "label": f"sheet menu {menu['text'][:20]}"})
        do({"action": "key", "target": "escape", "wait": 0.5, "label": "escape menu"})
    for it in sheet_items():
        if it["role"] == "Button" and re.fullmatch(r"cancel|close|done|ok", it["text"], re.I):
            do({"action": "click", "x": it["cx"], "y": it["cy"], "window": "sheet", "wait": 1, "label": f"close sheet ({it['text']})"})
            if not sheet_items(): return True
    do({"action": "key", "target": "escape", "wait": 1, "label": "escape sheet"})
    if sheet_items():
        log.append("      !! sheet did not close"); do({"action": "key", "target": "escape", "wait": 1})
    return True

def click(it, note, **extra):
    do({"action": "click", "x": it["cx"], "y": it["cy"], "wait": 1.2, "label": note[:40], **extra}, "   " + note)
    if not settle_sheet(note):
        pass

def page_pass(chip_names, first):
    items = ax()
    content = [it for it in items if it["x"] > 60 and it["y"] > 56 and it["x"] < 1850]
    tool_bar = [it for it in items if it["role"] == "Button" and it["y"] < 52 and it["text"] and it["text"] not in CHROME and not UNSAFE.search(it["text"])
                and not it["text"].startswith("Hide ") and it["w"] > 8]
    # toolbar buttons of this page
    for it in tool_bar[:4]:
        click(it, f"toolbar '{it['text']}'")
    # buttons, checkboxes, menus in the content
    seen = set(chip_names)
    buttons = []
    for it in content:
        if it["role"] != "Button" or not it["text"] or it["text"] in seen or UNSAFE.search(it["text"]) or it["w"] < 12 or it["h"] < 12 or it["cy"] > 790: continue
        seen.add(it["text"]); buttons.append(it)
    for it in buttons[:MAX_BUTTONS]: click(it, f"button '{it['text']}'")
    for it in [i for i in content if i["role"] in ("MenuButton", "PopUpButton") and i["w"] > 12][:3]:
        do({"action": "click", "x": it["cx"], "y": it["cy"], "wait": 0.8, "label": f"menu {it['text'][:24]}"}, f"   menu '{it['text']}'")
        do({"action": "key", "target": "escape", "wait": 0.5, "label": "escape menu"})
    for it in [i for i in content if i["role"] in ("CheckBox", "Switch") and not UNSAFE.search(i["text"])][:3]:
        click(it, f"toggle '{it['text']}'"); click(it, f"toggle back '{it['text']}'")
    for it in [i for i in content if i["role"] == "RadioButton" and i["text"] not in chip_names and not UNSAFE.search(i["text"])][:4]:
        click(it, f"option '{it['text']}'")
    # the first table: sort by its headers, select, open, context menu
    tables = [i for i, it in enumerate(items) if it["role"] in ("Outline", "Table") and it["w"] > 300]
    for ti in tables[:1]:
        row = next((j for j in items[ti + 1:] if j["role"] == "Row"), None)
        if not row: continue
        cells = [j for j in items[ti + 1:ti + 80] if j["role"] == "Cell" and j["y"] == row["y"]][:4]
        log.append(f"   table: rows {row['h']}pt high, {len(cells)} columns shown")
        for c in cells[:3]:
            do({"action": "click", "x": c["cx"], "y": row["y"] - 16, "wait": 1.0, "label": "sort column"}, "   sort by column")
        x = row["x"] + 30
        for k in (0, 2):
            do({"action": "click", "x": x, "y": row["cy"] + k * row["h"], "wait": 0.8, "label": f"select row {k + 1}"}, f"   select row {k + 1}")
        do({"action": "click", "x": x, "y": row["cy"], "index": 2, "wait": 1.5, "label": "open row (double click)"}, "   double-click row")
        settle_sheet("double click")
        do({"action": "click", "x": x, "y": row["cy"] + row["h"], "role": "right", "wait": 1.0, "label": "context menu"}, "   right-click row")
        do({"action": "key", "target": "escape", "wait": 0.6, "label": "escape menu"})
    # a search or filter field
    field = next((i for i in content if i["role"] in ("TextField", "SearchField") and i["w"] > 40), None)
    if field:
        do({"action": "click", "x": field["cx"], "y": field["cy"], "wait": 0.5, "label": "filter field"}, "   filter field")
        do({"action": "fieldType", "target": "dbo", "seconds": 0.12, "wait": 1.0, "label": "type filter"})
        do({"action": "key", "target": "cmd+a", "wait": 0.2}); do({"action": "key", "target": "delete", "wait": 0.8, "label": "clear filter"})
    do({"action": "scroll", "target": "content", "distance": 900, "seconds": 1.5, "wait": 0.5, "label": "scroll down"})
    do({"action": "scroll", "target": "content", "distance": -900, "seconds": 1.0, "wait": 0.5, "label": "scroll up"})

def explore(opener):
    do(json.loads(opener), f"open {opener}")
    base = ax()
    chips = []
    for i, it in enumerate(base):
        if it["role"] == "Group" and it["text"] == "Pages":
            for j in base[i + 1:]:
                if j["depth"] <= it["depth"]: break
                if j["role"] == "Button": chips.append(j)
    chip_names = {c["text"] for c in chips}
    log.append(f"pages: {[c['text'] for c in chips]}")
    for n, chip in enumerate(chips or [None]):
        if chip:
            do({"action": "click", "x": chip["cx"], "y": chip["cy"], "wait": 2.5, "label": f"page {chip['text']}"}, f"-- page {chip['text']}")
        page_pass(chip_names, n == 0)

def main():
    for opener in openers: explore(opener)
    json.dump({"connect": [server] if "," not in server else server.split(","), "steps": steps}, open(os.path.join(P, "scenarios", f"crawl-{name}.json"), "w"), indent=1)
    print("\n".join(log)); print(f"{len(steps)} steps")

os.makedirs(os.path.join(P, "scenarios"), exist_ok=True)
main()
