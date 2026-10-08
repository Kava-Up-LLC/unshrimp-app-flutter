"""Standing calf stretch: final assembly on the harmonizing pass (seed 11, 12 steps, strength 0.25).

Body = the model's redraw of guide.png. Head = the character's own head from the guide (no eyes, no brow).
Then: palette of the master, teal laces, white sock instead of the model's purple one, build check.
"""
import sys, math
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
from scipy.ndimage import uniform_filter

src = sys.argv[1]
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
shadow = (np.abs(g - med(g, (yy > 950) & (yy < 975) & (xx > 380) & (xx < 480))).sum(2) < 30) & (yy > 900)
teal = (G > 60) & (R < G - 50) & (np.abs(G - B) < 40) & ~shadow & (yy < 760)
navy = (B > R + 15) & (B > G + 8) & (R < 110) & (G < 110) & (B < 150)
skin = (R > 200) & (R - B > 60)
flat = skin & (G > 180) & (yy > 400)
o = g.copy()
o[teal] = (np.array([10, 123, 127]) * np.clip(G / med(g, teal)[1], 0, 1.1)[..., None])[teal]
o[navy] = (np.array([39, 49, 78]) * np.clip(B / med(g, navy)[2], 0, 1.15)[..., None])[navy]
w = np.clip((G - 157) / 30, 0, 1)[..., None]
o[skin] = (g + w * (SKIN - med(g, flat)))[skin]
o[np.abs(g - bgc).sum(2) < 16] = BG
o[shadow] = SHADOW
brown = (R > B + 20) & (R >= G) & ~skin
k = (np.clip((165 - R) / 55, 0, 1) * brown)[..., None]
o = o * (1 - 0.55 * k)

# --- socks: the model's purple sock -> white (reads as the shoe opening, no colored sock in the design)
purple = (B > G + 25) & (R > 90) & (B > 150) & (yy > 820)
o[ndimage.binary_dilation(purple, iterations=1) & (g.min(2) > 90)] = (247, 245, 248)
# --- laces: dark strokes inside the white of the shoes -> teal
white = (g.min(2) > 195) & (g.max(2) - g.min(2) < 28) & (yy > 840)
near_white = uniform_filter(white.astype(float), size=17) > 0.25
boxes = ((178, 872, 236, 944), (664, 896, 734, 950))
inbox = np.zeros((H, W), bool)
for x0, y0, x1, y1 in boxes: inbox |= (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
lace = (g.max(2) < 150) & (g.max(2) - g.min(2) < 50) & near_white & inbox
t = np.clip((235 - g.mean(2)) / 170, 0, 1)[..., None]
o[lace] = (np.array([247, 245, 248.]) * (1 - t) + np.array([13, 100, 100.]) * t)[lace]

# --- the character's own head from the guide (hard rule 1: no eyes, nothing at eye height)
sil = np.asarray(Image.open('head_zone.png').convert('L')) > 127
gt = (ga[..., 1] > ga[..., 0] + 30) & (np.abs(ga[..., 1] - ga[..., 2]) < 45) & (ga[..., 1] > 40)
sil &= ~ndimage.binary_dilation(gt, iterations=2)
lab, n = ndimage.label(sil); sil = ndimage.binary_fill_holes(lab == np.bincount(lab[lab > 0]).argmax())
ymax = int(np.where(sil.any(1))[0].max())
zone = ndimage.binary_dilation(sil, iterations=16) & ~sil & (yy < ymax - 14) & ~ndimage.binary_dilation(teal, iterations=4)
o = np.where(zone[..., None], BG, o)
al = soft(ndimage.binary_erosion(sil, iterations=1), 0.8)
o = o * (1 - al) + ga * al
fs = sil & (o[..., 0] > 235) & (o[..., 1] > 185) & (o[..., 2] > 140) & (xx > 560)      # face: one flat skin tone, no trace where the brow was
o[fs & ndimage.binary_erosion(sil, iterations=4)] = np.median(o[fs], axis=0)
nail = (R > 215) & (G < 150) & (B < 115) & (xx > 640) & (yy > 380) & (yy < 500)          # orange fingertips the model adds
nail = ndimage.binary_dilation(ndimage.binary_opening(nail, iterations=1), iterations=1) & ~(g.max(2) < 170)   # blobs only, the finger lines stay
o[nail] = SKIN
out = Image.fromarray(np.clip(o, 0, 255).astype('uint8')); out.save('final.png')

# --- build check (hard rule 2)
fa = np.asarray(out).astype(int)
tl = (fa[..., 1] > fa[..., 0] + 30) & (np.abs(fa[..., 1] - fa[..., 2]) < 45) & (fa[..., 1] > 60) & (yy < 760)
nv = (fa[..., 2] > fa[..., 0] + 8) & (fa[..., 2] > fa[..., 1] + 8) & (fa[..., 0] < 110)
sk = (fa[..., 0] > 200) & (fa[..., 0] - fa[..., 2] > 40)
row = np.where(tl[600])[0]; shin = np.where(nv[850, 600:])[0]; arm = np.where(sk[:, 700].any() and sk[:, 700])[0]
print('torso depth', row.max() - row.min(), '(target ~150)  shin', len(shin), '(target 56-60)  arm span at x=700', arm.max() - arm.min() if len(arm) else None, '(two arms, ~25-30 each)')
cols = np.where(sk[430:500, 560:].any(0))[0] + 560
print('visible arm skin', cols.min(), cols.max(), 'length', cols.max() - cols.min(), '(target 226-246, as in mountain pose and chin tuck)')
ys = np.where((np.abs(fa - BG).sum(2) > 40).any(1))[0]; print('figure rows', ys.min(), ys.max())
sh = Image.new('RGB', (820 + 20 + 780 + 20 + 512, 1000), 'white')
sh.paste(out.crop((100, 180, 920, 1000)), (0, 0)); sh.paste(out.crop((440, 190, 700, 440)).resize((780, 750), Image.LANCZOS), (840, 0))
sh.paste(out.resize((512, 512), Image.LANCZOS), (1640, 0)); sh.paste(out.crop((150, 840, 410, 1000)).resize((512, 315), Image.LANCZOS), (1640, 520)); sh.save('check.png')
out.crop((620, 860, 880, 1000)).resize((780, 420), Image.LANCZOS).save('front_foot.png')
