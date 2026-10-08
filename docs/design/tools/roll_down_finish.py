"""Pilates roll down (peak), final assembly on the freer guided pass (seed 11, 8 steps, strength 0.2).

The model draws the folded body, sleeve, arms and hands. The head is the character's own head: the profile
master's head, flipped so it hangs (neck up, crown down, face toward the legs). Other edits: palette of the
master, plain trouser legs, no stray lines on the skin, floor shadow in our color, laces in teal.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SRC = sys.argv[1] if len(sys.argv) > 1 else 'roll_s11_8_0.2.png'
BG = np.array([240, 254, 249.]); SHADOW = (165, 225, 208); HAIR = np.array([21, 36, 43.])
ref = Image.open('front_ref.png').convert('RGB'); ra = np.asarray(ref).astype(int); c = ra.astype(float)
H, W = c.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
cs = (c[..., 0] > 200) & (c[..., 0] - c[..., 2] > 60) & (c[..., 1] > 180) & (yy > 300) & (yy < 345)
SKIN = np.median(c[cs], axis=0)
def med(a, m): return np.median(a[m], axis=0)
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def soft(m, r): return np.asarray(L(m).filter(ImageFilter.GaussianBlur(r))).astype(float)[..., None] / 255
def shifted(img, dx, dy): return img.transform(img.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy))

g = np.asarray(Image.open(SRC).convert('RGB')).astype(float)
R, G, B = g[..., 0], g[..., 1], g[..., 2]
bgc = med(g, yy < 40)
teal = (G > 60) & (R < G - 50) & (np.abs(G - B) < 40) & (yy < 760)
navy = (B > R + 15) & (B > G + 8) & (R < 110) & (G < 110) & (B < 150)
skin = (R > 200) & (R - B > 60)
flat = skin & (G > 180)
dark = (R < 85) & (G < 80) & (np.abs(G - B) < 16) & (xx > 575) & (xx < 750) & (yy > 625) & (yy < 820)
lab, _ = ndimage.label(dark); hair0 = lab == np.bincount(lab[lab > 0]).argmax()

# --- 1) palette
o = g.copy()
o[teal] = (np.array([10, 123, 127]) * np.clip(G / med(g, teal)[1], 0, 1.1)[..., None])[teal]
o[navy] = (np.array([39, 49, 78]) * np.clip(B / med(g, navy)[2], 0, 1.15)[..., None])[navy]
w = np.clip((G - 157) / 30, 0, 1)[..., None]
o[skin] = (g + w * (SKIN - med(g, flat)))[skin]
o[np.abs(g - bgc).sum(2) < 16] = BG
brown = (R > B + 20) & (R >= G) & ~skin
k = (np.clip((165 - R) / 55, 0, 1) * brown)[..., None]
o = o * (1 - 0.55 * k)

# --- 2) the model's head goes; the character's own head hangs in its place
def ball(r): return np.hypot(*np.mgrid[-r:r + 1, -r:r + 1]) <= r
lab, n = ndimage.label(skin & (xx > 578) & (xx < 705) & (yy > 600) & (yy < 790))
ids = np.unique(lab[(xx > 590) & (xx < 660) & (yy > 640) & (yy < 760) & (lab > 0)])
mhead = ndimage.binary_dilation(hair0 | np.isin(lab, ids), structure=ball(13))
tealish = (o[..., 1] > o[..., 0] + 35) & (np.abs(o[..., 1] - o[..., 2]) < 40) & (o[..., 1] > 45)
torso = ndimage.binary_closing(tealish, iterations=2)
farm = ndimage.binary_dilation(skin & (yy > 798) & (xx > 630), iterations=4) & (yy > 798)      # far arm with its outline
mh0 = hair0 | np.isin(lab, ids)
near = (xx < 588) & (np.abs(g - bgc).sum(2) > 40) & ~ndimage.binary_dilation(mh0, iterations=3)
near &= ~ndimage.binary_dilation(mh0, structure=ball(10)) | skin | torso
mhead &= ~torso & ~farm & ~near
o[mhead] = BG
for y in range(760, 806): o[y, 640:702] = o[808, 640:702]                 # far arm runs up behind the head
fillbox = (xx > 560) & (xx < 712) & (yy > 580) & (yy < 676)
tl0 = (o[..., 1] > o[..., 0] + 35) & (np.abs(o[..., 1] - o[..., 2]) < 40) & (o[..., 1] > 45)
t2 = ndimage.binary_closing(np.pad(tl0, 60), structure=ball(24))[60:-60, 60:-60]
t2 = soft(t2, 2.5)[..., 0] > 0.5                                       # smooth, no steps
isb = np.abs(o - BG).sum(2) < 12
o[t2 & fillbox & isb] = (10, 123, 127)                                # the shirt closes where the model's neck and face were
o[~t2 & fillbox & tl0 & ~ndimage.binary_erosion(tl0, iterations=4)] = BG   # and loses the ragged teeth on its edge

mas = Image.open('master.png').convert('RGB'); ma = np.asarray(mas).astype(int)
mt = (ma[..., 1] > ma[..., 0] + 30) & (np.abs(ma[..., 1] - ma[..., 2]) < 45) & (ma[..., 1] > 40)              # shirt and its dark lines
hm = (np.abs(ma - BG).sum(2) > 30) & (yy < 250) & (xx > 430) & (xx < 625) & ~ndimage.binary_dilation(mt, iterations=2)
lab, n = ndimage.label(hm); hm = ndimage.binary_erosion(ndimage.binary_fill_holes(lab == np.bincount(lab[lab > 0]).argmax()), iterations=1)
NECK = (554, 236)                                                    # neck base of the master
ANGLE = float(sys.argv[2]) if len(sys.argv) > 2 else 25
TARGET = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (632, 612)
def hang(img):
    img = shifted(img, 512 - NECK[0], 512 - NECK[1]).transpose(Image.FLIP_TOP_BOTTOM)      # neck at the center, crown down
    img = img.rotate(ANGLE, resample=Image.BICUBIC, center=(512, 511))
    return shifted(img, TARGET[0] - 512, TARGET[1] - 511)
hmask = np.asarray(hang(L(hm))).astype(float)[..., None] / 255
hrgb = np.asarray(hang(mas)).astype(float)
hmask = hmask * (1 - soft(near, 0.6))                                # the near sleeve and arm stay in front of the head
tl_now = (o[..., 1] > o[..., 0] + 35) & (np.abs(o[..., 1] - o[..., 2]) < 40) & (o[..., 1] > 45)
cover = (soft(ndimage.binary_closing(tl_now, iterations=3), 4.0)[..., 0] > 0.5) & (yy < TARGET[1] + 26)
isb = np.abs(o - BG).sum(2) < 12
o[cover & fillbox & isb] = (10, 123, 127)
hmask = hmask * (1 - soft(cover, 0.7))                               # the collar covers the base of the neck
edge = ndimage.binary_dilation(cover, iterations=2) & ~cover & (np.asarray(hang(L(hm))) > 127) & fillbox
collar = soft(ndimage.binary_dilation(edge, iterations=1), 0.7)       # collar line where the shirt meets the neck
o = o * (1 - hmask) + hrgb * hmask
o = o * (1 - collar) + np.array([9, 62, 68.]) * collar

# --- 3) no face lines, no mark on the arm: thin dark strokes inside flat skin
sk2 = (o[..., 0] > 200) & (o[..., 0] - o[..., 2] > 40)
inner = ndimage.binary_erosion(ndimage.binary_closing(sk2, iterations=4), iterations=5)
stroke = inner & ~sk2 & (hmask[..., 0] < 0.05)                                      # not on our head
stroke = ndimage.binary_dilation(stroke, iterations=1) & inner
o[stroke] = SKIN

# --- 2b) no gap between the shirt and the neck: background caught between them becomes shirt
isb = np.abs(o - BG).sum(2) < 12
tl1 = (o[..., 1] > o[..., 0] + 60) & (np.abs(o[..., 1] - o[..., 2]) < 30) & (o[..., 1] > 100)
gap = isb & fillbox & (yy < TARGET[1] + 40) & (xx < TARGET[0] + 6) & ndimage.binary_dilation(tl1, structure=ball(16)) & ndimage.binary_dilation(hmask[..., 0] > 0.5, structure=ball(16))
gap = ndimage.binary_opening(gap, iterations=1)
o[gap] = (10, 123, 127)

# --- 3a) outline where a shape now touches the background without one
isbg = np.abs(o - BG).sum(2) < 12
tl = (o[..., 1] > o[..., 0] + 60) & (np.abs(o[..., 1] - o[..., 2]) < 30) & (o[..., 1] > 100)
sk3 = (o[..., 0] > 200) & (o[..., 0] - o[..., 2] > 40)
for cls, col in ((tl, (9, 62, 68)), (sk3, (52, 34, 26))):
    ring = ndimage.binary_dilation(cls, iterations=2) & ~cls & isbg & (hmask[..., 0] < 0.05)
    a2 = soft(ndimage.binary_dilation(ring, iterations=1) & ~cls, 0.6) * (hmask < 0.05)
    o = o * (1 - a2) + np.array(col, float) * a2

# --- 3b) plain trouser legs: no crease lines, no gathered ankles drawn inside
nv = ndimage.binary_closing(navy, iterations=3)
inside = ndimage.binary_erosion(nv, iterations=5) & (yy > 660)
o[inside] = (39, 49, 78)

# --- 4) floor shadow in our color, laces in teal (the model's shoes stay: they match the view)
shadow = (np.abs(g - med(g, (yy > 940) & (yy < 975) & (xx > 330) & (xx < 370))).sum(2) < 30) & (yy > 900)
o[shadow] = SHADOW
lum = g.mean(2); spread = g.max(2) - g.min(2)
for x0, y0, x1, y1 in ((384, 899, 442, 930), (512, 893, 548, 930)):
    lace = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1) & (spread < 34) & (lum < 215) & ~skin
    t = np.clip((235 - lum) / 150, 0, 1)[..., None]
    o[lace] = (np.array([247, 245, 248.]) * (1 - t) + np.array([13, 100, 100.]) * t)[lace]
out = Image.fromarray(np.clip(o, 0, 255).astype('uint8'))
out.save('pre_zoom.png')
# --- 5) framing: a folded figure is enlarged so it fills the frame like the reference pose (about 65% of the height)
ZOOM = 1.2
fx = np.where((np.abs(np.asarray(out).astype(float) - BG).sum(2) > 40).any(0))[0]; cx = (fx.min() + fx.max()) / 2
FLOOR = 985
out = out.transform((W, H), Image.AFFINE, (1 / ZOOM, 0, cx - 512 / ZOOM, 0, 1 / ZOOM, FLOOR - (FLOOR - 15) / ZOOM), resample=Image.BICUBIC, fillcolor=tuple(int(v) for v in BG))
out.save('final3.png')
sh = Image.new('RGB', (1024 + 20 + 512, 1024), 'white')
sh.paste(out, (0, 0)); sh.paste(out.resize((512, 512), Image.LANCZOS), (1044, 0)); sh.save('final3_check.png')
