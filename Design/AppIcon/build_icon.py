import math
# Apple-like continuous squircle (superellipse) path
def squircle(cx,cy,r,n=4.8,steps=360):
    pts=[]
    for i in range(steps):
        t=2*math.pi*i/steps
        c,s=math.cos(t),math.sin(t)
        x=cx+r*math.copysign(abs(c)**(2/n),c); y=cy+r*math.copysign(abs(s)**(2/n),s)
        pts.append(f"{x:.2f},{y:.2f}")
    return "M"+" L".join(pts)+"Z"
SQ=squircle(512,512,412)
W,H,R=400,112,56
rows=[(228.5,318.5),(312.5,456.5),(396.5,594.5)]
def row(i,x,y):
    return f'''
  <g id="row{i}">
   <!-- wide soft glow -->
   <rect x="{x}" y="{y+16}" width="{W}" height="{H}" rx="{R}" fill="url(#g{i})" filter="url(#blurL)" opacity="{[.7,.7,.85][i-1]}"/>
   <!-- tight glow -->
   <rect x="{x}" y="{y}" width="{W}" height="{H}" rx="{R}" fill="url(#g{i})" filter="url(#blurS)" opacity=".8"/>
   <!-- glass body -->
   <rect x="{x}" y="{y}" width="{W}" height="{H}" rx="{R}" fill="url(#g{i})"/>
   <rect x="{x}" y="{y}" width="{W}" height="{H}" rx="{R}" fill="url(#body{i})" style="mix-blend-mode:screen"/>
   <rect x="{x}" y="{y}" width="{W}" height="{H}" rx="{R}" fill="url(#depth)"/>
   <!-- inner colored bloom -->
   <ellipse cx="{x+W*[.82,.78,.86][i-1]}" cy="{y+H*.55}" rx="{W*.26}" ry="{H*.62}" fill="url(#bloom{i})" clip-path="url(#clip{i})" filter="url(#blurM)"/>
   <!-- rim: bright top edge, soft bottom edge -->
   <rect x="{x+1.5}" y="{y+1.5}" width="{W-3}" height="{H-3}" rx="{R-1.5}" fill="none" stroke="url(#rim)" stroke-width="2.5"/>
   <!-- specular sheen -->
   <path d="M{x+R*.9},{y+7} H{x+W-R*.9} Q{x+W-R*.35},{y+7} {x+W-R*.2},{y+R*.42} Q{x+W-R*.55},{y+H*.34} {x+W-R*1.4},{y+H*.34} H{x+R*1.4} Q{x+R*.55},{y+H*.34} {x+R*.2},{y+R*.42} Q{x+R*.35},{y+7} {x+R*.9},{y+7}Z" fill="url(#sheen)"/>
  </g>'''
grads = {
 1:("#8B4BFF","#6F6CFF","#2AA9FF","#2ACBFF"),
 2:("#9166F0","#A660D6","#FF6E60","#FF9B78"),
 3:("#FFA087","#FF7C8C","#FF5AA3","#FF78B8"),
}
defs=""
for i,(a,b,c,d) in grads.items():
    defs+=f'''
 <linearGradient id="g{i}" x1="0" y1="0" x2="1" y2="0.25"><stop offset="0" stop-color="{a}"/><stop offset=".5" stop-color="{b}"/><stop offset=".88" stop-color="{c}"/><stop offset="1" stop-color="{d}"/></linearGradient>
 <linearGradient id="body{i}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".26"/><stop offset=".4" stop-color="#fff" stop-opacity=".03"/><stop offset=".8" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity=".22"/></linearGradient>
 <radialGradient id="bloom{i}"><stop offset="0" stop-color="{c}" stop-opacity=".5"/><stop offset="1" stop-color="{c}" stop-opacity="0"/></radialGradient>
 <clipPath id="clip{i}"><rect x="{rows[i-1][0]}" y="{rows[i-1][1]}" width="{W}" height="{H}" rx="{R}"/></clipPath>'''
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
 <clipPath id="sq"><path d="{SQ}"/></clipPath>
 <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3A3B5C"/><stop offset=".55" stop-color="#2F3050"/><stop offset="1" stop-color="#25263E"/></linearGradient>
 <radialGradient id="vig" cx=".5" cy=".55" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#0d0d1e" stop-opacity=".35"/></radialGradient>
 <linearGradient id="topsheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".10"/><stop offset=".35" stop-color="#fff" stop-opacity="0"/></linearGradient>
 <linearGradient id="depth" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#1b0f3a" stop-opacity=".18"/></linearGradient>
 <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".62"/><stop offset=".25" stop-color="#fff" stop-opacity=".12"/><stop offset=".75" stop-color="#fff" stop-opacity=".06"/><stop offset="1" stop-color="#fff" stop-opacity=".38"/></linearGradient>
 <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".32"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
 <filter id="blurL" x="-40%" y="-120%" width="180%" height="340%"><feGaussianBlur stdDeviation="38"/></filter>
 <filter id="blurM" x="-50%" y="-100%" width="200%" height="300%"><feGaussianBlur stdDeviation="14"/></filter>
 <filter id="blurS" x="-20%" y="-60%" width="140%" height="220%"><feGaussianBlur stdDeviation="10"/></filter>
 {defs}
</defs>
<g clip-path="url(#sq)">
 <rect x="80" y="80" width="864" height="864" fill="url(#bg)"/>
 <rect x="80" y="80" width="864" height="864" fill="url(#vig)"/>
 <rect x="80" y="80" width="864" height="500" fill="url(#topsheen)"/>
 {''.join(row(i+1,*rows[i]) for i in range(3))}
</g>
<path d="{SQ}" fill="none" stroke="#fff" stroke-opacity=".08" stroke-width="2"/>
</svg>'''
open("EchoIcon.svg","w").write(svg)
