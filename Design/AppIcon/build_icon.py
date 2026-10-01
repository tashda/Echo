#!/usr/bin/env python3
"""Builds Echo's app icons: three rows on a squircle, in three looks.

  EchoIcon.svg        Light  (default)  white-to-grey tile
  EchoIcon-Navy.svg   Navy   (dark appearance)
  EchoIcon-Labs.svg   Acid   (Echo Labs)
  EchoMark.svg        the three rows alone, for the start page (no tile)

Usage (macOS):  python3 Design/AppIcon/build_icon.py
Writes the SVG masters here and renders 1024 px PNG masters next to them
(via headless Chrome). `render_sizes` then cuts the
smaller sizes with sips.
"""
import math, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Apple-like continuous squircle (superellipse); 824 pt inside the 1024 grid.
def squircle(cx, cy, r, n=4.8, steps=360):
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        pts.append(f"{cx + r * math.copysign(abs(c) ** (2 / n), c):.2f},{cy + r * math.copysign(abs(s) ** (2 / n), s):.2f}")
    return "M" + " L".join(pts) + "Z"

SQ = squircle(512, 512, 412)
W, H = 424, 128
POS = [(206, 290), (300, 448), (394, 606)]  # the three rows, centred on the tile

def stops(*cs):
    offs = [0, .5, .88, 1] if len(cs) == 4 else [0, 1]
    return list(zip(offs, cs))

ECHO_ROWS = [stops("#8B4BFF", "#6F6CFF", "#2AA9FF", "#2ACBFF"),
             stops("#9166F0", "#A660D6", "#FF6E60", "#FF9B78"),
             stops("#FFA087", "#FF7C8C", "#FF5AA3", "#FF78B8")]
ECHO_GLOW = ["#2AA9FF", "#FF6E60", "#FF5AA3"]
ACID_ROWS = [stops("#00C2D4", "#00D6B0", "#2BE88A", "#5CF59A"),
             stops("#12C97A", "#3FDC5A", "#8CEB3A", "#C6F54A"),
             stops("#9BE63A", "#C6EE3A", "#F0F03A", "#FFF26B")]
ACID_GLOW = ["#2BE88A", "#8CEB3A", "#F0F03A"]

# name: (file, tile gradient top/bottom, rows, glow colours, dark?)
LOOKS = {
    "light": ("EchoIcon.svg", "#FFFFFF", "#D8DBEC", ECHO_ROWS, ECHO_GLOW, False),
    "navy": ("EchoIcon-Navy.svg", "#3A3B5C", "#25263E", ECHO_ROWS, ECHO_GLOW, True),
    "labs": ("EchoIcon-Labs.svg", "#15201D", "#080C0B", ACID_ROWS, ACID_GLOW, True),
}

def linear(i, st, x2=1, y2=.25):
    body = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in st)
    return f'<linearGradient id="{i}" x1="0" y1="0" x2="{x2}" y2="{y2}">{body}</linearGradient>'

def row(i, x, y, glow, dark):
    r = H / 2
    glow_op, sheen_op = (.5, .4) if dark else (.35, .45)
    out = f'<rect x="{x}" y="{y + 22}" width="{W}" height="{H}" rx="{r}" fill="{glow}" filter="url(#soft)" opacity="{glow_op}"/>'
    out += f'<clipPath id="c{i}"><rect x="{x}" y="{y}" width="{W}" height="{H}" rx="{r}"/></clipPath>'
    out += f'<rect x="{x}" y="{y}" width="{W}" height="{H}" rx="{r}" fill="url(#p{i})"/>'
    out += f'<g clip-path="url(#c{i})"><rect x="{x}" y="{y}" width="{W}" height="{H * .5}" fill="url(#sheen)" opacity="{sheen_op}"/></g>'
    if dark:
        out += f'<rect x="{x + 1.5}" y="{y + 1.5}" width="{W - 3}" height="{H - 3}" rx="{r - 1.5}" fill="none" stroke="url(#rim)" stroke-width="3" opacity=".35"/>'
    return out

