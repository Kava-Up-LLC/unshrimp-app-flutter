"""Standing quad stretch guide: profile facing right. Standing on one straight leg; the near knee points to the floor,
its lower leg folded up behind the thigh with the heel next to the buttock; the near hand reaches back and grips the instep.

Built from the character's own parts: the profile master mirrored (head, torso, standing leg), its own leg cut in thigh,
shin and shoe and folded at the knee, the mountain-pose arm turned back and the gripping hand of the cross-body stretch.
A front view of this pose was shown and rejected (the folded leg reads as kicking sideways, the shoe sticks out crooked).
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
def paint(c, m, col): c.paste(Image.new('RGB', c.size, col), (0, 0), m)
def outlined(c, m, col, lw=3, line=LINE):
    paint(c, m.filter(ImageFilter.MaxFilter(2 * lw + 1)).filter(ImageFilter.GaussianBlur(0.7)), line); paint(c, m, col)
def rot(p, pivot, cw, dest):
    t = math.radians(cw); dx, dy = p[0] - pivot[0], p[1] - pivot[1]
    return (dest[0] + dx * math.cos(t) - dy * math.sin(t), dest[1] + dx * math.sin(t) + dy * math.cos(t))
def place(img, mask, pivot, cw, dest):
    kw = dict(center=pivot, translate=(dest[0] - pivot[0], dest[1] - pivot[1]))
    return img.rotate(-cw, resample=Image.BICUBIC, **kw), mask.rotate(-cw, resample=Image.BICUBIC, **kw)

DX = 40             # the whole figure moves right: the held foot sticks out behind
THIGH = 28          # the thigh of the bent leg swings back about the hip: the knee points to the floor, a little behind
SHIN = 162          # its lower leg turns about the knee: 180 = flat against the thigh
FOOT = 198          # the shoe about the ankle: toe pointing back, sole up, foot stretched by the hand
ARM = 25            # the holding arm, degrees from vertical toward the back

# ---------------------------------------------------------------- the profile master, mirrored (faces right)
ma = np.asarray(Image.open('master.png').convert('RGB')).astype(int).copy()
fig = nonbg(ma) & notsh(ma)
brow = (xx >= 484) & (xx <= 518) & (yy >= 124) & (yy <= 148) & (ma.max(2) < 175)          # hard rule 1: nothing at eye height
ma[ndimage.binary_dilation(brow, iterations=2)] = SKIN
inside = ndimage.binary_erosion(ndimage.binary_fill_holes(fig & (yy > 250) & (yy < 566)), iterations=4)
armR = (((xx > 556) & (yy > 284)) | ((xx > 546) & (yy > 500))) & (xx < 640) & (yy < 560)
ma[armR & inside] = SHIRT                                                                  # the hanging arm goes
leg = biggest(ndimage.binary_fill_holes(ndimage.binary_closing((fig | navy_of(ma)) & (yy >= 556) & (xx > 470) & (xx < 645), iterations=2))) & notsh(ma)
ma[leg & (yy < 640) & ~navy_of(ma)] = NAVY                                                 # and its hand over the thigh
leg = np.where(yy < 905, ndimage.binary_erosion(leg, iterations=1), leg)
upm = ndimage.binary_fill_holes(biggest(fig & (yy < 552)))
masF = Image.fromarray(ma.astype('uint8')).transpose(Image.FLIP_LEFT_RIGHT)
F = lambda m: L(m).transpose(Image.FLIP_LEFT_RIGHT)
PIV = (450, 575); KNEE = (446, 745); ANK = (433, 915); SH = (428, 318)                     # joints in the mirrored master

# ---------------------------------------------------------------- arm of the mountain pose and the gripping hand of the cross-body stretch
mt = np.asarray(Image.open('mountain.png').convert('RGB')).astype(int)
mfig = nonbg(mt) & notsh(mt)
armL = ndimage.binary_fill_holes(biggest(mfig & ~teal_of(mt) & ~navy_of(mt) & (xx > 350) & (xx < 414) & (yy > 386) & (yy < 620)))
mtI = Image.open('mountain.png').convert('RGB'); ATOP = (385, 388)
cr = Image.open('front_ref.png').convert('RGB'); cra = np.asarray(cr).astype(int)
gp = [(586, 360), (581, 331), (570, 320), (562, 311), (564, 303), (578, 299), (593, 296), (610, 296), (622, 303), (627, 318), (628, 340), (627, 360)]
grip = shape(lambda d: d.polygon([(x * S, y * S) for x, y in gp], fill=255))
grip = L((np.asarray(grip) > 127) & ~ndimage.binary_dilation(teal_of(cra), iterations=1))
GW = (606, 357); GDIR = -128.5                                                              # its wrist, and where its forearm points (degrees)

out = masF.copy()                                                                           # head, torso, standing leg, floor shadow
knee = rot(KNEE, PIV, THIGH, PIV); ank = rot(ANK, KNEE, SHIN, knee)
# folded lower leg and its shoe, behind the thigh
sI, sM = place(masF, F(leg & (yy >= 905)), ANK, FOOT, ank); out.paste(sI, (0, 0), sM)
lI, lM = place(masF, F(leg & (yy >= 738) & (yy < 912)), KNEE, SHIN, knee); out.paste(lI, (0, 0), lM)
# thigh and knee
outlined(out, capsule((knee[0] + 2, knee[1] - 8), 38, (knee[0] + 1, knee[1] + 2), 37), NAVY, line=NAVY_LINE)
tI, tM = place(masF, F(leg & (yy >= 590) & (yy < 760)), PIV, THIGH, PIV); out.paste(tI, (0, 0), tM)
paint(out, capsule((PIV[0] - 6, PIV[1] + 30), 40, (knee[0] + 4, knee[1] - 40), 32), NAVY)   # no line between hips and thigh
# the shirt back over the top of the thigh
out.paste(masF, (0, 0), F(upm))
# holding arm: sleeve, arm, gripping hand
d = (-math.sin(math.radians(ARM)), math.cos(math.radians(ARM)))
al = lambda t: (SH[0] + t * d[0], SH[1] + t * d[1])
atop = al(100)
paint(out, capsule(al(60), 19, al(120), 19), SKIN)
aI, aM = place(mtI, L(armL & (yy < 556)), ATOP, ARM, atop); out.paste(aI, (0, 0), aM)
wr = rot((386, 548), ATOP, ARM, atop)
hI, hM = place(cr, grip, GW, (90 + ARM) - GDIR, wr); out.paste(hI, (0, 0), hM)
outlined(out, capsule(al(8), 33, al(88), 27), SHIRT, line=SHIRT_LINE)
paint(out, capsule(al(-6), 29, al(30), 27), SHIRT)                                          # sleeve joins the shoulder, no inner line
# shift the whole picture
out = out.transform((W, H), Image.AFFINE, (1, 0, -DX, 0, 1, 0), fillcolor=tuple(int(v) for v in BG))
out.save('guide.png')
L(np.asarray(F(upm & (yy < 250)).transform((W, H), Image.AFFINE, (1, 0, -DX, 0, 1, 0))) > 127).save('head_zone.png')
a = np.asarray(out).astype(int); f = nonbg(a) & notsh(a); xs = np.where(f.any(0))[0]; ys = np.where(f.any(1))[0]
print('knee', knee, 'ankle', ank, 'wrist', wr, 'bbox', xs.min(), xs.max(), ys.min(), ys.max(), 'center', (xs.min() + xs.max()) / 2)
out.crop((200, 0, 824, 1024)).save('guide_view.png')
