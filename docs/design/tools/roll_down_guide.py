"""Pilates roll down (peak) guide: three-quarter front view, legs straight, torso folded forward,
head hanging (seen from above / behind, no face), both arms hanging straight down to the floor."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

S = 4; W = H = 1024
BG = (240, 254, 249); SHADOW = (165, 225, 208); SHIRT = (10, 123, 127); SHIRT_LINE = (9, 62, 68)
SKIN = (255, 209, 170); LINE = (52, 34, 26); NAVY = (39, 49, 78); NAVY_LINE = (22, 24, 40); HAIR = (21, 36, 43)

def shape(fn):
    m = Image.new('L', (W * S, H * S), 0); fn(ImageDraw.Draw(m)); return m.resize((W, H), Image.LANCZOS)
def capsule(p0, r0, p1, r1):
    def fn(d):
        (x0, y0), (x1, y1) = p0, p1
        ang = math.atan2(y1 - y0, x1 - x0); nx, ny = -math.sin(ang), math.cos(ang)
        pts = [(x0 + nx * r0, y0 + ny * r0), (x1 + nx * r1, y1 + ny * r1), (x1 - nx * r1, y1 - ny * r1), (x0 - nx * r0, y0 - ny * r0)]
        d.polygon([(x * S, y * S) for x, y in pts], fill=255)
        for (x, y), rr in ((p0, r0), (p1, r1)): d.ellipse([(x - rr) * S, (y - rr) * S, (x + rr) * S, (y + rr) * S], fill=255)
    return shape(fn)
def spline(p, n=14):
    k = len(p); out = []
    for i in range(k):
        p0, p1, p2, p3 = (np.array(p[(i + j) % k], float) for j in (-1, 0, 1, 2))
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2*p0 - 5*p1 + 4*p2 - p3) * t*t + (-p0 + 3*p1 - 3*p2 + p3) * t**3)))
    return out
def blob(pts): return shape(lambda d: d.polygon([(x * S, y * S) for x, y in spline(pts)], fill=255))
def union(*ms):
    o = ms[0]
    for m in ms[1:]: o = Image.fromarray(np.maximum(np.asarray(o), np.asarray(m)))
    return o
def paint(c, m, col): c.paste(Image.new('RGB', c.size, col), (0, 0), m)
def outlined(c, layers, lw=3, line=LINE):
    u = union(*[m for m, _ in layers])
    paint(c, u.filter(ImageFilter.MaxFilter(2 * lw + 1)).filter(ImageFilter.GaussianBlur(0.7)), line)
    for m, col in layers: paint(c, m, col)

ref = Image.open('front_ref.png').convert('RGB'); ra = np.asarray(ref).astype(int)
yy, xx = np.mgrid[0:H, 0:W]
def shoe(x0, x1, dx):
    m = (xx >= x0) & (xx < x1) & (yy >= 899) & (np.abs(ra - np.array(BG)).sum(2) > 30) & (np.abs(ra - np.array(SHADOW)).sum(2) > 45)
    m = ndimage.binary_fill_holes(ndimage.binary_closing(m, iterations=2)) & (yy >= 899)   # outline + white inside
    mk = Image.fromarray((m * 255).astype('uint8'))
    out.paste(ref.transform(ref.size, Image.AFFINE, (1, 0, -dx, 0, 1, 0)), (0, 0), mk.transform(mk.size, Image.AFFINE, (1, 0, -dx, 0, 1, 0)))

out = Image.new('RGB', (W, H), BG)
ImageDraw.Draw(out).ellipse([300, 922, 720, 982], fill=SHADOW)
# far leg + its shoe
outlined(out, [(capsule((486, 640), 36, (512, 905), 28), NAVY)], line=NAVY_LINE); shoe(556, 646, -80)
# far arm, hanging below the head
outlined(out, [(capsule((676, 700), 20, (672, 880), 13), SKIN), (capsule((672, 890), 15, (670, 942), 9), SKIN)])
# hips + near leg + its shoe
outlined(out, [(blob([(362, 600), (368, 556), (396, 532), (450, 528), (510, 560), (522, 640), (486, 690), (384, 690)]), NAVY),
               (capsule((408, 640), 38, (398, 905), 28), NAVY)], line=NAVY_LINE); shoe(376, 466, -14)
# torso: rounded back arching over to the right and down
outlined(out, [(blob([(404, 606), (410, 548), (460, 516), (540, 510), (620, 540), (672, 596), (692, 660), (668, 704), (616, 694), (566, 668), (500, 656), (436, 648)]), SHIRT)], line=SHIRT_LINE)
# head hanging: seen from above / behind -> hair with the nape and one ear
outlined(out, [(blob([(588, 644), (628, 624), (678, 644), (718, 694), (722, 754), (688, 796), (638, 800), (594, 764), (576, 704)]), HAIR)], line=HAIR)
outlined(out, [(blob([(580, 654), (618, 630), (658, 636), (650, 672), (618, 694), (588, 704)]), SKIN)])                  # nape
outlined(out, [(capsule((594, 710), 11, (598, 726), 9), SKIN)])                                                          # ear
# near arm in front of the legs: sleeve over the shoulder, arm, open hand
outlined(out, [(capsule((548, 690), 20, (542, 880), 13), SKIN), (capsule((542, 890), 15, (542, 944), 9), SKIN)])
outlined(out, [(blob([(512, 600), (530, 566), (566, 560), (590, 590), (588, 660), (572, 694), (526, 694), (514, 650)]), SHIRT)], line=SHIRT_LINE)
ImageDraw.Draw(out).polygon([(524, 560), (592, 566), (584, 610), (520, 606)], fill=SHIRT)
out.save('guide.png'); out.resize((800, 800), Image.LANCZOS).save('guide_view.png')
