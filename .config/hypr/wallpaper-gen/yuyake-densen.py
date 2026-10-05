#!/usr/bin/env python3
# Fondo del rice: "夕焼け電線" — atardecer pixel art, anime de los 90, paleta Gruvbox.
# Se dibuja a 480x270 y se escala x4 (vecino más cercano) a 1920x1080.
import numpy as np, random, math, sys
from PIL import Image, ImageDraw, ImageFont

W, H = 480, 270
SEED = int(sys.argv[1]) if len(sys.argv) > 1 else 7
rng = random.Random(SEED)

def hx(s): s = s.lstrip('#'); return tuple(int(s[i:i+2], 16) for i in (0, 2, 4))

img = np.zeros((H, W, 3), np.uint8)

# Bayer 4x4 para el dithering ordenado
B4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16 + 1/32
def bayer(y, x): return B4[y % 4, x % 4]

def ramp_pick(cols, t, y, x):
    """t en [0,1] sobre la lista de colores, con dithering ordenado."""
    f = min(max(t, 0), 1) * (len(cols) - 1)
    i = int(f); fr = f - i
    if i < len(cols) - 1 and fr > bayer(y, x): i += 1
    return cols[i]

# ── Cielo ──────────────────────────────────────────────────────────────────
SKY = [hx(c) for c in ["#0d0b09", "#151009", "#1f150c", "#2c1a0d", "#40220e",
                       "#5e2c0f", "#83350d", "#a8420b", "#cf5a0d", "#f07a17", "#fe8019"]]
HORIZON = 196
for y in range(H):
    t = (y / HORIZON) ** 1.55
    for x in range(W):
        img[y, x] = ramp_pick(SKY, t, y, x)

# Estrellas arriba (pocas, chiquitas)
for _ in range(70):
    x, y = rng.randrange(W), rng.randrange(8, 70)
    img[y, x] = hx(rng.choice(["#665c54", "#7c6f64", "#a89984", "#d5c4a1"]))

# ── Sol con franjas retro ──────────────────────────────────────────────────
SUN = [hx(c) for c in ["#fbe08a", "#fbe08a", "#fabd2f", "#f7a325", "#fe8019", "#f07a17"]]
cx, cy, R = 262, 158, 66
for y in range(cy - R, cy + R):
    dy = y - cy
    # franjas: aparecen debajo del centro y se ensanchan hacia abajo
    if dy > -24:
        k = dy + 24
        period = 8
        gap = 1 + k * 3 // 40           # 1..4 px, más anchas hacia abajo
        if (k % period) < gap:
            half = int(math.sqrt(max(R * R - dy * dy, 0)))
            for x in range(cx - half, cx + half):
                if 0 <= x < W: img[y, x] = hx("#a8420b") if bayer(y, x) < 0.75 else hx("#83350d")
            continue
    half = int(math.sqrt(max(R * R - dy * dy, 0)))
    t = (y - (cy - R)) / (2 * R)
    for x in range(cx - half, cx + half):
        if 0 <= x < W and 0 <= y < H:
            img[y, x] = ramp_pick(SUN, t, y, x)

# Halo del sol: aclara un poco el cielo alrededor (anillo dithered)
for y in range(cy - R - 14, min(H, cy + R)):
    for x in range(cx - R - 14, cx + R + 14):
        d = math.hypot(x - cx, y - cy)
        if R < d < R + 12 and 0 <= x < W and 0 <= y < H:
            if (R + 12 - d) / 12 * 0.55 > bayer(y, x):
                c = img[y, x].astype(int)
                img[y, x] = np.clip(c + [26, 14, 2], 0, 255)

