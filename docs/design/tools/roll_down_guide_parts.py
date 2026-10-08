"""Pilates roll down (peak): the figure rebuilt from the character's own approved parts.

Legs and shoes = the leg of the profile master (chin-tuck-hold), mirrored to face right and sheared
(near leg upright, far leg slanting so the feet end up apart). Arms and hands = the hanging arm of the
mountain pose. Head = the master's head (already in pre_zoom4.png). Shirt and sleeve = the guided pass.
Only the hips are drawn: a round shape behind the thighs.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

S = 4
BG = np.array([240, 254, 249.]); SHADOW = np.array([165, 225, 208.]); SHIRT_LINE = (9, 62, 68); NAVY_LINE = (22, 24, 40)
p4 = Image.open('pre_zoom4.png').convert('RGB'); a = np.asarray(p4).astype(int)
mas = Image.open('master.png').convert('RGB'); ma = np.asarray(mas).astype(int)
mtn = Image.open('mountain.png').convert('RGB'); mt = np.asarray(mtn).astype(int)
H, W = a.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def nonbg(x): return (np.abs(x - BG).sum(2) > 30)
def notsh(x): return (np.abs(x - SHADOW).sum(2) > 45)
def skin_of(x): return (x[..., 0] > 200) & (x[..., 0] - x[..., 2] > 40)
def navy_of(x): return (x[..., 2] > x[..., 0] + 8) & (x[..., 2] > x[..., 1] + 8) & (x[..., 0] < 110)
def teal_of(x): return (x[..., 1] > x[..., 0] + 30) & (np.abs(x[..., 1] - x[..., 2]) < 45) & (x[..., 1] > 40)
def biggest(m):
    lab, n = ndimage.label(m); return lab == np.bincount(lab[lab > 0]).argmax()
def spline(p, n=12):
    p = np.array([p[0]] + list(p) + [p[-1]], float); out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(tuple(0.5 * ((2 * p[i]) + (-p[i-1] + p[i+1]) * t + (2*p[i-1] - 5*p[i] + 4*p[i+1] - p[i+2]) * t*t + (-p[i-1] + 3*p[i] - 3*p[i+1] + p[i+2]) * t**3)))
    out.append(tuple(p[-2])); return out
def P(pts): return [(x * S, y * S) for x, y in pts]
def edges(m, y):
    xs = np.where(m[y])[0]; return int(xs.min()), int(xs.max())

# ---------------------------------------------------------------- parts
SX = 1.14
# leg + shoe of the profile master (below its hanging hand), mirrored to face right
fig = (nonbg(ma) & notsh(ma)) | navy_of(ma)
lm = ndimage.binary_fill_holes(ndimage.binary_closing(fig & (yy >= 640) & (xx > 470) & (xx < 645), iterations=2))
lm = biggest(lm) & notsh(ma)
lm &= ~((np.abs(ma - BG).sum(2) < 12) & ~ndimage.binary_erosion(lm, iterations=3))     # no light rim
NAVY = tuple(int(v) for v in np.median(ma[navy_of(ma) & lm & (ma.max(2) > 60)], axis=0))
lm = np.where(yy < 905, ndimage.binary_erosion(lm, iterations=1), lm)   # trims the light anti-aliased rim of the trousers
legI = mas.transpose(Image.FLIP_LEFT_RIGHT); legM = L(lm).filter(ImageFilter.GaussianBlur(0.5)).transpose(Image.FLIP_LEFT_RIGHT)
lmf = np.asarray(legM) > 127
c = lambda y: np.mean(edges(lmf & navy_of(np.asarray(legI).astype(int)), y))
slope = (c(660) - c(900)) / 240.0
heel = int(np.where(lmf[940:975].any(0))[0].min())
print('navy', NAVY, 'leg slope', round(slope, 3), 'heel', heel, 'hem', edges(lmf, 915))
def leg(x_heel, lean):
    """lean: how far the top of the leg (y=690) ends up left of the ankle, in px."""
    dx = x_heel - heel; K = slope + lean / 230.0; xc = heel + 38
    T = (1 / SX, -K, xc - (dx + xc) / SX + 920 * K, 0, 1, 0)       # SX: legs as thick as the character's after the model slims them
    img = legI.transform((W, H), Image.AFFINE, T, resample=Image.BICUBIC); m = legM.transform((W, H), Image.AFFINE, T, resample=Image.BICUBIC)
    T0 = (1, 0, -dx, 0, 1, 0)
    img0 = legI.transform((W, H), Image.AFFINE, T0); m0 = legM.transform((W, H), Image.AFFINE, T0)
    low = L((yy >= 920).astype(float))
    img.paste(img0, (0, 0), low); m.paste(m0, (0, 0), low)
    return img, np.asarray(m).astype(float) / 255
# hanging arm with open hand of the mountain pose
am = nonbg(mt) & ~teal_of(mt) & ~navy_of(mt) & (xx > 596) & (xx < 674) & (yy > 388) & (yy < 618)
am = ndimage.binary_fill_holes(biggest(am))
def arm(cx, tip_y, top_y):
    wr = edges(skin_of(mt) & am, 540); dx = int(round(cx - np.mean(wr))); dy = tip_y - int(np.where(am.any(1))[0].max())
    rgb = mt.copy().astype('uint8'); m = am.copy()
    for y in range(392 - max(0, (392 + dy) - top_y), 392): rgb[y] = rgb[392]; m[y] = m[392]      # longer upper arm, under the sleeve
    T = (1, 0, -dx, 0, 1, -dy)
    return Image.fromarray(rgb).transform((W, H), Image.AFFINE, T), L(m).transform((W, H), Image.AFFINE, T)

# ---------------------------------------------------------------- what stays from the current image: shirt, sleeve, head
teal = teal_of(a) & (yy < 712)
shirt = ndimage.binary_closing(teal, iterations=2) & nonbg(a) & (yy < 712)
sk = skin_of(a); lab, n = ndimage.label(sk)
armskin = np.isin(lab, [lab[800, 548], lab[860, 672]]) & (lab > 0)
head = nonbg(a) & notsh(a) & (xx > 578) & (yy > 600) & (yy < 800) & ~shirt & ~ndimage.binary_dilation(armskin, iterations=4)
keep = shirt | head

# ---------------------------------------------------------------- layers, back to front
ys, xs = np.where((np.abs(a - SHADOW).sum(2) < 45) & (yy > 880))
low = Image.new('RGB', (W * S, H * S), tuple(int(v) for v in BG))
ImageDraw.Draw(low).ellipse([(xs.min() - 6) * S, ys.min() * S, (xs.max() + 6) * S, ys.max() * S], fill=tuple(int(v) for v in SHADOW))
out = low.resize((W, H), Image.LANCZOS)

NEAR_HEEL, FAR_HEEL = 372, 476
nI, nM = leg(NEAR_HEEL, 6); fI, fM = leg(FAR_HEEL, 72)
TOP = 694
nl, nr = edges(nM > 0.5, TOP); fl, fr = edges(fM > 0.5, 650)
print('near leg at top', nl, nr, 'far leg at 650', fl, fr)
# hips: round buttocks behind the thighs, up under the shirt
back = spline([(452, 542), (438, 531), (416, 526), (393, 531), (375, 547), (364, 572), (359, 604), (358, 636), (358, 668), (nl + 1, TOP + 4)])
front = [(fr - 1, 652), (fr - 3, 638)]
big = out.resize((W * S, H * S), Image.LANCZOS); d = ImageDraw.Draw(big)
d.polygon(P(back + [(nr, TOP + 4), (fr - 1, TOP + 4)] + front + [(470, 620), (452, 560)]), fill=NAVY)
w = int(3 * S)
d.line(P(back), fill=NAVY_LINE, width=w, joint='curve')
d.line(P(front), fill=NAVY_LINE, width=w)
out = big.resize((W, H), Image.LANCZOS)
out.paste(fI, (0, 0), L(fM * ((yy >= 648) & ((xx > nr - 2) | (yy >= TOP)))))          # far leg, behind
big = out.resize((W * S, H * S), Image.LANCZOS); d = ImageDraw.Draw(big)
d.line(P(spline([(nr, TOP + 2), (nr + 4, 660), (nr + 12, 612)])), fill=NAVY_LINE, width=int(2.6 * S), joint='curve')   # near thigh in front of the far one
out = big.resize((W, H), Image.LANCZOS)
out.paste(nI, (0, 0), L(nM * (yy >= TOP)))                                              # near leg, in front
for cx in (674, 557):                                                                   # far arm, then near arm
    aI, aM = arm(cx, 952, 694); out.paste(aI, (0, 0), aM)
out.paste(p4, (0, 0), L(keep).filter(ImageFilter.GaussianBlur(0.5)))                    # shirt, sleeve and head on top
# ---------------------------------------------------------------- clean-up of the drawn joins
big = out.resize((W * S, H * S), Image.LANCZOS); d = ImageDraw.Draw(big)
hem = spline([(526, 693), (546, 700), (568, 703), (590, 701)])
d.polygon(P(hem + [(590, 686), (526, 682)]), fill=(10, 123, 127))                        # sleeve hem: no saw teeth
out = big.resize((W, H), Image.LANCZOS)
below = Image.new('L', (W, H), 0); ImageDraw.Draw(below).polygon(hem + [(590, 735), (526, 735)], fill=255)
aI, aM = arm(557, 952, 694)
out.paste(aI, (0, 0), Image.fromarray(np.minimum(np.asarray(aM), np.asarray(below))))     # the arm again, below the hem
fa = np.asarray(out).astype(int)
patch = (xx > 590) & (xx < 624) & (yy > 614) & (yy < 650) & (fa[..., 2] > 200)             # light scraps between collar and neck
fa[patch] = (10, 123, 127)
for x0, y0, x1, y1 in ((585, 672, 594, 695), (438, 515, 453, 529)):                       # slits of background at the sleeve and at the waist
    slit = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1) & (fa[..., 2] > 200)
    fa[slit] = (10, 123, 127)
# shirt outline against the background: one even line on a smoothed edge
tl = teal_of(fa) & (yy < 712)
smo = np.asarray(L(ndimage.binary_closing(tl, iterations=3)).filter(ImageFilter.GaussianBlur(2.0))) > 127
bgn = ndimage.binary_dilation((np.abs(fa - BG).sum(2) < 40) & ~smo, iterations=4)
fuzz = smo & bgn & ~tl & (np.abs(fa - BG).sum(2) < 120)
fa[fuzz] = (10, 123, 127)                                                                 # fuzzy edge pixels inside the smooth edge
ring = ndimage.binary_dilation(smo, iterations=1) & ~ndimage.binary_erosion(smo, iterations=2) & bgn
out = Image.fromarray(fa.astype('uint8'))
big = out.resize((W * S, H * S), Image.LANCZOS)
rb = L(ring).resize((W * S, H * S), Image.BICUBIC).filter(ImageFilter.GaussianBlur(S * 0.8)).point(lambda v: 255 if v > 110 else 0)
big.paste(Image.new('RGB', big.size, SHIRT_LINE), (0, 0), rb)
d = ImageDraw.Draw(big); d.line(P(hem), fill=SHIRT_LINE, width=int(3 * S), joint='curve')
out = big.resize((W, H), Image.LANCZOS)
fa = np.asarray(out).copy()
brow = (xx >= 612) & (xx <= 638) & (yy >= 714) & (yy <= 738) & (fa.max(2) < 170)       # the guide gives the model no stroke at eye height
fa[ndimage.binary_dilation(brow, iterations=2)] = (255, 209, 170)
out = Image.fromarray(fa)
out.save('pre_zoom5.png'); out.save('guide6.png')
sh = Image.new('RGB', (888 + 20 + 512, 1100), 'white')
sh.paste(out.crop((320, 480, 740, 1000)).resize((888, 1100), Image.LANCZOS), (0, 0)); sh.paste(out.resize((512, 512), Image.LANCZOS), (908, 0)); sh.save('final5_check.png')

ZOOM = 1.2; FLOOR = 985
fx = np.where((np.abs(np.asarray(out).astype(float) - BG).sum(2) > 40).any(0))[0]; cx = (fx.min() + fx.max()) / 2
fin = out.transform((W, H), Image.AFFINE, (1 / ZOOM, 0, cx - 512 / ZOOM, 0, 1 / ZOOM, FLOOR - (FLOOR - 15) / ZOOM), resample=Image.BICUBIC, fillcolor=tuple(int(v) for v in BG))
fin.save('final5.png')
out.crop((500, 560, 740, 820)).resize((960, 1040), Image.LANCZOS).save('review_head.png')
