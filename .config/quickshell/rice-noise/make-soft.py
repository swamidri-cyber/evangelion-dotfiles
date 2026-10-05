#!/usr/bin/env python3
# Genera noise-soft.png: ruido BLANDO para apps y logo. Granos desenfocados
# (sin bordes filosos) en crema y marrón cálido en vez de blanco/negro puro,
# casi todo transparente. Se repite como mosaico (los bordes empalman).
# Necesita numpy y Pillow.
import os, numpy as np
from PIL import Image, ImageFilter
S = 256
rng = np.random.default_rng(5)
n = rng.normal(0, 1, (S, S)).astype(np.float32)
# desenfoque que empalma en los bordes: se repite 3x3, se desenfoca y se recorta el centro
big = np.tile(n, (3, 3))
img = Image.fromarray(((big - big.min()) / (big.max() - big.min()) * 255).astype(np.uint8))
big = np.asarray(img.filter(ImageFilter.GaussianBlur(1.1))).astype(np.float32) / 255
n = big[S:2 * S, S:2 * S]
n = (n - n.mean()) / n.std()                       # centrado en 0
pos, neg = np.clip(n - 0.9, 0, None), np.clip(-n - 0.9, 0, None)   # solo los extremos → espaciado
a = np.clip((pos + neg) * 0.9, 0, 1)
cream, dark = np.array([235, 219, 178]), np.array([40, 26, 16])
rgb = np.where((pos > neg)[..., None], cream, dark)
out = np.dstack([rgb, a * 255]).astype(np.uint8)
Image.fromarray(out, "RGBA").save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "noise-soft.png"))
print("cobertura media", round(float(a.mean()), 3))
