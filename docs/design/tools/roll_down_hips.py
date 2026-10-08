"""Pilates roll down (peak), step 3: hips, waist, legs and shoes redrawn after the reference pose.

Input: pre_zoom.png (roll_down_finish.py before framing). The buttocks become a round shape that
sticks out behind the thighs, the shirt ends at the waist (thin torso, hips and upper thighs
visible under it), the legs are slim and straight down to the shoe, and the shoes are the
character's own side-view sneakers (profile master, mirrored).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

S = 4
BG = np.array([240, 254, 249.]); SHADOW = (165, 225, 208); NAVY = (39, 49, 78); NAVY_LINE = (22, 24, 40); SHIRT_LINE = (9, 62, 68)
src = Image.open('pre_zoom.png').convert('RGB'); o = np.asarray(src).astype(int)
H, W = o.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
R, G, B = o[..., 0], o[..., 1], o[..., 2]
def L(m): return Image.fromarray((np.clip(m, 0, 1) * 255).astype('uint8'))
def shifted(img, dx, dy): return img.transform(img.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy))
def spline(p, n=12):
    p = np.array([p[0]] + list(p) + [p[-1]], float); out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(tuple(0.5 * ((2 * p[i]) + (-p[i-1] + p[i+1]) * t + (2*p[i-1] - 5*p[i] + 4*p[i+1] - p[i+2]) * t*t + (-p[i-1] + 3*p[i] - 3*p[i+1] + p[i+2]) * t**3)))
    out.append(tuple(p[-2])); return out
def P(pts): return [(x * S, y * S) for x, y in pts]

skin = (R > 200) & (R - B > 40)
isbg = np.abs(o - BG).sum(2) < 30
issh = np.abs(o - np.array(SHADOW)).sum(2) < 45
navyish = (B > R + 8) & (B > G + 8) & (R < 110)
darkn = (o.max(2) < 90) & (G - R < 25)
box = (xx < 528) & (yy > 500) & (yy < 912)
oldnavy = ndimage.binary_dilation((navyish | darkn) & box, iterations=2) & ~ndimage.binary_dilation(skin, iterations=4)

# --- new shirt edge at the waist (thin torso) and what the shirt loses below it
WAIST = spline([(441, 505), (420, 530), (408, 564), (410, 600), (428, 628), (470, 644), (528, 646)])   # torso as deep as the character's (about 140px), not a thin athlete
cut = Image.new('L', (W, H), 0); ImageDraw.Draw(cut).polygon(WAIST + [(528, 668), (392, 668), (392, 505)], fill=255)
cut = np.asarray(cut) > 0
oldshoes = (yy > 888) & (xx < 540) & ~isbg & ~issh & ~(ndimage.binary_dilation(skin, iterations=3))
hands = ndimage.binary_dilation(skin, iterations=3)
keep = ~isbg & ~issh & ~oldnavy & ~cut & ~oldshoes
keep &= (yy < 890) | hands                                    # in the floor band only the hands stay

# --- floor shadow, same place as before
ys, xs = np.where(issh & (yy > 880))
low = Image.new('RGB', (W * S, H * S), tuple(int(v) for v in BG))
ImageDraw.Draw(low).ellipse([xs.min() * S, ys.min() * S, xs.max() * S, ys.max() * S], fill=SHADOW)
out = low.resize((W, H), Image.LANCZOS)

# --- the character's side-view shoe (profile master), mirrored to point right
mas = Image.open('master.png').convert('RGB'); ma = np.asarray(mas).astype(int)
mnavy = (ma[..., 2] > ma[..., 0] + 8) & (ma[..., 2] > ma[..., 1] + 8) & (ma[..., 0] < 110)
fig = ((np.abs(ma - BG).sum(2) > 30) & (np.abs(ma - np.array(SHADOW)).sum(2) > 45)) | mnavy
sb = (xx > 492) & (xx < 642) & (yy > 880) & (yy < 982)
sm = ndimage.binary_fill_holes(ndimage.binary_closing(fig & sb, iterations=2)) & ~ndimage.binary_dilation(mnavy, iterations=1) & (yy > 904)
lab, n = ndimage.label(sm); sm = lab == np.bincount(lab[lab > 0]).argmax()
sx = np.where(sm.any(0))[0]; print('master shoe x', sx.min(), sx.max(), 'y', np.where(sm.any(1))[0][[0, -1]])
fm = mas.transpose(Image.FLIP_LEFT_RIGHT); fmask = L(sm).transpose(Image.FLIP_LEFT_RIGHT)
heel = 1023 - sx.max()
def shoe(x_heel): out.paste(shifted(fm, x_heel - heel, 0), (0, 0), shifted(fmask, x_heel - heel, 0))
shoe(469); shoe(374)                                          # far shoe first, near shoe in front

# --- hips and legs: round buttocks behind the thighs, slim straight legs down onto the shoes
HEM = 921
back = spline([(452, 544), (438, 533), (418, 529), (398, 534), (382, 547), (372, 570), (368, 604), (368, 640), (369, 678), (371, 720), (375, 790), (379, 860), (381, HEM)])   # hips low and flat: a bent-over pose, not a raised bottom
near_front = spline([(439, HEM), (441, 850), (443, 780), (447, 720), (451, 690)])
far_back = spline([(451, 690), (457, 720), (465, 790), (471, 860), (474, HEM)])
far_front = spline([(529, HEM), (530, 850), (531, 780), (533, 715), (534, 672), (528, 646)])
contour = back + near_front + far_back + far_front + [(528, 630), (470, 620), (452, 560)]      # runs under the shirt
big = out.resize((W * S, H * S), Image.LANCZOS); d = ImageDraw.Draw(big)
d.polygon(P(contour), fill=NAVY)
w = int(3 * S)
for seg in (back, near_front, far_back, far_front, [(381, HEM), (439, HEM)], [(474, HEM), (529, HEM)]):
    d.line(P(seg), fill=NAVY_LINE, width=w, joint='curve')
d.line(P(spline([(451, 690), (458, 664), (470, 640)])), fill=NAVY_LINE, width=int(2.2 * S), joint='curve')                  # far thigh behind the near one
vis = Image.new('L', (W * S, H * S), 0); ImageDraw.Draw(vis).polygon(P(back + near_front + far_back + far_front + WAIST[::-1]), fill=255)   # the part not under the shirt
vis = np.asarray(vis.resize((W, H), Image.LANCZOS)) > 127
leftof = Image.new('L', (W, H), 0); ImageDraw.Draw(leftof).polygon(WAIST + [(528, 1000), (300, 1000), (300, 505)], fill=255)
vis &= np.asarray(leftof) > 0                                       # never cuts into the shirt
out = big.resize((W, H), Image.LANCZOS)
keep &= ~(ndimage.binary_erosion(vis, iterations=2) & ~hands)       # nothing old shows through the new trousers

# --- everything else (shirt, sleeve, arms, hands, head) back on top
out.paste(src, (0, 0), L(keep).filter(ImageFilter.GaussianBlur(0.5)))
# --- dark line wherever the shirt or the sleeve now lies on the trousers (waist hem, sleeve edge)
fa = np.asarray(out).astype(int)
tl = (fa[..., 1] > fa[..., 0] + 60) & (np.abs(fa[..., 1] - fa[..., 2]) < 30) & (fa[..., 1] > 100)
nv = (fa[..., 2] > fa[..., 0] + 25) & (fa[..., 2] > fa[..., 1] + 20) & (fa[..., 0] < 70)
tl = ndimage.binary_opening(tl, iterations=1) & (yy > 500) & (yy < 700) & (xx < 540)
edge = ndimage.binary_dilation(tl, iterations=2) & ndimage.binary_dilation(nv, iterations=2)
a2 = np.asarray(L(edge).filter(ImageFilter.GaussianBlur(0.8))).astype(float)[..., None] / 255
out = Image.fromarray(np.clip(fa * (1 - a2) + np.array(SHIRT_LINE, float) * a2, 0, 255).astype('uint8'))
out.save('pre_zoom4.png')

ZOOM = 1.2; FLOOR = 985
fx = np.where((np.abs(np.asarray(out).astype(float) - BG).sum(2) > 40).any(0))[0]; cx = (fx.min() + fx.max()) / 2
fin = out.transform((W, H), Image.AFFINE, (1 / ZOOM, 0, cx - 512 / ZOOM, 0, 1 / ZOOM, FLOOR - (FLOOR - 15) / ZOOM), resample=Image.BICUBIC, fillcolor=tuple(int(v) for v in BG))
fin.save('final4.png')
sh = Image.new('RGB', (840 + 20 + 512, 1040), 'white')
sh.paste(out.crop((300, 480, 720, 1000)).resize((840, 1040), Image.LANCZOS), (0, 0)); sh.paste(fin.resize((512, 512), Image.LANCZOS), (860, 0)); sh.save('final4_check.png')
