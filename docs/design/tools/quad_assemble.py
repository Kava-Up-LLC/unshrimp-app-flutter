"""Standing quad stretch: final assembly on the harmonizing pass (seed 11, 12 steps, strength 0.25).

Body = the model's redraw of guide.png. Head and neck = the character's own from the guide (no eyes, no blush).
Then: palette of the master, white shoes with teal laces, arms and hands kept as drawn (only recolored), build check.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src = sys.argv[1]
BG = np.array([240, 254, 249.]); SHADOW = np.array([165, 225, 208.])
ga = np.asarray(Image.open('guide.png').convert('RGB')).astype(float)
c = np.asarray(Image.open('front_ref.png').convert('RGB')).astype(float)
H, W = ga.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
def med(a, m): return np.median(a[m], axis=0)
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def soft(m, r): return np.asarray(L(m).filter(ImageFilter.GaussianBlur(r))).astype(float)[..., None] / 255
SKIN = med(c, (c[..., 0] > 200) & (c[..., 0] - c[..., 2] > 60) & (c[..., 1] > 180) & (yy > 300) & (yy < 345))
flatc = np.array([10, 123, 127.]); linec = np.array([9, 62, 68.]); NAVY = np.array([39, 49, 78.]); BROWN = np.array([84, 50, 36.])

g = np.asarray(Image.open(src).convert('RGB')).astype(float)
R, G, B = g[..., 0], g[..., 1], g[..., 2]
bgc = med(g, yy < 30)
mint = (G > R + 30) & (G > 190) & (B > R + 15) & (yy > 915)
shadow = (np.abs(g - med(g, mint)).sum(2) < 36) & (yy > 900)
teal = (G > 60) & (R < G - 50) & (np.abs(G - B) < 40) & ~shadow & (yy < 640)
navy = (B > R + 15) & (B > G + 8) & (R < 110) & (G < 110) & (B < 150)
skin = (R > 200) & (R - B > 60)
o = g.copy()
o[np.abs(g - bgc).sum(2) < 28] = BG
o[shadow] = SHADOW
# shirt: palette teal, the model's lines kept
tg = med(g, teal)[1]
o[teal] = (flatc * np.clip(G / tg, 0, 1.0)[..., None])[teal]
# trousers
o[navy] = (NAVY * np.clip(B / med(g, navy)[2], 0, 1.1)[..., None])[navy]
# skin: arms and hands kept as the model draws them (crisp lines); only the tone and the line color move to the palette
# The model shades the skin in orange (fingertips, under the sleeve) and draws its lines in dark brown: the two are told apart
# by the red channel (shading R >= 195, lines R < 175), so shading goes flat and lines stay crisp.
warm = (R > 60) & (R - B > 25) & (R >= G) & (yy > 230) & (yy < 660) & ~teal & ~navy & ~shadow
t = np.clip((195 - R) / 55, 0, 1)[..., None]
o = np.where(warm[..., None], SKIN * (1 - t) + BROWN * t, o)
# shoes: flat white with their own lines, teal laces
grey = (g.min(2) > 135) & (g.max(2) - g.min(2) < 45) & (np.abs(g - bgc).sum(2) > 40) & ~shadow & ~skin & ~warm
grey = ndimage.binary_dilation(ndimage.binary_opening(grey, iterations=1), iterations=1) & grey
lab, n = ndimage.label(grey); size = np.bincount(lab.ravel()); size[0] = 0
shoe = grey & (size[lab] > 120) & ndimage.binary_dilation(grey & (size[lab] > 800), iterations=14)
o[shoe] = (247, 245, 248)
shoez = ndimage.binary_fill_holes(ndimage.binary_closing(shoe, iterations=4))
o[ndimage.binary_dilation(shoez, iterations=2) & (g.max(2) - g.min(2) < 45) & (g.min(2) > 95) & (np.abs(g - bgc).sum(2) > 40) & ~shadow & ~warm] = (247, 245, 248)
lab, n = ndimage.label(navy); trous = ndimage.binary_dilation(lab == np.bincount(lab[lab > 0]).argmax(), iterations=2)
nb = med(g, navy)[2]; print('navy B', nb)
lace = (g.max(2) < 150) & (B < 0.82 * nb) & ~skin                                           # the model's black laces (the trousers are bluer)
lt = np.clip((235 - g.mean(2)) / 170, 0, 1)[..., None]
boxes = [tuple(int(v) for v in b.split(',')) for b in sys.argv[2:] if not b.startswith('arm:')]
ARMS = [tuple(int(v) for v in b[4:].split(',')) for b in sys.argv[2:] if b.startswith('arm:')]   # arm stretches whose edge is redrawn
inbox = np.zeros((H, W), bool)
for x0, y0, x1, y1 in boxes: inbox |= (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
o = np.where((lace & inbox)[..., None], np.array([247, 245, 248.]) * (1 - lt) + np.array([13, 100, 100.]) * lt, o)

# arms (above the wrists): the model's outline there is pale and broken, so the edge against the background is redrawn
# as one smooth thin brown line. The hands keep the model's own crisp lines.
from PIL import ImageFilter as IF
oi = np.clip(o, 0, 255)
isbg = np.abs(oi - BG).sum(2) < 12
armreg = np.zeros((H, W), bool)
for x0, y0, x1, y1 in ARMS: armreg |= (xx > x0) & (xx < x1) & (yy > y0) & (yy < y1)
tealish = (oi[..., 1] > oi[..., 0] + 20) & (np.abs(oi[..., 1] - oi[..., 2]) < 45)
navyish = (oi[..., 2] > oi[..., 0] + 8) & (oi[..., 0] < 110)
M0 = ndimage.binary_fill_holes(ndimage.binary_closing(~isbg & ~tealish & ~navyish, iterations=2)) & ~tealish & ~navyish
K = 4
Mh = L(M0).resize((W * K, H * K), Image.BICUBIC).filter(IF.GaussianBlur(K * 1.3)).point(lambda v: 255 if v > 127 else 0)
ring = np.asarray(Mh.filter(IF.MaxFilter(2 * K + 1)).resize((W, H), Image.LANCZOS)).astype(float) - np.asarray(Mh.filter(IF.MinFilter(2 * 6 + 1)).resize((W, H), Image.LANCZOS)).astype(float)
Ms = np.asarray(Mh.resize((W, H), Image.LANCZOS)).astype(float) / 255
band = armreg & ndimage.binary_dilation(isbg, iterations=4) & ndimage.binary_dilation(M0, iterations=3) & ~tealish & ~navyish
o = np.where(band[..., None], np.where((Ms > 0.5)[..., None], SKIN, BG), o)
ra = (np.clip(ring / 255, 0, 1) * 0.92 * band)[..., None]
o = o * (1 - ra) + BROWN * ra

# --- the character's own head and neck from the guide (hard rule 1: no eyes; no blush)
sil = np.asarray(Image.open('head_zone.png').convert('L')) > 127                          # head and neck above the collar, from the guide
gteal = (ga[..., 1] > ga[..., 0] + 30) & (np.abs(ga[..., 1] - ga[..., 2]) < 45) & (ga[..., 1] > 40)
sil = ndimage.binary_fill_holes(sil & ~ndimage.binary_dilation(gteal, iterations=2))
mhead = (ndimage.binary_dilation(sil, iterations=18) & ~sil & (yy < 250)) & ~ndimage.binary_dilation(teal, iterations=2)
hairm = (g.max(2) < 110) & (yy < 250) & ~ndimage.binary_dilation(teal, iterations=3)
mhead |= ndimage.binary_dilation(hairm, iterations=3) & ~sil & ~ndimage.binary_dilation(teal, iterations=2)
o = np.where(mhead[..., None], BG, o)
al = soft(ndimage.binary_erosion(sil, iterations=1), 0.8) * (~teal)[..., None]
gh = ga + ((ga[..., 0] > 235) & (ga[..., 1] > 190) & (ga[..., 2] > 150))[..., None] * (SKIN - np.array([255, 209, 170.]))
o = o * (1 - al) + gh * al
# last: grey patches the model leaves on the shoes -> white (their dark lines stay); the white undershirt sliver at the collar -> shirt
oi = np.clip(o, 0, 255)
greyp = (oi.max(2) - oi.min(2) < 30) & (oi.min(2) > 120) & (oi.max(2) < 243) & ndimage.binary_dilation(shoez, iterations=40) & ~shadow & (np.abs(oi - BG).sum(2) > 14)
o[greyp] = (247, 245, 248)
sliver = (oi.min(2) > 215) & (oi.max(2) - oi.min(2) < 20) & (np.abs(oi - BG).sum(2) > 14) & (yy > 200) & (yy < 300) & ndimage.binary_dilation(teal, iterations=4)
o[ndimage.binary_dilation(sliver, iterations=2) & ~teal & (np.abs(oi - BG).sum(2) > 14) & (oi.min(2) > 150) & (oi[..., 0] - oi[..., 2] < 40)] = flatc
out = Image.fromarray(np.clip(o, 0, 255).astype('uint8')); out.save('final.png')

# --- build check (hard rule 2)
fa = np.asarray(out).astype(int)
tl = (fa[..., 1] > fa[..., 0] + 30) & (np.abs(fa[..., 1] - fa[..., 2]) < 45) & (fa[..., 1] > 60) & (yy < 640)
sk = (fa[..., 0] > 200) & (fa[..., 0] - fa[..., 2] > 40)
row = np.where(tl[470])[0]; print('torso depth at y=470:', row.max() - row.min(), '(target ~150 in profile)')
fig = (np.abs(fa - BG).sum(2) > 30) & (np.abs(fa - SHADOW).sum(2) > 45); ys = np.where(fig.any(1))[0]
print('figure rows', ys.min(), ys.max(), 'height', ys.max() - ys.min(), '(master 59-973)')
