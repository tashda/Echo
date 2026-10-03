#!/usr/bin/env python3
"""Builds hatch-design.html from its parts (run inside design-page/)."""
head = ''.join(open(f).read() for f in ['p1-head.html', 'p2a.html', 'p2b.html'])
js = ''.join(open(f).read() for f in ['p3a.js','p3b.js','p3c.js','p3d.js','p3e.js','p3f.js','p3g.js','p4.js'])
open('hatch-design.html', 'w').write(head + '<script>\n' + js + '</script>\n')
