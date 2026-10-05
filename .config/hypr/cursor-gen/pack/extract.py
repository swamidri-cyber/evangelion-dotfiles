#!/usr/bin/env python3
# Convierte pack.png (pack de cursores pixel art, fondo blanco) en grillas de
# texto: X = borde oscuro, o = relleno crema, . = transparente. Escribe grids.json
#
# 1) Mide la grilla de píxeles del dibujo (período y fase) con los bordes de la
#    imagen: sale ~8,56 px por píxel (el pack mide 140x74 píxeles).
# 2) Lee el centro de cada celda y la clasifica por brillo.
# 3) Corta los íconos: franjas separadas por filas vacías, y dentro de cada
#    franja, columnas vacías (3 o más seguidas).
# Necesita numpy + Pillow.  Uso: python3 extract.py
import json, os, numpy as np
from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
a = np.asarray(Image.open(os.path.join(D, "pack.png")).convert("L")).astype(float)
H, W = a.shape

def fit(edges):
    """Período y fase de una grilla a partir de la cantidad de bordes por posición."""
    xs = np.arange(len(edges)); best = None
    for p in np.arange(8.40, 8.70, 0.001):
        s = (edges * np.exp(2j * np.pi * xs / p)).sum()
        cand = (abs(s), p, (np.angle(s) / (2 * np.pi) * p) % p)
        if best is None or cand > best: best = cand
    return best[1], best[2] + 0.5          # diff[i] es el borde entre i e i+1

px, ox = fit((np.abs(np.diff(a, axis=1)) > 60).sum(0).astype(float))
py, oy = fit((np.abs(np.diff(a, axis=0)) > 60).sum(1).astype(float))

cells = []
for j in range(-1, int((H - oy) / py)):
    row = ""
    for i in range(-1, int((W - ox) / px)):
        x0, y0 = ox + i * px, oy + j * py
        c = a[max(int(y0 + py * .3), 0):int(y0 + py * .7) + 1,
              max(int(x0 + px * .3), 0):int(x0 + px * .7) + 1]
        m = c.mean() if c.size else 255
        row += "X" if m < 120 else ("." if m > 250 else "o")
    cells.append(row)

def clean(g):
    """El relleno siempre está rodeado de borde: un 'o' que toca vacío es un
    resto del suavizado de la imagen, no parte del dibujo."""
    g = [list(r) for r in g]; changed = True
    while changed:
        changed = False
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] != "o": continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if not (0 <= yy < len(g) and 0 <= xx < len(g[0])) or g[yy][xx] == ".":
                        g[y][x] = "."; changed = True; break
    return ["".join(r) for r in g]

def runs(blank):
    """Tramos no vacíos separados por al menos 3 posiciones vacías."""
    out, start, gap = [], None, 0
    for i, b in enumerate(blank + [True] * 3):
        if not b:
            if start is None: start = i
            gap = 0; end = i
        elif start is not None:
            gap += 1
            if gap >= 3: out.append((start, end)); start = None
    return out

NAMES = [  # en orden de lectura
    "arrow_rings", "arrow_click", "triangle", "hand_rings", "hand_click", "hand_dots",
    "hg0", "hg1", "hg2", "hg3", "zoom_in", "zoom_out", "move",
    "nodrop", "arrow_wait", "tri_dark", "arrow_dark", "forbid", "burst", "move_dots",
]
icons = []
for r0, r1 in runs([set(r) == {"."} for r in cells]):
    band = cells[r0:r1 + 1]
    for c0, c1 in runs([all(r[i] == "." for r in band) for i in range(len(band[0]))]):
        g = [r[c0:c1 + 1] for r in band]
        while set(g[0]) == {"."}: g = g[1:]
        while set(g[-1]) == {"."}: g = g[:-1]
        icons.append(clean(g))
assert len(icons) == len(NAMES), f"esperaba {len(NAMES)} íconos, salieron {len(icons)}"
out = dict(zip(NAMES, icons))
json.dump(out, open(os.path.join(D, "grids.json"), "w"), indent=1)
print(f"grilla {px:.3f} x {py:.3f} px, {len(icons)} íconos → grids.json")
