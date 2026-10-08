"""Mountain pose: paste only the model's open hands (below the wrist) onto the straight master arms."""
import sys
import numpy as np
from PIL import Image, ImageFilter

BG = np.array([240, 254, 249.])
base = np.asarray(Image.open('guide_hands.png').convert('RGB')).astype(float)
g = np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(float)
y0 = int(sys.argv[2]) if len(sys.argv) > 2 else 528
H, W = base.shape[:2]; yy, xx = np.mgrid[0:H, 0:W]
R, G, B = g[..., 0], g[..., 1], g[..., 2]
skin = (R > 200) & (R - B > 60)
bs = (base[..., 0] > 200) & (base[..., 0] - base[..., 2] > 60) & (base[..., 1] > 195) & (yy > 400) & (yy < 520)
gs = skin & (G > 180) & (yy > 400) & (yy < 520)
o = g.copy()
w = np.clip((G - 157) / 30, 0, 1)[..., None]
o[skin] = (g + w * (np.median(base[bs], axis=0) - np.median(g[gs], axis=0)))[skin]
o[np.abs(g - np.median(g[:40].reshape(-1, 3), axis=0)).sum(2) < 16] = BG
brown = (R > B + 20) & (R >= G) & ~skin
k = (np.clip((165 - R) / 55, 0, 1) * brown)[..., None]
o = o * (1 - 0.55 * k)
m = np.zeros((H, W))
for cx in (637, 1022 - 637):
    m[(np.abs(xx - cx) <= 27) & (yy >= y0) & (yy <= 640)] = 1
navy = (base[..., 2] > 60) & (base[..., 0] < 70) & (base[..., 1] < 80)               # trousers stay
m[np.asarray(Image.fromarray((navy * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0] = 0
m = np.asarray(Image.fromarray((m * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.5))).astype(float)[..., None] / 255
out = Image.fromarray(np.clip(base * (1 - m) + o * m, 0, 255).astype('uint8')); out.save('hands_final.png')
raw = Image.fromarray(g.astype('uint8'))
sh = Image.new('RGB', (400 * 4 + 60 + 512, 560), 'white')
for i, (im, box) in enumerate(((raw, (337, 490, 437, 630)), (raw, (587, 490, 687, 630)), (out, (337, 490, 437, 630)), (out, (587, 490, 687, 630)))):
    sh.paste(im.crop(box).resize((400, 560), Image.LANCZOS), (420 * i, 0))
sh.paste(out.resize((512, 512), Image.LANCZOS), (1680, 0)); sh.save('hands_check.png')
