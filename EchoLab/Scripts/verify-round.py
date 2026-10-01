#!/usr/bin/env python3
r"""Checks that Echo looks and behaves like what the owner accepted in an Echo Labs round.

    python3 EchoLab/Scripts/verify-round.py <page-id> --reference   # capture the accepted round (Echo Labs)
    python3 EchoLab/Scripts/verify-round.py <page-id> [--app PATH]  # capture Echo and compare

The reference is the round's accepted exhibit drawn with the owner's picks from lab-state.json,
captured in every conformance state (RoundSpec.conformance) in light and dark. It goes to
EchoLab/State/References/<page-id>/ and is committed: it is what Echo must match.

The check launches Echo (a Debug build: --app, or the newest Echo.app in DerivedData) with the
same request; Echo draws its real view for that page (ConformanceSpecimens) and captures it the
same way. The two are compared on:
  1. PARTS     every tagged part (`.conformanceTag`), relative to the subject: present, same frame (0.5pt)
  2. TIMELINE  when parts go away (a toast timing out): within 0.25s
  3. PIXELS    the subject cropped from both screenshots: share of pixels that differ (advisory)
Known differences the round lists are reported as expected, not failures: a part name exempts
the part, `pixels:<part>` only leaves its pixels out of the score (its frame is still checked). Output: a report on
stdout and in EchoLab/.build/conformance/<page-id>/, with compare.png (reference | Echo | diff)
for each state. Exit status 1 when parts or timelines differ. The result is also written to
References/<page-id>/last-check.json (commit it), which the round's info box in Echo Labs shows.

Run --reference before you build an accepted round into Echo; after building it, run the check
and set the round to In Echo only when it passes or each difference is explained in the history
event. The reference records the exhibit as the owner saw it, flaws included: if the check shows
the exhibit itself was wrong, ask the owner, fix the exhibit, record a revision and capture again.

Making a round checkable (pilot: round 18, ongoing.notification-toast-r18):
  1. In the RoundSpec add `conformance: RoundConformance(states:subject:knownDifferences:)`: the
     states to capture (id, title, settle, observe), the tag of the part being judged, and the
     differences that are expected, with the reason. The exhibit reads
     `@Environment(\.labConformanceState)` on appear and puts itself in that state, the same way
     every time.
  2. Tag the parts in the exhibit with `.conformanceTag("area.thing.part")`: the subject, every
     element whose size or place was decided, anything with a timeline. Tags do nothing outside
     a capture.
  3. In Echo, tag the same parts with the same names in the real view, and add a specimen for the
     page id to `ConformanceSpecimens` (Echo/Sources/Features/AppHost/Conformance/, DEBUG only):
     Echo's real view with the same sample data, posted through Echo's real code paths, in the
     same states.
  4. Capture the reference and commit EchoLab/State/References/<page-id>/.

How it works: both apps capture through ConformanceCapture (Packages/EchoDesignSystem, Conformance/).
This script writes a request and launches the app's executable directly with
ECHO_CONFORMANCE=<request> (not with `open`, so it uses this shell's screen-recording permission).
The app shows the specimen in a bare floating window at the exhibit's design size for each state
and appearance (small windows flash in the top-right corner), screenshots it with
`screencapture -l` (so Liquid Glass is drawn), records the tagged parts, and quits. Echo Labs draws
the accepted exhibit with RoundValues(fixed:), never the owner's saved knobs; Echo starts its
capture from EchoApp.init and loads none of the user's data.
"""
import argparse, json, os, shutil, subprocess, sys, time
import functools
print = functools.partial(print, flush=True)   # keep progress and errors in order when piped
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "EchoLab"
STATE = LAB / "State/lab-state.json"
REFERENCES = LAB / "State/References"
RESULTS = LAB / ".build/conformance"
APPEARANCES = ["light", "dark"]
FRAME_TOLERANCE = 0.5      # points
TIME_TOLERANCE = 0.25      # seconds
PIXEL_THRESHOLD = 24       # 0-255, per channel, before a pixel counts as different
PIXEL_WARN_SHARE = 0.02    # more than 2% different pixels is worth a look


def fail(message):
    print(f"verify-round: {message}", file=sys.stderr)
    sys.exit(2)


def run_capture(executable, request, out, timeout=180):
    """Launches the app directly (not with `open`) so it inherits this shell's screen-capture
    permission. A capture that fails is tried once more (one failed once right after a heavy build)."""
    try:
        return capture_once(executable, request, out, timeout)
    except RuntimeError as error:
        print(f"  first attempt failed, trying again: {error}")
    try:
        return capture_once(executable, request, out, timeout)
    except RuntimeError as error:
        fail(str(error))


