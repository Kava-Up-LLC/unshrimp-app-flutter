"""Pilates roll down (peak): final assembly on the harmonizing pass.

The guide (guide6.png) already has the right pose and the character's parts (master legs, shoes and head,
mountain-pose arms). The guided pass (seed 11, 12 steps, strength 0.25) redraws the whole figure with one
consistent line and keeps the character. Here: palette of the master, hair in the master color, no eye,
teal laces, framing.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src = sys.argv[1]; ZOOM = 1.2; FLOOR = 985
BG = np.array([240, 254, 249.]); SHADOW = np.array([165, 225, 208.])
gd = Image.open('guide6.png').convert('RGB'); ga = np.asarray(gd).astype(float)
p4 = np.asarray(Image.open('pre_zoom4.png').convert('RGB')).astype(int)
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
shadow = (np.abs(g - med(g, (yy > 940) & (yy < 970) & (xx > 330) & (xx < 360))).sum(2) < 30) & (yy > 880)
teal = (G > 60) & (R < G - 50) & (np.abs(G - B) < 40) & ~shadow & (yy < 720)
navy = (B > R + 15) & (B > G + 8) & (R < 110) & (G < 110) & (B < 150)
skin = (R > 200) & (R - B > 60)
flat = skin & (G > 180)
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

# --- hair in the master color (flat)
hair = (g.max(2) < 95) & (np.abs(G - B) < 22) & (G >= R) & (xx > 590) & (yy > 630) & (yy < 800)
lab, n = ndimage.label(hair); hair = lab == np.bincount(lab[lab > 0]).argmax()
hair = ndimage.binary_fill_holes(ndimage.binary_closing(hair, iterations=2))
o[hair] = (21, 36, 43)
# --- no eyes (hard rule 1): every stroke at eye height inside the face goes
face = ndimage.binary_fill_holes(ndimage.binary_closing(skin & (xx > 585) & (xx < 700) & (yy > 640) & (yy < 780), iterations=5))
inner = ndimage.binary_erosion(face, iterations=3)
strokes = inner & ~skin & ~ndimage.binary_dilation(hair, iterations=1) & (yy > 700) & ~((xx > 652) & (xx < 692) & (yy > 660) & (yy < 702))
lab, n = ndimage.label(ndimage.binary_dilation(strokes, iterations=1))
touch = np.unique(lab[ndimage.binary_dilation(hair, iterations=2) & (lab > 0)])
erase = (lab > 0) & ~np.isin(lab, touch)
erase |= strokes & (xx > 612) & (xx < 656) & (yy > 708) & (yy < 746)       # and whatever hangs off the fringe at eye height
erase = ndimage.binary_dilation(erase, iterations=2) & ~hair
o[erase] = np.median(o[(xx > 610) & (xx < 632) & (yy > 680) & (yy < 704) & skin], axis=0)
print('eye-height strokes erased:', int(erase.sum()), 'px')
# --- laces in teal
from scipy.ndimage import uniform_filter
white = (g.min(2) > 200) & (g.max(2) - g.min(2) < 25) & (yy > 890)
near_white = uniform_filter(white.astype(float), size=17) > 0.22
hand = ndimage.binary_dilation(skin & (yy > 880) & (xx > 531), iterations=3)
lace = (g.max(2) < 150) & (g.max(2) - g.min(2) < 45) & near_white & (yy > 904) & (yy < 944) & (((xx > 416) & (xx < 468)) | ((xx > 516) & (xx < 562))) & ~hand
ankle = skin & (yy > 900) & (yy < 938) & (xx < 531)                  # no bare ankle: the opening of the shoe is white
o[ndimage.binary_dilation(ankle, iterations=1) & (g.min(2) > 120)] = (247, 245, 248)
t = np.clip((235 - g.mean(2)) / 170, 0, 1)[..., None]
o[lace] = (np.array([247, 245, 248.]) * (1 - t) + np.array([13, 100, 100.]) * t)[lace]
out = Image.fromarray(np.clip(o, 0, 255).astype('uint8')); out.save('pre_zoom6.png')
fx = np.where((np.abs(np.asarray(out).astype(float) - BG).sum(2) > 40).any(0))[0]; cx = (fx.min() + fx.max()) / 2
fin = out.transform((W, H), Image.AFFINE, (1 / ZOOM, 0, cx - 512 / ZOOM, 0, 1 / ZOOM, FLOOR - (FLOOR - 15) / ZOOM), resample=Image.BICUBIC, fillcolor=tuple(int(v) for v in BG))
fin.save('final6.png')
raw = Image.open(src).convert('RGB')
sh = Image.new('RGB', (630 * 2 + 20 + 20 + 512, 780), 'white')
sh.paste(raw.crop((320, 480, 740, 1000)).resize((630, 780), Image.LANCZOS), (0, 0)); sh.paste(out.crop((320, 480, 740, 1000)).resize((630, 780), Image.LANCZOS), (650, 0))
sh.paste(fin.resize((512, 512), Image.LANCZOS), (1300, 0)); sh.save('final6_check.png')
out.crop((560, 590, 740, 790)).resize((720, 800), Image.LANCZOS).save('head6.png'); out.crop((380, 860, 720, 990)).resize((1020, 390), Image.LANCZOS).save('feet6.png')

# --- build check (hard rule 2)
fa = np.asarray(out).astype(int)
nv = (fa[..., 2] > fa[..., 0] + 8) & (fa[..., 2] > fa[..., 1] + 8) & (fa[..., 0] < 110); tl2 = (fa[..., 1] > fa[..., 0] + 30) & (np.abs(fa[..., 1] - fa[..., 2]) < 45) & (yy < 720)
sk2 = (fa[..., 0] > 200) & (fa[..., 0] - fa[..., 2] > 40)
col = np.where(tl2[:, 480])[0]; xs = np.where(nv[760, :450])[0]; ar = np.where(sk2[720, 520:600])[0]
print('torso depth', col.max() - col.min(), '(target ~140)  thigh', xs.max() - xs.min(), '(target 75-78)  arm', len(ar), '(target ~42)')