def build(name):
    file, top, bottom, rows, glows, dark = LOOKS[name]
    defs = linear("tile", [(0, top), (1, bottom)], 0, 1)
    for i, st in enumerate(rows):
        defs += linear(f"p{i}", st)
    defs += ('<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
             '<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".9"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity=".35"/></linearGradient>'
             '<filter id="soft" x="-30%" y="-80%" width="160%" height="300%"><feGaussianBlur stdDeviation="16"/></filter>')
    tile = '<rect x="60" y="60" width="904" height="904" fill="url(#tile)"/>'
    if dark:
        defs += '<linearGradient id="top" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".08"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
        tile += '<rect x="60" y="60" width="904" height="500" fill="url(#top)"/>'
    rows_svg = "".join(row(i, x, y, glows[i], dark) for i, (x, y) in enumerate(POS))
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
           f'<defs><clipPath id="sq"><path d="{SQ}"/></clipPath>{defs}</defs>'
           f'<g clip-path="url(#sq)">{tile}{rows_svg}</g></svg>\n')
    with open(os.path.join(HERE, file), "w") as f:
        f.write(svg)
    return file

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

def render_master(svg_file):
    """1024 px PNG master with a transparent margin, via headless Chrome."""
    svg = os.path.join(HERE, svg_file)
    png = svg.replace(".svg", ".png")
    page = png + ".html"
    with open(page, "w") as f:
        f.write(f'<!doctype html><body style="margin:0;background:transparent"><img src="file://{svg}" width="1024" height="1024" style="display:block">')
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--default-background-color=00000000", "--window-size=1024,1024",
                    f"--screenshot={png}", f"file://{page}"], check=True, capture_output=True)
    os.remove(page)
    return png

# The rows without the tile, on a tight 568 x 388 canvas (start page).
def build_mark():
    rows, defs, body = ECHO_ROWS, "", ""
    for i, st in enumerate(rows):
        defs += linear(f"p{i}", st)
        x, y = i * 84, i * 138
        body += (f'<clipPath id="c{i}"><rect x="{x}" y="{y}" width="400" height="112" rx="56"/></clipPath>'
                 f'<rect x="{x}" y="{y}" width="400" height="112" rx="56" fill="url(#p{i})"/>'
                 f'<g clip-path="url(#c{i})"><rect x="{x}" y="{y}" width="400" height="56" fill="url(#sheen)" opacity=".4"/></g>')
    defs += '<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
    with open(os.path.join(HERE, "EchoMark.svg"), "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="568" height="388" viewBox="0 0 568 388"><defs>{defs}</defs>{body}</svg>\n')

def render_mark(out_dir, width=120):
    """PNGs at 1x/2x/3x of a `width` pt mark, transparent, via headless Chrome."""
    svg = os.path.join(HERE, "EchoMark.svg")
    for scale in (1, 2, 3):
        w = width * scale
        h = round(w * 388 / 568)
        page = os.path.join(HERE, "mark.html")
        with open(page, "w") as f:
            f.write(f'<!doctype html><body style="margin:0;background:transparent"><img src="file://{svg}" width="{w}" height="{h}" style="display:block">')
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--default-background-color=00000000", f"--window-size={w},{h}",
                        f"--screenshot={os.path.join(out_dir, f'EchoMark@{scale}x.png')}", f"file://{page}"],
                       check=True, capture_output=True)
        os.remove(page)

def render_sizes(master, out_dir, prefix, sizes=(16, 32, 64, 128, 256, 512, 1024)):
    for s in sizes:
        out = os.path.join(out_dir, f"{prefix}-{s}.png")
        if s == 1024:
            subprocess.run(["cp", master, out], check=True)
        else:
            subprocess.run(["sips", "-z", str(s), str(s), master, "--out", out], check=True, capture_output=True)

if __name__ == "__main__":
    for look in LOOKS:
        print(render_master(build(look)))
    build_mark()