def capture_once(executable, request, out, timeout):
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    request_file = out / "request.json"
    request_file.write_text(json.dumps(request, indent=2))
    env = dict(os.environ, ECHO_CONFORMANCE=str(request_file))
    started = time.time()
    try:
        result = subprocess.run([str(executable)], env=env, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"{executable.name} did not finish the capture within {timeout}s")
    request_file.unlink()
    if result.returncode != 0 or not (out / "capture.json").exists():
        raise RuntimeError(f"{executable.name} capture failed (exit {result.returncode}):\n{result.stderr[-2000:]}")
    print(f"  captured in {time.time() - started:.0f}s")


# ---------------------------------------------------------------- reference (Echo Labs)

def capture_reference(page):
    pages = json.loads(STATE.read_text())
    entry = pages.get(page)
    if not entry:
        fail(f"{page} has no entry in lab-state.json (nothing accepted yet)")
    status = entry.get("status")
    if status not in ("Accepted", "In Echo", "Decided"):
        fail(f"{page} is '{status}': only an accepted round has a reference")
    # As the owner runs it: the app bundle open-lab.sh makes. A bare SwiftPM executable draws
    # some things differently (selectable text on glass has more contrast there).
    print(f"Building Echo Labs…")
    subprocess.run([str(LAB / "Scripts/open-lab.sh"), "--no-launch"], check=True, capture_output=True,
                   env=dict(os.environ, ECHOLAB_QUIET="1"))
    bin_path = subprocess.run(["swift", "build", "--package-path", str(LAB), "--show-bin-path"],
                              check=True, capture_output=True, text=True).stdout.strip()
    out = REFERENCES / page
    print(f"Capturing the accepted {page} in Echo Labs…")
    run_capture(Path(bin_path) / "Echo Labs.app/Contents/MacOS/EchoLab",
                {"page": page, "out": str(out), "appearances": APPEARANCES, "picks": entry.get("picks", {})}, out)
    contract_file = out / "contract.json"
    contract = json.loads(contract_file.read_text())
    contract["status"] = status
    contract["capturedAt"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    contract["labCommit"] = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                                           capture_output=True, text=True).stdout.strip()
    contract_file.write_text(json.dumps(contract, indent=2, sort_keys=True) + "\n")
    (out / "capture.json").unlink()   # the shots are in the contract
    if contract.get("unpicked"):
        print(f"  note: drawn at their default (no pick): {', '.join(contract['unpicked'])}")
    print(f"Reference written to {out.relative_to(ROOT)} ({len(contract['shots'])} shots). Commit it.")


# ---------------------------------------------------------------- check (Echo)

def newest_echo_app():
    candidates = []
    for base in [Path.home() / "Library/Developer/Xcode/DerivedData", Path.home() / "Library/Developer/XcodeBuildMCP"]:
        if base.exists():
            candidates += [p for p in base.glob("**/Build/Products/Debug/Echo.app") if p.is_dir()]
    if not candidates:
        fail("no Debug Echo.app found; build Echo (build_macos) or pass --app")
    return max(candidates, key=lambda p: (p / "Contents/MacOS/Echo").stat().st_mtime)


def relative(part, subject):
    return {k: part[k] - subject[o] if o else part[k]
            for k, o in (("x", "x"), ("y", "y"), ("width", None), ("height", None))}


def compare_parts(ref_shot, echo_shot, subject, known):
    findings, expected = [], []
    ref_parts, echo_parts = ref_shot["parts"], echo_shot["parts"]
    if subject not in ref_parts:
        return [f"the reference has no subject part '{subject}'"], []
    if subject not in echo_parts:
        return [f"Echo has no subject part '{subject}' (tag it with .conformanceTag(\"{subject}\"))"], []
    for name in sorted(ref_parts):
        ref_part = ref_parts[name]
        if ref_part.get("disappearedAt") is not None and ref_part["disappearedAt"] < ref_shot.get("settle", 1.5):
            continue   # gone before the screenshot
        bucket = expected if name in known else findings
        if name not in echo_parts:
            bucket.append(f"{name}: missing in Echo" + (f" (expected: {known[name]})" if name in known else ""))
            continue
        a, b = relative(ref_part, ref_parts[subject]), relative(echo_parts[name], echo_parts[subject])
        deltas = [f"{k} {a[k]:.1f} → {b[k]:.1f}" for k in ("x", "y", "width", "height") if abs(a[k] - b[k]) > FRAME_TOLERANCE]
        if deltas:
            bucket.append(f"{name}: " + ", ".join(deltas) + (f" (expected: {known[name]})" if name in known else ""))
    extra = sorted(set(echo_parts) - set(ref_parts))
    if extra:
        expected.append("Echo tags parts the reference doesn't: " + ", ".join(extra))
    return findings, expected


