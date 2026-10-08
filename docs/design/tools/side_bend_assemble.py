"""Standing side bend: final assembly on the harmonizing pass (seed 11, 12 steps, strength 0.25).

The pass over this guide comes out clean (flat skin, thin dark lines), so the model's drawing is kept as it is and only moved to
the palette. Head = the character's own from the guide (no eyes, no blush). Shoes white, laces teal.
Every extra rule on arms and hands (flattening, redrawn edges, pasted hands) broke their lines in earlier tries.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src = sys.argv[1]
boxes = [tuple(int(v) for v in b.split(',')) for b in sys.argv[2:]]                       # lace boxes
BG = np.array([240, 254, 249.]); SHADOW = np.array([165, 225, 208.])
ga = np.asarray(Image.open('guide.png').convert('RGB')).astype(float)
c = np.asarray(Image.open('front_ref.png').convert('RGB')).astype(float)
H, W = ga.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
def med(a, m): return np.median(a[m], axis=0)
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def soft(m, r): return np.asarray(L(m).filter(ImageFilter.GaussianBlur(r))).astype(float)[..., None] / 255
SKIN = med(c, (c[..., 0] > 200) & (c[..., 0] - c[..., 2] > 60) & (c[..., 1] > 180) & (yy > 300) & (yy < 345))
flatc = np.array([10, 123, 127.]); NAVY = np.array([39, 49, 78.])

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
o[teal] = (flatc * np.clip(G / med(g, teal)[1], 0, 1.0)[..., None])[teal]
o[navy] = (NAVY * np.clip(B / med(g, navy)[2], 0, 1.1)[..., None])[navy]
flat = skin & (G > med(g, skin)[1] - 8)
shade = ndimage.binary_dilation(ndimage.binary_opening(skin & ~flat, iterations=3), iterations=3) & skin & ~flat
o[shade] = (241, 146, 99)                                                                    # broad shading (the neck under the chin) -> the palette's skin shadow
o[flat] = SKIN                                                                               # flat skin to the palette tone; lines and the chin shadow stay as drawn
brown = (R > B + 20) & (R >= G) & ~skin & (np.abs(g - bgc).sum(2) > 40)                      # the model's orange-brown lines -> the dark brown outline of the character
k = (np.clip((235 - R) / 90, 0, 1) * brown)[..., None]
o = o * (1 - 0.6 * k)
shirtz = ndimage.binary_fill_holes(ndimage.binary_closing(teal, iterations=3))
under = (R > 244) & (B > 244) & (yy < 500) & ndimage.binary_dilation(teal, iterations=8)        # white undershirt at the collar (whiter than the mint background)
under = ndimage.binary_dilation(ndimage.binary_opening(under, iterations=2), iterations=5) & ~teal & (g.min(2) > 150) & ~flat
o[under] = flatc
# shoes: white, laces teal
grey = (g.min(2) > 135) & (g.max(2) - g.min(2) < 45) & (np.abs(g - bgc).sum(2) > 40) & ~shadow & (yy > 860)
o[grey] = (247, 245, 248)
warm_s = (yy > 880) & (R > B + 30) & ~shadow & (np.abs(g - bgc).sum(2) > 40)                # colored soles and stripes the model adds to the shoes
o[warm_s & (R > 185)] = (247, 245, 248)
thick_s = ndimage.binary_dilation(ndimage.binary_opening(warm_s & (R <= 185), iterations=2), iterations=2)
o[warm_s & (R <= 185)] = (84, 50, 36)
o[warm_s & thick_s] = (247, 245, 248)                                                        # colored heel tabs -> white; thin lines stay as outline
inbox = np.zeros((H, W), bool)
for x0, y0, x1, y1 in boxes: inbox |= (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
lace = inbox & (g.max(2) < 170) & ~navy
lt = np.clip((235 - g.mean(2)) / 150, 0, 1)[..., None]
o = np.where(lace[..., None], np.array([247, 245, 248.]) * (1 - lt) + np.array([13, 100, 100.]) * lt, o)

# --- the character's own head from the guide
sil = np.asarray(Image.open('head_zone.png').convert('L')) > 127
sil = ndimage.binary_fill_holes(sil)
near = ndimage.binary_dilation(sil, iterations=30)
hair = (g.max(2) < 95) & (B >= R - 8) & near                                                # the model's hair
lab, n = ndimage.label(hair); size = np.bincount(lab.ravel()); size[0] = 0; hair = hair & (size[lab] > 400)
lab, n = ndimage.label(skin); area = np.bincount(lab.ravel()); ins = np.bincount(lab[sil], minlength=n + 1); area[0] = 1; ins[0] = 0
face = (ins / area > 0.5)[lab] & near                                                        # the model's face and ears: skin regions that lie inside our head
blush = (R > 220) & (G < 185) & (B > 130) & ndimage.binary_dilation(ndimage.binary_fill_holes(face), iterations=2)
mh = ndimage.binary_fill_holes(ndimage.binary_closing(hair | face | blush, iterations=3))
mh = ndimage.binary_dilation(mh, iterations=3) & ~teal
out_ = mh & ~sil                                                                             # what our head does not cover: filled from its surroundings
_, (iy, ix) = ndimage.distance_transform_edt(mh, return_indices=True)
o = np.where(out_[..., None], o[iy, ix], o)
print('model head px outside ours (inpainted):', int(out_.sum()))
sil &= ndimage.binary_dilation(mh, iterations=3)                                             # head only: the neck stays as the model drew it, into the collar
al = soft(ndimage.binary_erosion(sil, iterations=1), 0.8) * (~teal)[..., None]
gh = ga + ((ga[..., 0] > 235) & (ga[..., 1] > 190) & (ga[..., 2] > 150))[..., None] * (SKIN - np.array([255, 209, 170.]))
o = o * (1 - al) + gh * al
# shoes: the character's own approved sneakers from the guide (the model draws colored soles and an orange outline).
#     The pass stays aligned with the guide, so they fit under the trousers.
oi = np.clip(o, 0, 255)
gnavy = (ga[..., 2] > ga[..., 0] + 8) & (ga[..., 2] > ga[..., 1] + 8) & (ga[..., 0] < 110)
gsh = (np.abs(ga - BG).sum(2) > 30) & (np.abs(ga - SHADOW).sum(2) > 45) & ~gnavy & (yy > 880)       # the guide's shoes
lab, n = ndimage.label(gsh); size = np.bincount(lab.ravel()); size[0] = 0; gsh = ndimage.binary_fill_holes(size[lab] > 1500)
msh = (np.abs(oi - BG).sum(2) > 14) & (np.abs(oi - SHADOW).sum(2) > 30) & ~navy & (yy > 880)       # the model's shoes
msh = ndimage.binary_dilation(msh, iterations=2) & ~navy
rows = np.zeros((H, W), bool)                                                                # the floor shadow, row by row, under what is cleared
for y in range(880, H):
    xs_ = np.where(shadow[y])[0]
    if len(xs_): rows[y, xs_.min():xs_.max() + 1] = True
o = np.where(msh[..., None], np.where(rows[..., None], SHADOW, BG), o)
sa = soft(gsh, 0.7)
o = o * (1 - sa) + ga * sa
# neck base: whatever is left of the undershirt goes to the shirt color, and the ragged edge of the neck shadow is smoothed
nb = ndimage.binary_dilation(shade, iterations=10) & ~ndimage.binary_dilation(sil, iterations=2) & (yy > 230) & (yy < 360)
oi = np.clip(o, 0, 255)
o[nb & (oi.min(2) > 195) & (oi[..., 0] - oi[..., 2] < 40)] = flatc
whit = (oi.min(2) > 215) & (oi.max(2) - oi.min(2) < 22) & (yy < 520) & (ndimage.uniform_filter((teal | skin).astype(float), 11) > 0.5)
o[whit] = flatc                                                                              # white specks left inside the collar
sm = np.stack([ndimage.median_filter(np.clip(o[..., c], 0, 255), size=7) for c in range(3)], -1)
o = np.where(nb[..., None], sm, o)
oi = np.clip(o, 0, 255)                                                                      # last: small light specks enclosed by the shirt or the neck
light = (oi.min(2) > 200) & (oi[..., 0] - oi[..., 2] < 30) & (yy < 520)
lab, n = ndimage.label(light); size = np.bincount(lab.ravel()); size[0] = 0
o[light & (size[lab] < 220)] = flatc
out = Image.fromarray(np.clip(o, 0, 255).astype('uint8')); out.save('final.png')

fa = np.asarray(out).astype(int)
tl = (fa[..., 1] > fa[..., 0] + 30) & (np.abs(fa[..., 1] - fa[..., 2]) < 45) & (fa[..., 1] > 60) & (yy < 640)
row = np.where(tl[540])[0]; print('torso width at y=540:', row.max() - row.min(), '(target ~195 from the front; the leaning torso reads wider on a row)')
fig = (np.abs(fa - BG).sum(2) > 30) & (np.abs(fa - SHADOW).sum(2) > 45); ys = np.where(fig.any(1))[0]; xs = np.where(fig.any(0))[0]
print('figure rows', ys.min(), ys.max(), 'cols', xs.min(), xs.max())
