"""Standing calf stretch guide: lunge in profile facing right, arms straight forward.

Built from the character's own parts: head and torso of the profile master (mirrored, leaning 8 degrees),
its leg and shoe (back leg rotated, front shin upright), the hanging arm of the mountain pose turned forward.
Only the front thigh, the hips and the sleeve are drawn. This is a guide for the harmonizing pass, never the final image.
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

S = 4; W = H = 1024
BG = np.array([240, 254, 249.]); SHADOW = (165, 225, 208); SHIRT = (10, 123, 127); SHIRT_LINE = (9, 62, 68)
SKIN = (255, 209, 170); LINE = (52, 34, 26); NAVY = (35, 47, 78); NAVY_LINE = (22, 24, 40)
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

# ---------------------------------------------------------------- parts from the profile master (mirrored: faces right)
ma = np.asarray(Image.open('master.png').convert('RGB')).astype(int).copy()
fig = nonbg(ma) & notsh(ma)
brow = (xx >= 484) & (xx <= 518) & (yy >= 124) & (yy <= 148) & (ma.max(2) < 175)          # hard rule 1: nothing at eye height
ma[ndimage.binary_dilation(brow, iterations=2)] = SKIN
inside = ndimage.binary_erosion(ndimage.binary_fill_holes(fig & (yy > 250) & (yy < 566)), iterations=4)
armR = (((xx > 556) & (yy > 284)) | ((xx > 546) & (yy > 500))) & (xx < 640) & (yy < 560)
ma[armR & inside] = SHIRT                                                                  # the hanging arm goes
upm = ndimage.binary_fill_holes(biggest(fig & (yy < 552)))
legall = (fig | navy_of(ma)) & (yy >= 640) & (xx > 470) & (xx < 645)
legall = biggest(ndimage.binary_fill_holes(ndimage.binary_closing(legall, iterations=2))) & notsh(ma)
legall = np.where(yy < 905, ndimage.binary_erosion(legall, iterations=1), legall)
masF = Image.fromarray(ma.astype('uint8')).transpose(Image.FLIP_LEFT_RIGHT)
F = lambda m: L(m).transpose(Image.FLIP_LEFT_RIGHT)
PIV = (450, 575); ANK = (433, 915)                       # hip joint and ankle in the mirrored master
HIP = (478, 716)

# ---------------------------------------------------------------- arm of the mountain pose (open hand)
mt = np.asarray(Image.open('mountain.png').convert('RGB')).astype(int)
am = nonbg(mt) & ~teal_of(mt) & ~navy_of(mt) & (xx > 596) & (xx < 674) & (yy > 388) & (yy < 618)
am = ndimage.binary_fill_holes(biggest(am)); mtI = Image.open('mountain.png').convert('RGB'); ATOP = (637, 392)

out = Image.new('RGB', (W * S, H * S), tuple(int(v) for v in BG)); ImageDraw.Draw(out).ellipse([120 * S, 938 * S, 880 * S, 990 * S], fill=SHADOW)
out = out.resize((W, H), Image.LANCZOS)

# shoulder after the lean
LEAN = 8
SH = rot((428, 318), PIV, LEAN, HIP)
# far arm (a little above the near one)
aI, aM = place(mtI, L(am), ATOP, -95, (SH[0] + 84, SH[1] - 22)); out.paste(aI, (0, 0), aM)      # far arm: clearly above the near one, both hands visible

# back leg: straight, far behind; heel raised
def back(theta, draw=False):
    ank = rot(ANK, PIV, theta, HIP)
    sI, sM = place(masF, F(legall & (yy >= 905)), ANK, 30, ank)
    if draw:
        knee = rot((450, 668), PIV, theta, HIP)
        outlined(out, [(capsule(HIP, 42, knee, 39), NAVY)], line=NAVY_LINE)
        lI, lM = place(masF, F(legall & (yy < 912)), PIV, theta, HIP)
        out.paste(lI, (0, 0), lM); out.paste(sI, (0, 0), sM)
    return int(np.where(np.asarray(sM) > 127)[0].max())
theta = min(range(40, 66), key=lambda t: abs(back(t) - 973)); print('back leg angle', theta); back(theta, True)

# front leg: thigh forward, shin upright on the master's own lower leg and shoe
KNEE = (662, 752)
shI = masF.transform((W, H), Image.AFFINE, (1, 0, -(KNEE[0] - 428), 0, 1, 0)); shM = F(legall & (yy >= 776)).transform((W, H), Image.AFFINE, (1, 0, -(KNEE[0] - 428), 0, 1, 0))
outlined(out, [(capsule(HIP, 44, KNEE, 37), NAVY), (capsule(KNEE, 37, (KNEE[0] + 2, 790), 35), NAVY)], line=NAVY_LINE)
out.paste(shI, (0, 0), shM)
outlined(out, [(capsule((HIP[0] - 8, HIP[1] - 6), 46, (HIP[0] + 18, HIP[1] - 2), 44), NAVY)], line=NAVY_LINE)
paint(out, capsule(HIP, 40, (KNEE[0] - 40, KNEE[1] - 6), 34), NAVY)                              # no line between hips and thigh

# upper body
uI, uM = place(masF, F(upm), PIV, LEAN, HIP); out.paste(uI, (0, 0), uM)
# near arm and its sleeve
aI, aM = place(mtI, L(am), ATOP, -87, (SH[0] + 108, SH[1] + 6)); out.paste(aI, (0, 0), aM)   # arm top at the sleeve hem: 226px of skin stay visible
outlined(out, [(capsule((SH[0] + 6, SH[1] + 2), 33, (SH[0] + 88, SH[1] + 6), 27), SHIRT)], line=SHIRT_LINE)
paint(out, capsule((SH[0] - 6, SH[1] + 2), 29, (SH[0] + 30, SH[1] + 4), 27), SHIRT)                # sleeve joins the shoulder, no inner line
out.save('guide.png'); L(np.asarray(place(masF, F(upm & (yy < 250)), PIV, LEAN, HIP)[1]) > 127).save('head_zone.png')
print('shoulder', SH)
