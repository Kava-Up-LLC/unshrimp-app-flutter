"""Overhead triceps: raised shoulders. Replaces the boxy sleeves with sleeves that follow the raised arms.

With an arm raised, the sleeve is a tube around the upper arm pointing up, and the side of the shirt runs
in one smooth line from the torso up into the outer edge of that sleeve. No horizontal ledge, no box.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

S = 4; BG = (240, 254, 249); SHIRT = (10, 123, 127); SHIRT_LINE = (9, 62, 68)
src = sys.argv[1] if len(sys.argv) > 1 else 'final_b.png'
im = Image.open(src).convert('RGB'); a = np.asarray(im).astype(int)
H, W = a.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
skin = (a[..., 0] > 200) & (a[..., 0] - a[..., 2] > 40)

def spline(p, n=14):
    p = np.array([p[0]] + list(p) + [p[-1]], float); out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * ((2 * p[i]) + (-p[i-1] + p[i+1]) * t + (2*p[i-1] - 5*p[i] + 4*p[i+1] - p[i+2]) * t*t + (-p[i-1] + 3*p[i] - 3*p[i+1] + p[i+2]) * t**3))
    out.append(p[-2]); return [tuple(q) for q in out]

# viewer's left side; the right side is its mirror about x = 511 (shifted 1px out, that arm leans a little)
OUTER = [(381, 224), (380, 262), (382, 296), (389, 326), (400, 354), (411, 382), (415, 404), (415, 416)]
INNER = [(440, 222), (442, 240), (449, 256), (460, 268)]
SEAM = [(390, 328), (408, 312), (428, 290), (444, 262)]
out = im.copy()
for mirror in (False, True):
    mx = (lambda x: 1023 - x) if mirror else (lambda x: x)
    M = lambda pts: [(mx(x), y) for x, y in pts]
    side = (xx > 511) if mirror else (xx < 511)
    # 1) clear the old box and its ledge (keep the skin of the arm above the hem)
    o = np.asarray(out).copy()
    box = side & (yy > 222) & (yy < 404) & ((xx > 598) if mirror else (xx < 424)) & ~skin
    o[box] = BG
    out = Image.fromarray(o); big = out.resize((W * S, H * S), Image.LANCZOS); d = ImageDraw.Draw(big)
    P = lambda pts: [(x * S, y * S) for x, y in pts]
    outer, inner = spline(M(OUTER)), spline(M(INNER))
    torso = M([(430, 416), (470, 416), (470, 270)])
    d.polygon(P(outer + torso + inner[::-1]), fill=SHIRT)
    w = int(3.2 * S)
    d.line(P(outer), fill=SHIRT_LINE, width=w, joint='curve')
    d.line(P(inner), fill=SHIRT_LINE, width=w, joint='curve')
    d.line(P([M(OUTER)[0], M(INNER)[0]]), fill=SHIRT_LINE, width=w)                    # sleeve hem
    d.line(P(spline(M(SEAM))), fill=SHIRT_LINE, width=int(2.4 * S), joint='curve')      # armhole seam
    for q in (outer[0], inner[0]): d.ellipse([q[0] * S - w / 2, q[1] * S - w / 2, q[0] * S + w / 2, q[1] * S + w / 2], fill=SHIRT_LINE)
    out = big.resize((W, H), Image.LANCZOS)
out.save('guide_shoulders.png')
sh = Image.new('RGB', (900 + 20 + 512, 800), 'white')
sh.paste(out.crop((340, 150, 700, 470)).resize((900, 800), Image.LANCZOS), (0, 0)); sh.paste(out.resize((512, 512), Image.LANCZOS), (920, 0)); sh.save('guide_shoulders_view.png')
