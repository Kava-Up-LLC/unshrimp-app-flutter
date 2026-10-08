"""Standing forward fold guide: profile facing left, someone bending down to touch the toes.

Legs almost vertical (hips do not stick out), back rounded and sloping down to the shoulders, head hanging,
both arms straight and equal reaching the toes. Built from the character's own parts: legs and shoe of the
profile master, torso and head of the approved calf stretch (mirrored, bent strip by strip along the spine),
and the arm of the mountain pose twice (same piece, so both arms and hands are the same size).
This is a guide for the harmonizing pass, never the final image.
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

S = 4; W = H = 1024
BG = np.array([240, 254, 249.]); SHADOW = (165, 225, 208); SHIRT = (10, 123, 127); SHIRT_LINE = (9, 62, 68)
SKIN = (255, 209, 170); LINE = (52, 34, 26); NAVY = (39, 49, 78); NAVY_LINE = (22, 24, 40)
yy, xx = np.mgrid[0:H, 0:W]
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def nonbg(a): return np.abs(a - BG).sum(2) > 30
def notsh(a): return np.abs(a - np.array(SHADOW)).sum(2) > 45
def navy_of(a): return (a[..., 2] > a[..., 0] + 8) & (a[..., 2] > a[..., 1] + 8) & (a[..., 0] < 110)
def teal_of(a): return (a[..., 1] > a[..., 0] + 30) & (np.abs(a[..., 1] - a[..., 2]) < 45) & (a[..., 1] > 40)
def biggest(m):
    lab, n = ndimage.label(m); return lab == np.bincount(lab[lab > 0]).argmax()
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
def union(*ms):
    o = ms[0]
    for m in ms[1:]: o = Image.fromarray(np.maximum(np.asarray(o), np.asarray(m)))
    return o
def paint(c, m, col): c.paste(Image.new('RGB', c.size, col), (0, 0), m)
def outlined(c, layers, lw=3, line=LINE):
    u = union(*[m for m, _ in layers])
    paint(c, u.filter(ImageFilter.MaxFilter(2 * lw + 1)).filter(ImageFilter.GaussianBlur(0.7)), line)
    for m, col in layers: paint(c, m, col)
def rot(p, pivot, cw, dest):
    t = math.radians(cw); dx, dy = p[0] - pivot[0], p[1] - pivot[1]
    return (dest[0] + dx * math.cos(t) - dy * math.sin(t), dest[1] + dx * math.sin(t) + dy * math.cos(t))
def place(img, mask, pivot, cw, dest):
    kw = dict(center=pivot, translate=(dest[0] - pivot[0], dest[1] - pivot[1]))
    return img.rotate(-cw, resample=Image.BICUBIC, **kw), mask.rotate(-cw, resample=Image.BICUBIC, **kw)

SHIN, THIGH = 2, 4  # soft knees: the shin leans back 3 degrees about the ankle, the thigh 8 about the knee (hips stay over the heels)
A0, A1, POW = 4, 30, 1.3     # the back: degrees below horizontal at the hips and at the shoulders (rounded, sloping down)
HEAD = 50           # the head looks forward and down (90 = face straight down, less = more forward); it does not hang toward the legs
NECKUP = 24         # the neck comes out of the shoulders more level with the back (the head is carried higher, not hanging)
NEAR, FAR = (22, 32), (19, 29)   # arms, degrees from vertical toward the feet: (upper arm, forearm). Elbows a little bent, never two parallel sticks
SPINE = 258

# ---------------------------------------------------------------- legs and shoe of the profile master (faces left)
ma = np.asarray(Image.open('master.png').convert('RGB')).astype(int).copy()
fig = nonbg(ma) & notsh(ma)
leg = biggest(ndimage.binary_fill_holes(ndimage.binary_closing((fig | navy_of(ma)) & (yy >= 556) & (xx > 470) & (xx < 645), iterations=2))) & notsh(ma)
ma[leg & (yy < 640) & ~navy_of(ma)] = NAVY                                                # the hand that hangs over the thigh goes
leg = np.where(yy < 905, ndimage.binary_erosion(leg, iterations=1), leg)
maI = Image.fromarray(ma.astype('uint8'))
PIV = (573, 575); ANK = (590, 915); KNEE = (578, 745)

# ---------------------------------------------------------------- torso and head of the calf stretch, mirrored (faces left)
cf = np.asarray(Image.open('calf_final.png').convert('RGB').transpose(Image.FLIP_LEFT_RIGHT)).astype(int)
cfI = Image.fromarray(cf.astype('uint8'))
cfig = nonbg(cf) & notsh(cf)
hem = yy < 664 + (598 - xx) * (40 / 150) + 3                                              # just below the shirt hem
up = ndimage.binary_fill_holes(biggest(cfig & ~navy_of(cf) & hem))
hz = np.asarray(Image.open('calf_head_zone.png').convert('L').transpose(Image.FLIP_LEFT_RIGHT)) > 127
head = hz & ~ndimage.binary_dilation(teal_of(cf), iterations=2) & up
head = ndimage.binary_fill_holes(biggest(head))
shirt = ndimage.binary_fill_holes(ndimage.binary_closing(teal_of(cf) & up, iterations=3))
arms = up & ~ndimage.binary_dilation(head, iterations=2) & ~ndimage.binary_dilation(shirt, iterations=2) & (xx < 452) & (yy > 385) & (yy < 510)
body = biggest(up & ~ndimage.binary_dilation(head, iterations=2) & ~arms)
CPIV = (545, 716); NECK = (476, 368); SHO = (531, 458)

# ---------------------------------------------------------------- arm of the mountain pose (open hand), used for both arms
mt = np.asarray(Image.open('mountain.png').convert('RGB')).astype(int)
am = nonbg(mt) & ~teal_of(mt) & ~navy_of(mt) & (xx > 596) & (xx < 674) & (yy > 388) & (yy < 618)
am = ndimage.binary_fill_holes(biggest(am)); mtI = Image.open('mountain.png').convert('RGB'); ATOP = (637, 392); ELB = (637, 450)

def spine(t, hip):
    """Point of the bent spine, its turn (degrees) and its slope at t: 0 = hips, 1 = shoulders; rigid before 0 and beyond 1."""
    n = 60; x, y = hip; tt = min(max(t, 0), 1)
    for i in range(n):
        a = math.radians(A0 + (A1 - A0) * ((i + 0.5) / n * tt) ** POW)
        x -= SPINE * tt / n * math.cos(a); y += SPINE * tt / n * math.sin(a)
    a = math.radians(A0 + (A1 - A0) * tt ** POW)
    x -= SPINE * (t - tt) * math.cos(a); y += SPINE * (t - tt) * math.sin(a)
    return (x, y), 90 + math.degrees(a) - 3, a            # the source torso already leans 3 degrees

def lerp(tab, t):
    for (t0, v0), (t1, v1) in zip(tab, tab[1:]):
        if t <= t1: return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return tab[-1][1]
BACK = [(-0.07, 46), (0.1, 56), (0.45, 62), (0.85, 60), (1.0, 54), (1.2, 40), (1.32, 30)]     # shirt, from the spine to the back line
HEMB, HEMF = -0.03, 0.17                                                                     # the hem: slanted, the back end over the hips, the front end further up the belly
FRONT = [(0.08, 96), (0.3, 100), (0.55, 95), (0.8, 90), (1.0, 82), (1.2, 52), (1.32, 34)]    # shirt, from the spine to the belly line: loose cloth hanging
def shirt_outline(hip):
    """The shirt as one soft silhouette over the bent back: no stiff tail at the hips, the front hanging a little."""
    pts = []
    for i in range(0, 70):
        t = HEMB + (1.32 - HEMB) * i / 69; (x, y), _, a = spine(t, hip); d = lerp(BACK, t)
        pts.append((x - math.sin(a) * d, y - math.cos(a) * d))
    for i in range(0, 70):
        t = 1.32 - (1.32 - HEMF) * i / 69; (x, y), _, a = spine(t, hip); d = lerp(FRONT, t)
        pts.append((x + math.sin(a) * d, y + math.cos(a) * d))
    return pts

def build(DX, save=False):
    out = Image.new('RGB', (W * S, H * S), tuple(int(v) for v in BG))
    ImageDraw.Draw(out).ellipse([(250 + DX) * S, 938 * S, (700 + DX) * S, 990 * S], fill=SHADOW)
    out = out.resize((W, H), Image.LANCZOS)
    ank = (ANK[0] + DX, ANK[1])
    hands = []
    knee = rot(KNEE, ANK, SHIN, ank); hip = rot(PIV, KNEE, THIGH, knee)
    # legs: hips, upper thigh, then the master's thigh, shin and shoe (soft knee)
    kn = rot((PIV[0] - 8, PIV[1] + 120), KNEE, THIGH, knee)
    outlined(out, [(capsule((hip[0] - 8, hip[1] + 4), 45, kn, 44), NAVY)], line=NAVY_LINE)            # small hips: nothing sticks out behind the thigh
    lI, lM = place(maI, L(leg & (yy < 760) & (yy >= 580)), KNEE, THIGH, knee); out.paste(lI, (0, 0), lM)
    lI, lM = place(maI, L(leg & (yy < 912) & (yy >= 738)), ANK, SHIN, ank); out.paste(lI, (0, 0), lM)
    sI, sM = place(maI, L(leg & (yy >= 905)), ANK, 0, ank); out.paste(sI, (0, 0), sM)
    sh, turn, _ = spine(1, hip)
    def arm(angles, along, side):
        up, fore = angles
        d = (math.sin(math.radians(up)), math.cos(math.radians(up))); n = (-d[1], d[0])     # upper arm direction, and its normal toward the head side
        top = lambda al, sd=side: (sh[0] + al * d[0] + sd * n[0], sh[1] + al * d[1] + sd * n[1])
        paint(out, capsule(top(20), 19, top(120), 19), SKIN)
        el = rot(ELB, ATOP, -up, top(along))
        aI, aM = place(mtI, L(am & (yy < ELB[1] + 8)), ATOP, -up, top(along)); out.paste(aI, (0, 0), aM)
        aI, aM = place(mtI, L(am & (yy >= ELB[1] - 8)), ELB, -fore, el); out.paste(aI, (0, 0), aM)
        hands.append(np.asarray(place(mtI, L(am & (yy >= 618 - 84)), ELB, -fore, el)[1]) > 127)   # the hand, from the wrist down
        return top
    arm(FAR, 104, 15)                                                                          # far arm: same piece, a little toward the head, its hand beside the near one
    # head, looking forward and down
    nk = rot(NECK, SHO, -(turn - NECKUP), sh)
    neckm = capsule(nk, 24, (sh[0] + 4, nk[1] - 8), 24)                                       # throat: from under the chin into the sleeve, its end hidden under the shirt
    outlined(out, [(neckm, SKIN)], lw=2)                                                       # neck: outlined, reaching under the collar
    hI, hM = place(cfI, L(head), NECK, -HEAD, nk); out.paste(hI, (0, 0), hM)
    # shirt: one soft silhouette
    pts = shirt_outline(hip)
    sm = shape(lambda d: d.polygon([(x * S, y * S) for x, y in pts], fill=255)).filter(ImageFilter.GaussianBlur(7)).point(lambda v: 255 if v > 127 else 0).filter(ImageFilter.GaussianBlur(0.6))   # rounded corners
    outlined(out, [(sm, SHIRT)], line=SHIRT_LINE)
    # near arm and its sleeve
    top = arm(NEAR, 106, 0)
    outlined(out, [(capsule(top(4), 33, top(88), 28), SHIRT)], line=SHIRT_LINE)
    paint(out, capsule(top(-14, -4), 30, top(30), 28), SHIRT)                                  # sleeve joins the shoulder, no inner line
    a = np.asarray(out).astype(int); f = nonbg(a) & notsh(a)
    xs = np.where(f.any(0))[0]; ys = np.where(f.any(1))[0]
    if save:
        out.save('guide.png')
        L((np.asarray(hM) > 127) | (np.asarray(neckm.filter(ImageFilter.MaxFilter(7))) > 127)).save('head_zone.png'); L(hands[0] | hands[1]).save('hands_zone.png')
        print('hip', hip, 'shoulder', sh, 'neck', nk, 'turn at shoulders', turn)
    return xs.min(), xs.max(), ys.min(), ys.max()

x0, x1, y0, y1 = build(0)
DX = 98                                                                                      # fixed: the pass was made at this offset (it was the centering value before the head was raised)
print('DX', DX, 'bbox', build(DX, True))
