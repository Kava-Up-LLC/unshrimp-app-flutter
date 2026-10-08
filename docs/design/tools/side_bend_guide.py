"""Standing side bend guide: front view, feet apart, the torso bending sideways in one smooth curve, both arms raised
overhead following the curve with the hands joined above the head, the head tilted between the arms.

Built from the character's own parts: the approved overhead triceps image (torso with raised sleeves, legs, shoes),
the mountain-pose arms raised (elbows a little bent) and the mountain-pose head. The figure is built upright on a
taller canvas and then bent: the legs lean a little (hips shift away from the bend), the torso follows an arc from the
hips to the shoulders, and everything above the shoulders turns with it as one piece.
This is a guide for the harmonizing pass, never the final image.
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

S = 4; W = H = 1024; PAD = 200
BG = np.array([240, 254, 249.]); SHADOW = (165, 225, 208); SKIN = (255, 209, 170); LINE = (52, 34, 26)
yy, xx = np.mgrid[0:H, 0:W]
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def nonbg(a): return np.abs(a - BG).sum(2) > 30
def notsh(a): return np.abs(a - np.array(SHADOW)).sum(2) > 45
def navy_of(a): return (a[..., 2] > a[..., 0] + 8) & (a[..., 2] > a[..., 1] + 8) & (a[..., 0] < 110)
def teal_of(a): return (a[..., 1] > a[..., 0] + 30) & (np.abs(a[..., 1] - a[..., 2]) < 45) & (a[..., 1] > 40)
def biggest(m):
    lab, n = ndimage.label(m); return lab == np.bincount(lab[lab > 0]).argmax()
def rot(p, pivot, cw, dest):
    t = math.radians(cw); dx, dy = p[0] - pivot[0], p[1] - pivot[1]
    return (dest[0] + dx * math.cos(t) - dy * math.sin(t), dest[1] + dx * math.sin(t) + dy * math.cos(t))

BEND = 38           # degrees the torso bends sideways between the hips and the shoulders
WAIST, SHOULD = 575, 430     # the arc starts at the hips and ends at the shoulder line (upright figure)
HIPS = 40           # the hips shift away from the bend, the legs lean
# arms as in the reference: an arch. Angles in degrees cw from hanging: (upper arm, forearm and hand)
ARM_L = (190, 213)     # stretched: far arm up beside the head, a soft elbow, hand above and beyond the head
OLD_L = (187, 232)     # the arm away from the bend: up beside the head, then the forearm over the top of the head
ARM_R = (170, 147)     # stretched: bend-side arm almost straight up beside the head to the other hand
OLD_R = (210, 140)     # the arm on the bend side: up and out, elbow open, then the forearm back in to the other hand
OLD = 0       # raised arms: upper arm up and a little out, forearm up and in (degrees cw from hanging), mirrored for the other arm
DX = -51            # the whole figure moves left: the hands end up far to the right

# ---------------------------------------------------------------- upright figure on a taller canvas
tri = np.asarray(Image.open('tri.png').convert('RGB')).astype(int).copy()
mt = np.asarray(Image.open('mountain.png').convert('RGB')).astype(int).copy()
face = (xx > 462) & (xx < 562) & (yy > 126) & (yy < 160)                                    # hard rule 1: nothing at eye height
lab, n = ndimage.label(mt.max(2) < 150); hair = lab == lab[80, 510]
mt[ndimage.binary_dilation((mt.max(2) < 150) & face & ~hair, iterations=2) & face & ~hair] = SKIN
mfig = nonbg(mt) & notsh(mt)
head = (mfig & (yy < 234) & (xx > 400) & (xx < 625)) | (mfig & (yy >= 234) & (yy < 250) & (xx > 484) & (xx < 538))
skinm = mfig & ~teal_of(mt) & ~navy_of(mt)
armL = ndimage.binary_fill_holes(biggest(skinm & (xx > 350) & (xx < 414) & (yy > 386) & (yy < 620)))
armR = ndimage.binary_fill_holes(biggest(skinm & (xx > 596) & (xx < 674) & (yy > 388) & (yy < 620)))
mtI = Image.fromarray(mt.astype('uint8'))
tri[(yy < 222) & True] = BG.astype(int)                                                     # the folded arms and the head of the triceps image go

TW, TH = W, H + PAD
up = Image.new('RGB', (TW, TH), tuple(int(v) for v in BG)); up.paste(Image.fromarray(tri.astype('uint8')), (0, PAD))
def place(img, mask, pivot, cw, dest):
    big = Image.new('RGB', (TW, TH), tuple(int(v) for v in BG)); big.paste(img, (0, PAD)); bm = Image.new('L', (TW, TH), 0); bm.paste(mask, (0, PAD))
    pv = (pivot[0], pivot[1] + PAD); kw = dict(center=pv, translate=(dest[0] - pivot[0], dest[1] - pivot[1]))
    return big.rotate(-cw, resample=Image.BICUBIC, **kw), bm.rotate(-cw, resample=Image.BICUBIC, **kw)
def capsule(p0, r0, p1, r1):
    m = Image.new('L', (TW * 2, TH * 2), 0); d = ImageDraw.Draw(m)
    (x0, y0), (x1, y1) = [(p[0] * 2, (p[1] + PAD) * 2) for p in (p0, p1)]; r0 *= 2; r1 *= 2
    ang = math.atan2(y1 - y0, x1 - x0); nx, ny = -math.sin(ang), math.cos(ang)
    d.polygon([(x0 + nx * r0, y0 + ny * r0), (x1 + nx * r1, y1 + ny * r1), (x1 - nx * r1, y1 - ny * r1), (x0 - nx * r0, y0 - ny * r0)], fill=255)
    for (x, y), rr in (((x0, y0), r0), ((x1, y1), r1)): d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
    return m.resize((TW, TH), Image.LANCZOS)
def paint(m, col, line=None):
    if line: up.paste(Image.new('RGB', up.size, line), (0, 0), m.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(0.7)))
    up.paste(Image.new('RGB', up.size, col), (0, 0), m)

handm = Image.new('L', (TW, TH), 0)
def arm(mask, atop, hem, angles):
    """One raised arm from the sleeve hem: upper arm to the elbow, then the forearm and hand."""
    ua, fa = angles; elb_y = atop[1] + 58
    upd = (-math.sin(math.radians(ua)), math.cos(math.radians(ua)))
    dest = (hem[0] + 25 * upd[0], hem[1] + 25 * upd[1])                                     # 25px of arm between the hem and the piece: full arm length
    paint(capsule((hem[0] - 8 * upd[0], hem[1] - 8 * upd[1]), 21, (dest[0] + 30 * upd[0], dest[1] + 30 * upd[1]), 20), SKIN, LINE)
    elb = (atop[0], elb_y); el = rot(elb, atop, ua, dest)
    aI, aM = place(mtI, L(mask & (yy < elb_y + 8)), atop, ua, dest); up.paste(aI, (0, 0), aM)
    wr = (atop[0], atop[1] + 158)
    aI, aM = place(mtI, L(mask & (yy >= elb_y - 8) & (yy < wr[1] + 4)), elb, fa, el); up.paste(aI, (0, 0), aM)   # the arm ends at the wrist: the hands are clasped
    paint(capsule(el, 17, el, 17), SKIN)                                                     # round elbow, no notch
    w = rot(wr, elb, fa, el); WRISTS.append(w); print('elbow', [round(v) for v in el], 'wrist', [round(v) for v in w])
WRISTS = []
def clasp():
    """Both hands clasped with the fingers interlaced: one compact shape above the wrists (only a guide; the pass redraws it)."""
    (xa, ya), (xb, yb) = WRISTS; cx, cy = (xa + xb) / 2, (ya + yb) / 2 - 30
    m = Image.new('L', (TW * 2, TH * 2), 0); d = ImageDraw.Draw(m)
    d.ellipse([(cx - 37) * 2, (cy - 30 + PAD) * 2, (cx + 37) * 2, (cy + 34 + PAD) * 2], fill=255)
    paint(m.resize((TW, TH), Image.LANCZOS), SKIN, LINE)
    d = ImageDraw.Draw(up)
    for i, dx in enumerate((-22, -8, 6, 20)):                                                 # interlaced fingers: short alternating strokes over the top
        t = 9 if i % 2 else -9
        d.line([(cx + dx - t, cy - 26 + PAD), (cx + dx + t, cy + 2 + PAD)], fill=LINE, width=3)
    d.line([(cx - 30, cy + 12 + PAD), (cx + 28, cy + 14 + PAD)], fill=LINE, width=3)          # the thumbs across
SHIRT = (10, 123, 127); SHIRT_LINE = (9, 62, 68)
ti = Image.fromarray(tri.astype('uint8'))
# the sleeve on the bend side follows its arm (up and out): the straight-up sleeve of the triceps image goes
tri2 = np.asarray(up).copy(); tyy, txx = np.mgrid[0:TH, 0:TW]
tri2[(txx > 568) & (tyy < 266 + PAD) & (tyy > PAD + 150)] = BG.astype(int); up = Image.fromarray(tri2)
arm(armR, (637, 392), (604, 190), ARM_R)
arm(armL, (385, 388), (421, 190), ARM_L)
clasp()
# sleeves: the shoulders rise with the arms. Left: the straight sleeve grows 36px. Right: a tube along the upper arm.
paint(capsule((411, 236), 30, (420, 194), 28), SHIRT, SHIRT_LINE); paint(capsule((411, 264), 27, (413, 228), 27), SHIRT)
paint(capsule((613, 236), 30, (604, 194), 28), SHIRT, SHIRT_LINE); paint(capsule((613, 264), 27, (611, 228), 27), SHIRT)
# sleeve hems over the arms, then the head in front of the arms
up.paste(mtI, (0, PAD), L(head))
hm = Image.new('L', (TW, TH), 0); hm.paste(L(head), (0, PAD))
up.save('upright.png')

# ---------------------------------------------------------------- bend: inverse map from the bent picture to the upright one
phi1 = math.radians(BEND); S1 = WAIST - SHOULD; R = S1 / phi1
P0 = (512 - HIPS, WAIST); C = (P0[0] + R, P0[1])
O1 = (C[0] - R * math.cos(phi1), C[1] - R * math.sin(phi1)); t = (math.sin(phi1), -math.cos(phi1)); nrm = (math.cos(phi1), math.sin(phi1))
oy, ox = np.mgrid[0:H, 0:W].astype(float); ox -= DX
vx, vy = ox - C[0], oy - C[1]
u = (ox - O1[0]) * t[0] + (oy - O1[1]) * t[1]
phi = np.arctan2(-vy, -vx)
x1 = ox.copy(); y1 = oy.copy()
above = oy < WAIST
rig = above & (u > 0)                                                                         # beyond the end of the arc: one rigid piece
arc = above & ~rig & (vx < 0) & (phi >= 0) & (phi <= phi1)
x1[arc] = P0[0] + (R - np.hypot(vx, vy))[arc]; y1[arc] = WAIST - (phi * R)[arc]
x1[rig] = P0[0] + ((ox - O1[0]) * nrm[0] + (oy - O1[1]) * nrm[1])[rig]; y1[rig] = SHOULD - u[rig]
x1[above & ~rig & ~arc] = -5000                                                                # nothing maps here: background
xs = x1 + HIPS * np.clip((900 - y1) / (900 - WAIST), 0, 1); ys = y1 + PAD
ua = np.asarray(up).astype(float)
out = np.stack([ndimage.map_coordinates(ua[..., c], [ys, xs], order=1, mode='constant', cval=float(BG[c])) for c in range(3)], -1)
hz = ndimage.map_coordinates(np.asarray(hm).astype(float), [ys, xs], order=1, mode='constant', cval=0) > 127
img = Image.fromarray(np.clip(out, 0, 255).astype('uint8')); img.save('guide.png'); L(hz).save('head_zone.png')
# handm.paste(0, (0, 0), hm)                                                                   # the part of the hands behind the head is not seen
L(ndimage.map_coordinates(np.asarray(handm).astype(float), [ys, xs], order=1, mode='constant', cval=0) > 127).save('hands_zone.png')
a = np.asarray(img).astype(int); f = nonbg(a) & notsh(a); fx = np.where(f.any(0))[0]; fy = np.where(f.any(1))[0]
print('bbox', fx.min(), fx.max(), fy.min(), fy.max(), 'center', (fx.min() + fx.max()) / 2)