# ── Nubes largas, iluminadas desde abajo ───────────────────────────────────
def cloud(x0, y0, length, thick, body, rim):
    pts = []
    for i in range(rng.randint(4, 7)):
        pts.append((x0 + rng.randint(0, length), y0 + rng.randint(-thick // 2, 0),
                    rng.randint(length // 6, length // 3), rng.randint(2, thick)))
    for y in range(y0 - thick * 2, y0 + 2):
        for x in range(x0 - length // 3, x0 + length + length // 3):
            if not (0 <= x < W and 0 <= y < H): continue
            inside = any(((x - px) / rx) ** 2 + ((y - py) / ry) ** 2 <= 1 for px, py, rx, ry in pts)
            if inside and y <= y0:
                below = not any(((x - px) / rx) ** 2 + ((y + 1 - py) / ry) ** 2 <= 1 for px, py, rx, ry in pts) or y == y0
                img[y, x] = rim if below else body

cloud(150, 118, 120, 7, hx("#5e2c0f"), hx("#d65d0e"))
cloud(300, 132, 150, 6, hx("#6b300e"), hx("#f07a17"))
cloud(40, 92, 110, 6, hx("#40220e"), hx("#a8420b"))
cloud(360, 84, 90, 5, hx("#40220e"), hx("#a8420b"))
cloud(210, 172, 170, 5, hx("#83350d"), hx("#fabd2f"))

# ── Ciudad en capas ────────────────────────────────────────────────────────
def skyline(base, hmin, hmax, wmin, wmax, color, wins, density, start=0):
    x = start - rng.randint(0, 10)
    while x < W:
        bw = rng.randint(wmin, wmax); bh = rng.randint(hmin, hmax)
        top = base - bh
        img[max(top, 0):base, max(x, 0):min(x + bw, W)] = color
        # detalles de techo: antena o tanque de agua
        r = rng.random()
        if r < 0.25 and bw > 6:
            ax = x + rng.randint(2, bw - 3)
            if 0 <= ax < W: img[max(top - rng.randint(4, 10), 0):top, ax] = color
        elif r < 0.4 and bw > 10:
            tx = x + rng.randint(1, bw - 7)
            img[max(top - 4, 0):top, max(tx, 0):min(tx + 5, W)] = color
        # ventanas (grilla de 1px, algunas encendidas)
        for wy in range(top + 3, base - 2, 3):
            for wx in range(x + 2, x + bw - 2, 3):
                if 0 <= wx < W and rng.random() < density:
                    img[wy, wx] = hx(rng.choice(wins))
        x += bw + rng.randint(0, 3)

skyline(206, 10, 34, 8, 20, hx("#40220e"), ["#83350d", "#a8420b"], 0.18)
skyline(214, 14, 48, 10, 24, hx("#24170d"), ["#cf5a0d", "#d79921", "#fe8019"], 0.22)

# Bruma sobre el horizonte (franja dithered que separa capas)
for y in range(196, 216):
    for x in range(W):
        a = 0.28 * (1 - abs(y - 206) / 10)
        if a > bayer(y, x):
            c = img[y, x].astype(int); img[y, x] = np.clip(c + [30, 12, 0], 0, 255)

# Base de la ciudad debajo de la vía (techos bajos, carteles chiquitos)
img[214:244, :] = hx("#1a120b")
for _ in range(90):
    x, y = rng.randrange(W), rng.randrange(217, 242)
    img[y, x:x + rng.choice([1, 1, 2])] = hx(rng.choice(["#83350d", "#d65d0e", "#fabd2f", "#a8420b"]))

# Vía elevada del tren + tren con ventanas encendidas
TRACK = 222
img[TRACK:TRACK + 3, :] = hx("#140e09")
for px in range(4, W, 26):                      # pilares
    img[TRACK + 3:H, px:px + 3] = hx("#140e09")
tx0, cars = 40, 5
for c in range(cars):
    x0 = tx0 + c * 46
    img[TRACK - 12:TRACK, x0:x0 + 43] = hx("#1d140c")
    img[TRACK - 12, x0 + 1:x0 + 42] = hx("#3c2a18")              # techo con brillo
    for wx in range(x0 + 4, x0 + 40, 6):
        img[TRACK - 9:TRACK - 5, wx:wx + 4] = hx("#fabd2f")
        img[TRACK - 9, wx:wx + 4] = hx("#fbe08a")
    img[TRACK - 3, x0:x0 + 43] = hx("#d65d0e")                     # franja del vagón
# luz del tren reflejada en la vía
img[TRACK, tx0:tx0 + cars * 46] = hx("#3c2a18")
# pantógrafo
img[TRACK - 16:TRACK - 12, tx0 + 20] = hx("#1d140c")
img[TRACK - 16, tx0 + 16:tx0 + 25] = hx("#1d140c")

# Capa cercana, casi negra, más alta en los costados
def near(x0, x1, top):
    img[top:H, x0:x1] = hx("#0d0b09")
for x0, x1, top in [(0, 30, 150), (30, 62, 176), (62, 84, 196), (84, 120, 218),
                    (380, 404, 206), (404, 432, 168), (432, 456, 186), (456, 480, 140)]:
    near(x0, x1, top)
    for wy in range(top + 4, H - 4, 4):
        for wx in range(x0 + 3, x1 - 3, 4):
            if rng.random() < 0.12:
                img[wy:wy + 2, wx:wx + 2] = hx(rng.choice(["#d65d0e", "#fabd2f", "#83350d"]))
img[244:H, :] = hx("#0d0b09")      # suelo / azotea

# Cartel vertical de neón (se escribe con la fuente CJK más abajo)
SIGN = (412, 74, 20, 92)           # x, y, ancho, alto
sx, sy, sw, sh = SIGN
img[sy:sy + sh, sx:sx + sw] = hx("#1a0f08")
img[sy, sx:sx + sw] = hx("#fe8019"); img[sy + sh - 1, sx:sx + sw] = hx("#fe8019")
img[sy:sy + sh, sx] = hx("#fe8019"); img[sy:sy + sh, sx + sw - 1] = hx("#fe8019")
img[sy + sh:sy + sh + 8, sx + 9:sx + 11] = hx("#0d0b09")           # soporte

# ── Postes y cables (primer plano) ─────────────────────────────────────────
POLE = hx("#070605")
def pole(x, top, cross):
    img[top:H, x:x + 4] = POLE
    for cy_, half in cross:
        img[cy_:cy_ + 2, x - half:x + 4 + half] = POLE
        for ix in (x - half, x + 3 + half):               # aisladores
            img[cy_ - 2:cy_, ix:ix + 1] = POLE
    img[top + 40:top + 52, x - 4:x] = POLE               # transformador
    img[top + 52, x - 3:x - 1] = POLE

pole(92, 18, [(30, 16), (44, 12)])
pole(372, 36, [(48, 14), (62, 10)])

def wire(x0, y0, x1, y1, sag):
    n = abs(x1 - x0) * 2
    prev = None
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t + sag * 4 * t * (1 - t)
        p = (int(round(x)), int(round(y)))
        if p != prev and 0 <= p[0] < W and 0 <= p[1] < H:
            img[p[1], p[0]] = POLE
        prev = p

L, Rr = (92, 18), (372, 36)
for (ly, lx), (ry, rx), sag in [((28, 76), (46, 358), 34), ((28, 112), (46, 390), 30),
                                ((42, 80), (60, 362), 38), ((42, 108), (60, 386), 34),
                                ((36, 96), (54, 375), 46)]:
    wire(lx, ly, rx, ry, sag)
# cables que salen de cuadro
wire(76, 28, -10, 60, 18); wire(80, 42, -10, 88, 14)
wire(390, 46, 490, 30, 10); wire(386, 60, 490, 70, 12)
# cuervo en un cable
cx_, cy_ = 230, 0
for x in range(W):
    pass
crow = ["..##..", ".####.", "######", ".#..#."]
bx, by = 197, 66
for j, row in enumerate(crow):
    for i, ch in enumerate(row):
        if ch == "#": img[by + j, bx + i] = POLE

# ── Texto: kanji del cartel y firma HUD ────────────────────────────────────
pil = Image.fromarray(img)
d = ImageDraw.Draw(pil)
cjk = ImageFont.truetype("/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc", 14, index=0)
d.fontmode = "1"                                           # sin suavizado: pixel puro
for i, ch in enumerate("夕焼電線"):
    d.text((sx + 3, sy + 4 + i * 21), ch, font=cjk, fill=hx("#fabd2f"))
mono = ImageFont.truetype("/usr/share/fonts/OTF/DepartureMonoNerdFont-Regular.otf", 11)
d.text((12, 252), "SYS.CRT // 1997", font=mono, fill=hx("#504945"))
d.text((W - 98, 252), "夕焼け", font=cjk, fill=hx("#3c2a18"))

pil = pil.resize((W * 4, H * 4), Image.NEAREST)
pil.save(sys.argv[2] if len(sys.argv) > 2 else "out.png")
