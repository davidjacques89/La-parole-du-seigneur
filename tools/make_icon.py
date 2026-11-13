"""Draws the praying-hands icon and writes it as a 64x64 32-bit TGA for the game.

    python3 tools/make_icon.py

Output: WordsOfTheLord/Media/PrayingHands.tga (plus a PNG preview next to this script's output dir if asked).
The drawing is original: simple shapes, gold on a transparent background.
"""
import struct, sys
from PIL import Image, ImageDraw

S = 8                     # supersampling
N = 64 * S                # canvas size while drawing
GOLD = (244, 213, 124, 255)
GOLD_SHADE = (212, 168, 72, 255)
OUTLINE = (92, 62, 18, 255)
CUFF = (250, 240, 214, 255)

def bez(p0, p1, p2, p3, steps=40):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = (1 - t) ** 3; b = 3 * (1 - t) ** 2 * t; c = 3 * (1 - t) * t ** 2; d = t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts

def sc(points):
    return [(x * N / 64, y * N / 64) for x, y in points]

img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
LW = int(1.5 * S)

def U(v):
    return v * N / 64

def poly(points, fill, outline=True, width=LW):
    pts = [(U(x), U(y)) for x, y in points]
    d.polygon(pts, fill=fill)
    if outline:
        d.line(pts + [pts[0]], fill=OUTLINE, width=width, joint="curve")

def curve(*segments):
    pts = []
    for seg in segments:
        pts += bez(*seg)
    return pts

# Back hand (the far one, darker): a tall shape ending in joined fingertips.
back = curve(((26, 52), (22, 36), (28, 17), (35, 4)), ((35, 4), (41, 18), (45, 36), (42, 52)))
poly(back, GOLD_SHADE)

# Front hand (lighter), a little to the left and lower.
front = curve(((22, 52), (17, 36), (23, 19), (31, 8)), ((31, 8), (37, 19), (40, 36), (37, 52)))
poly(front, GOLD)

# Fingers: three separations running up the front hand toward the tips.
for pts in [[(28.5, 15), (27.5, 31)], [(31.5, 13), (31.5, 31)], [(34.5, 16), (35.2, 31)]]:
    d.line([(U(x), U(y)) for x, y in pts], fill=OUTLINE, width=int(1.1 * S))

# Thumb: a lobe on the near edge.
thumb = curve(((20, 47), (16, 40), (19, 31), (25, 29)), ((25, 29), (28, 34), (27, 41), (25, 47)))
poly(thumb, GOLD)

# Sleeves
poly([(20, 51), (39, 51), (43, 61), (15, 61)], CUFF)
d.line([(U(17.5), U(56)), (U(40.5), U(56))], fill=GOLD_SHADE, width=int(1.1 * S))

# Tilt the pair, the way the pose is usually drawn, and re-center.
img = img.rotate(-12, resample=Image.BICUBIC, center=(U(31), U(52)))
shift = Image.new("RGBA", (N, N), (0, 0, 0, 0))
shift.paste(img, (int(U(1)), int(U(1))))
img = shift

icon = img.resize((64, 64), Image.LANCZOS)

# A soft dark halo behind the shape keeps it readable against the minimap's bright background.
halo = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
alpha = icon.split()[3]
from PIL import ImageFilter
glow = alpha.filter(ImageFilter.GaussianBlur(1.6)).point(lambda v: int(v * 0.55))
halo.putalpha(glow)
out = Image.alpha_composite(halo, icon)

def write_tga(path, image):
    w, h = image.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8 | 0x20)
    px = bytearray()
    for r, g, b, a in image.convert('RGBA').tobytes() and zip(*[iter(image.convert('RGBA').tobytes())] * 4):
        px += bytes((b, g, r, a))
    with open(path, "wb") as f:
        f.write(header + bytes(px))

dest = sys.argv[1] if len(sys.argv) > 1 else "WordsOfTheLord/Media/PrayingHands.tga"
write_tga(dest, out)
if len(sys.argv) > 2:
    big = Image.new("RGBA", (256, 256), (70, 90, 120, 255))
    big.alpha_composite(out.resize((256, 256), Image.NEAREST))
    big.save(sys.argv[2])
print("wrote", dest)
