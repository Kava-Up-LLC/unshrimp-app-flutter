"""Vector closed fist of the exercise character, traced from the doorway-chest-stretch pose.

Local frame: origin at the fist center, x right, y down, knuckles on top, fingers to the viewer,
forearm entering from the lower left (mirror=True: lower right). Units = pixels of the 1024 master.
"""
import math
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SKIN = (255, 205, 170); SHADE = (241, 150, 112); LINE = (38, 30, 34)

OUTLINE = [(-27, -12), (-23, -14.5), (-13, -17), (-5, -21), (2, -22.5), (7, -22.6), (12, -21), (17, -22.6), (21, -22),
           (24.5, -18), (26, -10), (27, -1), (29, 5), (30.5, 9.5), (29, 14), (23, 19), (15, 23), (8, 24), (3.5, 21.5),
           (1, 20), (-3, 21), (-8, 19.5), (-12, 17), (-15, 13.5), (-19, 9), (-22.5, 4), (-24.5, -2), (-27, -7)]
SHADING = [(-14, 9.5), (-8.5, 9), (5, 9), (17, 9), (18, 10.5), (8, 16), (3, 20), (-3, 20.5), (-8, 19), (-12, 16)]
FINGERS = [[(-8.5, -4), (-8.3, 9), (-11, 16)], [(3, -7.5), (5, 9), (1.5, 18.5)], [(14.5, -12.5), (17, 9)]]
THUMB = [(17, 9), (19, 10.5), (7.5, 16.5)]
HEEL = [(-24.5, -2), (-22.5, 4), (-19, 9), (-14, 14.5)]
FOREARM = (-30, 16)                               # where the forearm axis meets the fist


def frame(center, angle=0, scale=1.0, mirror=False):
    """Local -> canvas. angle is clockwise in degrees."""
    t = math.radians(angle); c, s = math.cos(t), math.sin(t); m = -1 if mirror else 1
    return lambda p: (center[0] + scale * (m * p[0] * c - p[1] * s), center[1] + scale * (m * p[0] * s + p[1] * c))


def spline(pts, closed, n=10):
    """Catmull-Rom through pts."""
    k = len(pts); out = []
    rng = range(k) if closed else range(k - 1)
    for i in rng:
        if closed: p0, p1, p2, p3 = pts[(i - 1) % k], pts[i], pts[(i + 1) % k], pts[(i + 2) % k]
        else: p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, k - 1)]
        for j in range(n):
            t = j / n
            out.append(tuple(0.5 * ((2 * p1[a]) + (-p0[a] + p2[a]) * t + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t * t
                                    + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t ** 3) for a in (0, 1)))
    if not closed: out.append(pts[-1])
    return out


def _mask(size, S, fn):
    m = Image.new('L', (size[0] * S, size[1] * S), 0); fn(ImageDraw.Draw(m))
    return m.resize(size, Image.LANCZOS)


def silhouette(size, F, S=4):
    pts = [F(p) for p in spline(OUTLINE, True)]
    return _mask(size, S, lambda d: d.polygon([(x * S, y * S) for x, y in pts], fill=255))


def details(canvas, F, scale=1.0, S=4, heel=True, sil=None):
    """Shading and inner lines; call after the silhouette has been outlined and filled."""
    size = canvas.size
    def poly(pts, color):
        q = [F(p) for p in pts]
        m = _mask(size, S, lambda d: d.polygon([(x * S, y * S) for x, y in q], fill=255))
        if sil is not None: m = ImageChops.darker(m, sil)
        canvas.paste(Image.new('RGB', size, color), (0, 0), m)
    def stroke(pts, w):
        q = [(x * S, y * S) for x, y in (F(p) for p in spline(pts, False))]; r = w * scale * S / 2
        def fn(d):
            d.line(q, fill=255, width=max(1, int(round(2 * r))), joint='curve')
            for x, y in (q[0], q[-1]): d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        canvas.paste(Image.new('RGB', size, LINE), (0, 0), _mask(size, S, fn))
    poly(SHADING, SHADE)
    for f in FINGERS: stroke(f, 2.6)
    stroke(THUMB, 3.4)
    if heel: stroke(HEEL, 2.8)