def compare_timeline(ref_shot, echo_shot, known):
    findings = []
    for name, ref_part in sorted(ref_shot["parts"].items()):
        if name in known:
            continue
        echo_part = echo_shot["parts"].get(name)
        if not echo_part:
            continue
        a, b = ref_part.get("disappearedAt"), echo_part.get("disappearedAt")
        if a is None and b is None:
            continue
        if a is None or b is None:
            findings.append(f"{name}: " + (f"goes away at {b:.2f}s in Echo, stays in the reference" if a is None
                                           else f"goes away at {a:.2f}s in the reference, stays in Echo"))
        elif abs(a - b) > TIME_TOLERANCE:
            findings.append(f"{name}: goes away at {a:.2f}s in the reference, {b:.2f}s in Echo")
    return findings


def crop(image, part, scale):
    box = tuple(round(v * scale) for v in (part["x"], part["y"], part["x"] + part["width"], part["y"] + part["height"]))
    return image.crop(box)


def label_font():
    from PIL import ImageFont
    for path in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, 18)
        except (OSError, ImportError):   # Pillow built without FreeType
            break
    return ImageFont.load_default()


def compare_pixels(ref_dir, echo_dir, ref_shot, echo_shot, subject, known=()):
    from PIL import Image, ImageDraw
    import numpy as np
    ref = crop(Image.open(ref_dir / ref_shot["image"]).convert("RGB"), ref_shot["parts"][subject], ref_shot["scale"])
    echo = crop(Image.open(echo_dir / echo_shot["image"]).convert("RGB"), echo_shot["parts"][subject], echo_shot["scale"])
    # Both on one canvas, top-left aligned (the subject's corner), so a size difference shows as
    # a difference instead of being scaled away.
    resized = echo.size != ref.size
    width, height = max(ref.size[0], echo.size[0]), max(ref.size[1], echo.size[1])
    def padded(image):
        canvas = Image.new("RGB", (width, height), (255, 0, 255))
        canvas.paste(image, (0, 0))
        return np.asarray(canvas, dtype=np.int16)
    a, b = padded(ref), padded(echo)
    mask = np.abs(a - b).max(axis=2) > PIXEL_THRESHOLD
    # Parts with a known difference are left out of the score (drawn hatched in the diff).
    counted = np.ones(mask.shape, dtype=bool)
    for shot in (ref_shot, echo_shot):
        origin = shot["parts"][subject]
        for key in known:
            part = shot["parts"].get(key.removeprefix("pixels:"))
            if part:
                x0, y0 = (round((part[k] - origin[k]) * shot["scale"]) for k in ("x", "y"))
                x1, y1 = x0 + round(part["width"] * shot["scale"]), y0 + round(part["height"] * shot["scale"])
                counted[max(y0, 0):max(y1, 0), max(x0, 0):max(x1, 0)] = False
    share = float(mask[counted].mean()) if counted.any() else 0.0
    heat = (np.asarray(Image.fromarray(a.astype(np.uint8)).convert("L").convert("RGB"), dtype=np.uint8) // 3 + 120)
    heat[mask] = [230, 40, 40]
    hatch = ~counted & ((np.add.outer(np.arange(height), np.arange(width)) // 6) % 2 == 0)
    heat[hatch] = [150, 150, 220]
    label = 28
    panel = Image.new("RGB", (width * 3 + 40, height + label), (250, 250, 250))
    draw = ImageDraw.Draw(panel)
    font = label_font()
    title = f"{ref_shot['state']}, {ref_shot['appearance']}"
    for index, (name, image) in enumerate([("Accepted (Echo Labs)", ref), ("Echo", echo), (f"Diff {share:.1%}", Image.fromarray(heat))]):
        x = index * (width + 20)
        draw.text((x + 4, 4), f"{name}  |  {title}", fill=(20, 20, 20), font=font)
        panel.paste(image, (x, label))
    return share, resized, panel


def check(page, app, capture=True):
    ref_dir = REFERENCES / page
    contract_file = ref_dir / "contract.json"
    if not contract_file.exists():
        fail(f"no reference for {page}; capture it first with --reference")
    contract = json.loads(contract_file.read_text())
    app = Path(app) if app else newest_echo_app()
    executable = app / "Contents/MacOS/Echo"
    out = RESULTS / page
    if capture:
        print(f"Capturing Echo ({app})…")
        run_capture(executable, {"page": page, "out": str(out), "appearances": APPEARANCES,
                                 "states": [{k: s[k] for k in ("id", "settle", "observe")} for s in contract["states"]],
                                 "width": contract["width"], "height": contract["height"]}, out)
    echo_shots = {(s["state"], s["appearance"]): s for s in json.loads((out / "capture.json").read_text())}
    subject, known = contract["subject"], contract.get("knownDifferences", {})
    settles = {s["id"]: s["settle"] for s in contract["states"]}
    titles = {s["id"]: s["title"] for s in contract["states"]}

    lines, failures, warnings, panels = [], 0, 0, []
    lines.append(f"# Conformance: {contract['title']} ({page})")
    lines.append(f"Reference: exhibit '{contract['exhibitTitle']}' with the owner's picks, captured {contract.get('capturedAt', '?')}")
    lines.append(f"Echo: {app}")
    for ref_shot in contract["shots"]:
        key = (ref_shot["state"], ref_shot["appearance"])
        ref_shot = dict(ref_shot, settle=settles.get(ref_shot["state"], 1.5))
        lines.append(f"\n## {key[0]} · {key[1]}: {titles.get(key[0], '')}")
        echo_shot = echo_shots.get(key)
        if not echo_shot:
            lines.append("FAIL  Echo did not capture this state (add it to the page's specimen)")
            failures += 1
            continue
        part_findings, expected = compare_parts(ref_shot, echo_shot, subject, known)
        timeline = compare_timeline(ref_shot, echo_shot, known)
        for finding in part_findings:
            lines.append(f"FAIL  PARTS     {finding}")
        for finding in timeline:
            lines.append(f"FAIL  TIMELINE  {finding}")
        for note in expected:
            lines.append(f"ok    EXPECTED  {note}")
        for key, reason in sorted(known.items()):
            if key.startswith("pixels:") and key[7:] in echo_shot["parts"]:
                lines.append(f"ok    EXPECTED  pixels of {key[7:]} left out: {reason}")
        failures += len(part_findings) + len(timeline)
        if subject in ref_shot["parts"] and subject in echo_shot["parts"]:
            share, resized, panel = compare_pixels(ref_dir, out, ref_shot, echo_shot, subject, known)
            panels.append(panel)
            status = "WARN" if share > PIXEL_WARN_SHARE else "ok  "
            warnings += status == "WARN"
            lines.append(f"{status}  PIXELS    {share:.1%} of the subject differs" + (" (the subjects differ in size)" if resized else "")
                         + (" (known differences left out)" if any(k in echo_shot["parts"] for k in known) else ""))
        if not part_findings and not timeline:
            lines.append("ok    PARTS and TIMELINE match")

    if panels:
        from PIL import Image
        sheet = Image.new("RGB", (max(p.size[0] for p in panels), sum(p.size[1] + 16 for p in panels)), (255, 255, 255))
        y = 0
        for panel in panels:
            sheet.paste(panel, (0, y))
            y += panel.size[1] + 16
        sheet.save(out / "compare.png")
        lines.append(f"\nSide by side: {(out / 'compare.png').relative_to(ROOT)}")
    verdict = "FAIL" if failures else ("PASS with pixel warnings: look at compare.png" if warnings else "PASS")
    lines.append(f"\nResult: {verdict} ({failures} failing checks, {warnings} pixel warnings)")
    report = "\n".join(lines)
    (out / "report.txt").write_text(report + "\n")
    commit = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
    (ref_dir / "last-check.json").write_text(json.dumps({
        "result": verdict.split(":")[0], "failures": failures, "warnings": warnings,
        "checkedAt": datetime.now().strftime("%Y-%m-%d %H:%M"), "commit": commit,
        "findings": [line[6:].strip() for line in lines if line.startswith("FAIL")],
    }, indent=2) + "\n")
    print(report)
    sys.exit(1 if failures else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("page")
    parser.add_argument("--reference", action="store_true", help="capture the accepted round in Echo Labs")
    parser.add_argument("--app", help="the Echo.app to check (default: newest Debug build)")
    parser.add_argument("--no-capture", action="store_true", help="compare the last Echo capture again")
    args = parser.parse_args()
    if args.reference:
        capture_reference(args.page)
    else:
        check(args.page, args.app, capture=not args.no_capture)


if __name__ == "__main__":
    main()
