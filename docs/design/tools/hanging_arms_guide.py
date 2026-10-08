"""Mountain pose: the arms of the profile master (chin-tuck-hold) on the front body.

The master's hanging arm is cut out, its outline redrawn smooth, and pasted under each sleeve
(mirrored for the other side), so both arms are the master's own arm: same length, taper and hand. The arm is straightened\nfirst (its elbow curve reads as crooked from the front), so it hangs vertical.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

BG = np.array([240, 254, 249.]); LINE = np.array([44, 30, 24.])
DX, DY = 46, -6
Y_CUT = 540                                   # wrist: below it the hand is drawn open (guide for the model)
body = np.asarray(Image.open('final_b.png').convert('RGB')).astype(float)
mas = np.asarray(Image.open('master.png').convert('RGB')).astype(float)
H, W = body.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]

def blur(m, r): return np.asarray(Image.fromarray((m * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(r))).astype(float) / 255
def skin_of(a): return (a[..., 0] > 200) & (a[..., 0] - a[..., 2] > 40)

# --- 1) body without its arms
sk = skin_of(body) & (yy > 376) & (yy < 620) & ((xx < 430) | (xx > 590))
er = ndimage.binary_dilation(sk, iterations=6)
keep = ((body[..., 1] > 90) & (body[..., 0] < 60)) | ((body[..., 2] > 60) & (body[..., 0] < 70) & (body[..., 1] < 80))   # shirt, trousers
o = body.copy(); o[er & ~keep] = BG

# --- 2) the master's arm, outline redrawn
ms = skin_of(mas) & (xx > 545) & (xx < 620) & (yy > 377) & (yy < 630)
ms = ndimage.binary_fill_holes(ndimage.binary_closing(ms, iterations=3))
# straighten: shift every row so the centerline of the arm is vertical (the hand moves as one piece)
rows = np.arange(388, 541); cen = np.array([np.where(ms[y])[0].mean() for y in rows])
fit = np.polyval(np.polyfit(rows, cen, 3), rows)
XC = 591.0
dxs = np.zeros(H); dxs[388:541] = XC - fit; dxs[:388] = dxs[388]; dxs[541:] = dxs[540]
print('row shifts', dxs[388], dxs[460], dxs[540])
xs_ = np.arange(W, dtype=float)
msf = ms.astype(float); mas2 = mas.copy()
for y in range(370, 632):
    msf[y] = np.interp(xs_ - dxs[y], xs_, ms[y].astype(float))
    for ch in range(3): mas2[y, :, ch] = np.interp(xs_ - dxs[y], xs_, mas[y, :, ch])
ms = msf > 0.5; mas = mas2
top = np.where(ms[388])[0]; ms[350:388, top.min():top.max() + 1] = True          # runs up under the sleeve
sm = blur(ms.astype(float), 2.2)                                                    # smooth the jagged edge
fill = np.clip((sm - 0.56) / 0.08, 0, 1)                                            # skin, slightly inside
ring = np.clip((sm - 0.20) / 0.08, 0, 1)                                            # skin + outline
src = mas.copy(); src[350:388, top.min():top.max() + 1] = mas[389, top.min():top.max() + 1][None]
flat = np.array([255, 209, 170.])
edge = ~ndimage.binary_erosion(ms, iterations=3)                                    # fringe pixels of the old edit -> flat skin
light = edge & (src.min(2) > 150) | (edge & ~skin_of(src))
src[light] = flat
layer = LINE * (1 - fill[..., None]) + src * fill[..., None]
al = ring
def shift(a, dx, dy): return np.roll(np.roll(a, dy, 0), dx, 1)
from PIL import ImageDraw
def spline(p, n=12):
    p = np.array([p[-1]] + p + [p[0], p[1]], float); out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * ((2 * p[i]) + (-p[i-1] + p[i+1]) * t + (2*p[i-1] - 5*p[i] + 4*p[i+1] - p[i+2]) * t*t + (-p[i-1] + 3*p[i] - 3*p[i+1] + p[i+2]) * t**3))
    return [tuple(q) for q in out]
# open relaxed hand seen from the side: fingers together pointing down, thumb on the inner side (viewer's right arm)
HAND = [(-13, -8), (-15, 14), (-17, 28), (-18, 40), (-16, 48), (-12, 47), (-9, 39), (-8, 50), (-7, 62), (-4, 70), (2, 72), (8, 66), (12, 52), (14, 36), (14, 16), (13, -8)]
S = 4; hm = Image.new('L', (W * S, H * S), 0)
ImageDraw.Draw(hm).polygon([((XC + x) * S, (Y_CUT - DY - 2 + y) * S) for x, y in spline(HAND)], fill=255)
hm = np.asarray(hm.resize((W, H), Image.LANCZOS)).astype(float) / 255
cut = np.clip((Y_CUT - DY + 1 - yy) / 2.0, 0, 1)                                    # the master's arm stops at the wrist
hs = blur(np.maximum((hm > 0.5).astype(float), (sm > 0.5) * (cut > 0.5)), 2.2)       # arm + hand as one silhouette
fill = np.clip((hs - 0.56) / 0.08, 0, 1); ring = np.clip((hs - 0.20) / 0.08, 0, 1)
src = np.where((cut > 0.5)[..., None], src, flat)
layer = LINE * (1 - fill[..., None]) + src * fill[..., None]; al = ring
for mirror in (False, True):
    L, A = shift(layer, DX, DY), shift(al, DX, DY)
    if mirror: L, A = L[:, ::-1][:, 2:], A[:, ::-1][:, 2:]; L = np.pad(L, ((0, 0), (0, 2), (0, 0)), mode='edge'); A = np.pad(A, ((0, 0), (0, 2)))
    o = o * (1 - A[..., None]) + L * A[..., None]

# --- 3) sleeves back on top
slv = (yy < 382) & (yy > 290) & (((xx > 352) & (xx < 426)) | ((xx > 594) & (xx < 668))) & (np.abs(body - BG).sum(2) > 24)
s = blur(slv.astype(float), 0.6)[..., None]
o = o * (1 - s) + body * s
out = Image.fromarray(np.clip(o, 0, 255).astype('uint8')); out.save('guide_hands.png')
m = Image.open('master.png')
sh = Image.new('RGB', (700 + 20 + 700 + 20 + 480, 1000), 'white')
sh.paste(out.crop((330, 300, 690, 660)).resize((700, 700), Image.LANCZOS), (0, 0))
sh.paste(out.resize((700, 700), Image.LANCZOS), (720, 0))
sh.paste(out.crop((590, 340, 710, 650)).resize((387, 1000), Image.LANCZOS), (1440, 0)); sh.save('guide_hands_check.png')
