"""Standing forward fold: final assembly on the harmonizing pass (seed 11, 12 steps, strength 0.25).

Body = the model's redraw of guide.png. Head = the character's own head from the guide (no eyes, no brow).
Then: palette of the master, teal laces, white sock, build check, and the 1.2x zoom about the floor for folded poses.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
from scipy.ndimage import uniform_filter

src = sys.argv[1]; ZOOM = 1.2; FLOOR = 985
BG = np.array([240, 254, 249.]); SHADOW = np.array([165, 225, 208.])
gd = Image.open('guide.png').convert('RGB'); ga = np.asarray(gd).astype(float)
c = np.asarray(Image.open('front_ref.png').convert('RGB')).astype(float)
H, W = ga.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
def med(a, m): return np.median(a[m], axis=0)
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def soft(m, r): return np.asarray(L(m).filter(ImageFilter.GaussianBlur(r))).astype(float)[..., None] / 255
cs = (c[..., 0] > 200) & (c[..., 0] - c[..., 2] > 60) & (c[..., 1] > 180) & (yy > 300) & (yy < 345)
SKIN = med(c, cs)

g = np.asarray(Image.open(src).convert('RGB')).astype(float)
R, G, B = g[..., 0], g[..., 1], g[..., 2]
bgc = med(g, yy < 40)
mint = (G > R + 30) & (G > 200) & (B > R + 15) & (yy > 930)                                # the floor shadow, found by its color
shadow = (np.abs(g - med(g, mint)).sum(2) < 34) & (yy > 900)
teal = (G > 60) & (R < G - 50) & (np.abs(G - B) < 40) & ~shadow & (yy < 800)
navy = (B > R + 15) & (B > G + 8) & (R < 110) & (G < 110) & (B < 150)
skin = (R > 200) & (R - B > 60)
flat = skin & (G > 180) & (yy > 760)
o = g.copy()
o[teal] = (np.array([10, 123, 127]) * np.clip(G / med(g, teal)[1], 0, 1.1)[..., None])[teal]
# flat shirt: the model's shadow blotches and speckles go, only the real fold lines (thin, dark) stay
ratio = G / med(g, teal)[1]
lab, n = ndimage.label(navy); trousers = lab == np.bincount(lab[lab > 0]).argmax()
shirt = ndimage.binary_fill_holes(ndimage.binary_closing(teal, iterations=3)) & ~skin & ~ndimage.binary_dilation(trousers, iterations=1)
dark = shirt & (ratio < 0.85)
broad = ndimage.binary_dilation(ndimage.binary_opening(dark, iterations=2), iterations=3)
cand = dark & ~broad
lab, n = ndimage.label(cand, structure=np.ones((3, 3))); size = np.bincount(lab.ravel())
lines = cand & (size[lab] >= 45)
lz = ndimage.binary_dilation(lines, iterations=1) & ~broad
tt = np.clip((ratio - 0.55) / 0.4, 0, 1)[..., None]
flatc = np.array([10, 123, 127.]); linec = np.array([9, 62, 68.])
o = np.where(shirt[..., None], flatc, o)
o = np.where(lz[..., None], flatc * tt + linec * (1 - tt), o)
nvy = navy & ~shirt
o[nvy] = (np.array([39, 49, 78]) * np.clip(B / med(g, navy)[2], 0, 1.15)[..., None])[nvy]
w = np.clip((G - 157) / 30, 0, 1)[..., None]
o[skin] = (g + w * (SKIN - med(g, flat)))[skin]
o[np.abs(g - bgc).sum(2) < 28] = BG
o[shadow] = SHADOW
brown = (R > B + 20) & (R >= G) & ~skin
k = (np.clip((165 - R) / 55, 0, 1) * brown)[..., None]
o = o * (1 - 0.55 * k)

# --- socks: the model's purple sock -> white (reads as the shoe opening, no colored sock in the design)
purple = (B > G + 25) & (R > 90) & (B > 150) & (yy > 820) & ~shirt
o[ndimage.binary_dilation(purple, iterations=1) & (g.min(2) > 90)] = (247, 245, 248)
# --- the shoe: the model keeps the teal laces of the guide, so they are not recolored here (its grey seams stay grey)
white = (g.min(2) > 195) & (g.max(2) - g.min(2) < 28) & (G - R < 7) & (yy > 880)          # the shoe, not the mint background
lab, n = ndimage.label(white); size = np.bincount(lab.ravel()); size[0] = 0
shoe_g = (g.min(2) > 180) & (g.max(2) - g.min(2) < 22) & (G - R < 7) & (yy > 880)           # the model greys the shoe: back to white
gain = np.clip(241 / max(float(np.median(g[shoe_g].mean(1))), 1), 1, 1.2)
o[shoe_g] = (247, 245, 248)                                                              # one flat white, no speckles
white = white | shoe_g
lab, n = ndimage.label(white); size = np.bincount(lab.ravel()); size[0] = 0
sx0 = int(np.where((white & (size[lab] > 200)).any(0))[0].min()); print('shoe toe at x =', sx0)

# --- the character's own head from the guide (hard rule 1: no eyes, nothing at eye height)
sil = np.asarray(Image.open('head_zone.png').convert('L')) > 127
gt = (ga[..., 1] > ga[..., 0] + 30) & (np.abs(ga[..., 1] - ga[..., 2]) < 45) & (ga[..., 1] > 40)
sil &= ~ndimage.binary_dilation(teal, iterations=1)                                       # the neck goes under the model's collar
lab, n = ndimage.label(sil); sil = ndimage.binary_fill_holes(lab == np.bincount(lab[lab > 0]).argmax())
# first take the model's own head out completely (its face and hair never line up exactly with ours), without touching the arms next to it
gsk = (ga[..., 0] > 200) & (ga[..., 0] - ga[..., 2] > 40)
garm = ndimage.binary_dilation(gsk & ~ndimage.binary_dilation(sil, iterations=2), iterations=5)       # where the guide has the arms
near = ndimage.binary_dilation(sil, iterations=16)
hairm = (g.max(2) < 100) & (B >= R - 5) & ndimage.binary_dilation(sil, iterations=45) & ~ndimage.binary_dilation(shirt | trousers, iterations=3)
mhead = (near & ~sil & ~garm) | ndimage.binary_dilation(hairm, iterations=3)
mhead |= (g.min(2) > 150) & (g.max(2) - g.min(2) < 30) & ndimage.binary_dilation(sil, iterations=30) & (yy < 860) & (np.abs(g - bgc).sum(2) > 28)   # white collar patch at the neck
mhead = ndimage.binary_dilation(mhead, iterations=1) & ~ndimage.binary_dilation(teal, iterations=3)
import os
if os.path.exists('head_zone_old.png'):                                                       # the head was raised after the pass: the model's head sits where the old one was
    oldz = ndimage.binary_dilation(np.asarray(Image.open('head_zone_old.png').convert('L')) > 127, iterations=18)
    hairo = ndimage.binary_dilation((g.max(2) < 100) & (B >= R - 5) & ndimage.binary_dilation(oldz, iterations=30) & ~ndimage.binary_dilation(shirt | trousers, iterations=3), iterations=3)
    mhead |= (oldz | hairo) & ~garm & ~ndimage.binary_dilation(teal | gt, iterations=3)
o = np.where(mhead[..., None], BG, o)
headall = ndimage.binary_dilation(sil | mhead, iterations=3)
al = soft(ndimage.binary_erosion(sil, iterations=1), 0.8) * (~ndimage.binary_dilation(teal, iterations=1))[..., None]
o = o * (1 - al) + ga * al
fsk = sil & (o[..., 0] > 215) & (o[..., 1] > 180) & (o[..., 2] > 140) & ~ndimage.binary_dilation(teal, iterations=1)   # face and neck: one flat skin tone, no seam
o[fsk & ndimage.binary_erosion(sil, iterations=3)] = SKIN
tealall = shirt | teal
seam = ndimage.binary_dilation(sil, iterations=5) & ndimage.binary_dilation(tealall, iterations=5) & ~sil & ~tealall     # where our head meets the collar: the shirt's outline, no ragged gap
o[seam] = linec
# arms and hands: the model's drawing is kept as it is (crisp lines); only its skin tone and its line color move to the palette
armz = ndimage.binary_fill_holes(ndimage.binary_closing(skin & (yy > 700) & (xx < sx0 + 10) & ~headall, iterations=2))
lab, n = ndimage.label(armz); size = np.bincount(lab.ravel()); size[0] = 0
armz = size[lab] > 3000
gapm = armz & (G > R + 3) & (g.min(2) > 150)                                                 # background seen between the two arms
o[ndimage.binary_dilation(gapm, iterations=1) & (G > R - 12) & (g.min(2) > 150)] = BG
armz = ndimage.binary_dilation(armz, iterations=2) & ~headall & ~shirt & ~shadow
warm = armz & (R > 110) & (R - G > 12) & (G < 189)
tl_ = np.clip((189 - G) / 62, 0, 1)[..., None]
o = np.where(warm[..., None], SKIN * (1 - tl_) + np.array([84, 50, 36.]) * tl_, o)
trz = ndimage.binary_fill_holes(ndimage.binary_closing(trousers, iterations=2)) & ~shirt
thick = ndimage.binary_opening(trz & (g.max(2) < 60), iterations=2)                       # thick black bars the model puts on the trousers
o[ndimage.binary_dilation(thick, iterations=3) & trz & (B < 95)] = (39, 49, 78)
mark = (G > R + 25) & (B > R + 25) & (g.max(2) < 150) & (yy > 800) & (xx < sx0 - 10)      # dark teal mark the model leaves beside the wrist
o[ndimage.binary_dilation(mark, iterations=2) & ~skin & ~brown & ~shadow & ~headall] = BG
isbg = np.abs(o - BG).sum(2) < 4
ring = ndimage.binary_dilation(teal, iterations=2) & ndimage.binary_dilation(isbg, iterations=2)
sm = np.asarray(Image.fromarray(np.clip(o, 0, 255).astype('uint8')).filter(ImageFilter.GaussianBlur(0.9))).astype(float)
o = np.where(ring[..., None], sm, o)                                                    # no stair steps on the shirt edge
fg = (np.abs(o - BG).sum(2) > 24) & (np.abs(o - SHADOW).sum(2) > 40)                     # stray marks the model leaves next to the figure
lab, n = ndimage.label(fg, structure=np.ones((3, 3))); size = np.bincount(lab.ravel()); size[0] = 0
stray = fg & (size[lab] < 400)
under = ndimage.binary_dilation(stray, iterations=2)
o = np.where(under[..., None], np.where((shadow & ~stray)[..., None] | (ndimage.uniform_filter(shadow.astype(float), 9) > 0.5)[..., None], SHADOW, BG), o)
print('stray marks erased:', int(stray.sum()), 'px')
rr = 14; dy_, dx_ = np.mgrid[-rr:rr + 1, -rr:rr + 1]                                         # the hem corner over the hips: rounded, no stiff point
opened = ndimage.binary_opening(shirt, structure=dx_ * dx_ + dy_ * dy_ <= rr * rr)
cut = ndimage.binary_dilation(shirt & ~opened & (xx > sx0 + 40), iterations=2) & ~opened
_, (iy, ix) = ndimage.distance_transform_edt(shirt | cut, return_indices=True)
tz = ndimage.binary_dilation(trousers, iterations=4)
o = np.where(cut[..., None], np.where(tz[iy, ix][..., None], np.array([39, 49, 78.]), BG), o)
shirt = np.where(xx > sx0 + 40, opened, shirt)
edge = L(shirt & ~ndimage.binary_erosion(shirt, iterations=2)).filter(ImageFilter.GaussianBlur(0.8))
ea = (np.asarray(edge).astype(float) / 255 * 1.25).clip(0, 1)[..., None] * (~ndimage.binary_dilation(sil, iterations=2))[..., None]
o = o * (1 - ea) + linec * ea                                                           # thin dark teal outline around the shirt, as in the master
import os
NECKFIX = os.environ.get('NONECK') is None
# --- neck and collar: a short neck going into the collar of the shirt, the chest of the shirt hanging below it.
#     (Before: a long slab of skin from the jaw into the sleeve, with a stump under the chin. Rejected.)
from PIL import ImageDraw
def bez(p0, p1, p2, n=24): return [((1 - t) ** 2 * p0[0] + 2 * t * (1 - t) * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * t * (1 - t) * p1[1] + t * t * p2[1]) for t in np.linspace(0, 1, n)]
K = 4
collar = bez((378, 699), (392, 735), (414, 757))                                           # collar line, from the nape to the throat
chest = bez((414, 757), (438, 767), (463, 750))                                            # the chest of the shirt, hanging, into the sleeve
poly = collar + chest + [(463, 716), (400, 706)]
pm = Image.new('L', (W * K, H * K), 0); ImageDraw.Draw(pm).polygon([(x * K, y * K) for x, y in poly], fill=255)
pm = np.asarray(pm.resize((W, H), Image.LANCZOS)).astype(float) / 255
oi = np.clip(o, 0, 255)
tealish = (oi[..., 1] > oi[..., 0] + 20) & (np.abs(oi[..., 1] - oi[..., 2]) < 45)
pa = pm[..., None]
o = o * (1 - pa) + flatc * pa
lm = Image.new('L', (W * K, H * K), 0); ld = ImageDraw.Draw(lm)
ld.line([(x * K, y * K) for x, y in collar + chest[1:-3]], fill=255, width=3 * K, joint='curve')
ld.line([(x * K, y * K) for x, y in bez((439, 706), (444, 738), (465, 754))], fill=255, width=int(2.4 * K), joint='curve')   # the sleeve edge over the chest, one smooth line
la = (np.asarray(lm.resize((W, H), Image.LANCZOS)).astype(float) / 255)[..., None]
o = o * (1 - la) + linec * la
# throat: one clean line from the jaw to the collar, skin above it, background below
# throat (head raised: the neck leaves the head level with the back and goes straight into the collar): clean skin, one line under it
oi = np.clip(o, 0, 255)
tl2 = (oi[..., 1] > oi[..., 0] + 20) & (np.abs(oi[..., 1] - oi[..., 2]) < 45)
nbx = (xx >= 352) & (xx <= 392) & ~tl2 & ~ndimage.binary_dilation(tl2, iterations=1)
o[nbx & (yy >= 676) & (yy <= 718) & (oi.max(2) > 120)] = SKIN
o[nbx & (yy >= 727) & (yy <= 740)] = BG
tm = Image.new('L', (W * K, H * K), 0); ImageDraw.Draw(tm).line([(340 * K, 721.5 * K), (392 * K, 724.5 * K)], fill=255, width=int(2.6 * K))
ta = (np.asarray(tm.resize((W, H), Image.LANCZOS)).astype(float) / 255)[..., None] * (~tl2)[..., None]
o = o * (1 - ta) + np.array([84, 50, 36.]) * ta

# knees a little bent: the knee moves forward (thigh and shin stay straight), hip and ankle stay where they are
KNEE_D, Y_HIP, Y_KNEE, Y_ANK = 24, 600, 750, 905
oi = np.clip(o, 0, 255)
tl3 = ndimage.binary_dilation((oi[..., 1] > oi[..., 0] + 20) & (np.abs(oi[..., 1] - oi[..., 2]) < 45) & (yy < 800), iterations=1)   # the shirt stays in front
band = (xx >= 596) & (yy > Y_HIP) & (yy < Y_ANK) & ~tl3                                        # leg and background only: the arms are left of it
dy_ = np.clip((yy - Y_HIP) / (Y_KNEE - Y_HIP), 0, 1) * (yy <= Y_KNEE) + np.clip((Y_ANK - yy) / (Y_ANK - Y_KNEE), 0, 1) * (yy > Y_KNEE)
srcimg = np.where(tl3[..., None], np.array([39, 49, 78.]), oi)                                # under the shirt the leg goes on
lay = np.stack([ndimage.map_coordinates(srcimg[..., c], [yy.astype(float), xx + KNEE_D * dy_], order=1, mode='nearest') for c in range(3)], -1)
o = np.where(band[..., None], lay, oi)
print('knee moved forward', KNEE_D, 'px')

# far leg: in profile the two legs overlap, and one leg alone reads as a missing leg. The far leg is the near one again,
# a step forward and behind everything (a little darker, as the far side), with the toe of its shoe showing in front.
FAR_DX, FAR_DY, FAR_TONE = -30, -5, 0.84
oi = np.clip(o, 0, 255)
isbg_ = (np.abs(oi - BG).sum(2) < 16) | (np.abs(oi - SHADOW).sum(2) < 24)
nav_ = (oi[..., 2] > oi[..., 0] + 8) & (oi[..., 2] > oi[..., 1] + 12) & (oi[..., 0] < 110) & (yy > 560) & (xx > 590)   # trousers only: the shirt's dark teal lines are not navy
lab, n = ndimage.label(nav_); nav_ = lab == np.bincount(lab[lab > 0]).argmax()
skin_ = (oi[..., 0] > 200) & (oi[..., 0] - oi[..., 2] > 40)
shoe_ = ~isbg_ & ~skin_ & (yy > 872) & (xx > 590) & ~ndimage.binary_dilation(skin_, iterations=3)
legshoe = ndimage.binary_fill_holes(ndimage.binary_dilation(nav_, iterations=2) | shoe_) & (yy > 600) & ~isbg_
lab, n = ndimage.label(legshoe); legshoe = lab == np.bincount(lab[lab > 0]).argmax()
src = [np.clip(yy - FAR_DY, 0, H - 1), np.clip(xx - FAR_DX, 0, W - 1)]
farm = legshoe[src[0], src[1]] & isbg_ & (yy > 600)                                            # only where nothing is in front of it
far = oi[src[0], src[1]] * FAR_TONE
o = np.where(farm[..., None], far, oi)
edge_f = ndimage.binary_dilation(legshoe, iterations=1) & farm                                # a thin line where the far leg meets the near one
o[edge_f] = (22, 24, 40)
rim_ = ndimage.binary_dilation(farm, iterations=3) & ndimage.binary_dilation(nav_, iterations=4) & ~farm & (o.min(2) > 110) & (yy < 890)   # light rim of the near leg, now between two legs
o[rim_] = (22, 24, 40)
print('far leg added:', int(farm.sum()), 'px')
out = Image.fromarray(np.clip(o, 0, 255).astype('uint8')); out.save('pre_zoom.png')

# --- build check at the character's own scale, before the zoom (hard rule 2)
fa = np.asarray(out).astype(int)
tl = (fa[..., 1] > fa[..., 0] + 30) & (np.abs(fa[..., 1] - fa[..., 2]) < 45) & (fa[..., 1] > 60) & (yy < 800)
nv = (fa[..., 2] > fa[..., 0] + 8) & (fa[..., 2] > fa[..., 1] + 8) & (fa[..., 0] < 110)
sk = (fa[..., 0] > 200) & (fa[..., 0] - fa[..., 2] > 40)
col = np.where(tl[:, 600])[0]
print('torso depth at x=600:', round((col.max() - col.min()) * np.cos(np.radians(13))), '(target ~150)')
for y in (700, 760, 860):
    r = np.where(nv[y, 600:])[0]; print(f'leg width at y={y}:', r.max() - r.min(), '(thigh 75-78 single leg / calf 56-60; two legs overlap in profile)')
arm = sk & (xx > 430) & (xx < 600) & (yy > 735)
ys = np.where(arm.any(1))[0]; xs_top = np.where(arm[ys.min() + 3])[0]; xs_bot = np.where(arm[ys.max() - 3])[0]
print('arm skin rows', ys.min(), ys.max(), 'vertical', ys.max() - ys.min())
lab, n = ndimage.label(arm)
for i in range(1, n + 1):
    p = np.argwhere(lab == i)
    if len(p) < 800: continue
    top = p[p[:, 0].argmin()]; bot = p[p[:, 0].argmax()]
    print('  arm piece: hem', tuple(top[::-1]), 'fingertip', tuple(bot[::-1]), 'visible length', round(float(np.hypot(*(bot - top)))), '(target 226-246)')

# --- folded pose: enlarge 1.2x about the floor, centered
a = np.asarray(out).astype(float)
figm = (np.abs(a - BG).sum(2) > 30) & (np.abs(a - SHADOW).sum(2) > 45)
xs = np.where(figm.any(0))[0]; cx = (xs.min() + xs.max()) / 2
T = (1 / ZOOM, 0, cx - 512 / ZOOM, 0, 1 / ZOOM, FLOOR - (FLOOR - 15) / ZOOM)
fin = out.transform((W, H), Image.AFFINE, T, resample=Image.BICUBIC, fillcolor=tuple(int(v) for v in BG))
fin.save('final.png')
fb = np.asarray(fin).astype(float); fm = (np.abs(fb - BG).sum(2) > 30) & (np.abs(fb - SHADOW).sum(2) > 45)
xs = np.where(fm.any(0))[0]; ys = np.where(fm.any(1))[0]; print('final figure bbox x', xs.min(), xs.max(), 'y', ys.min(), ys.max())
