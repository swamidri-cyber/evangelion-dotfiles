#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  Prepara el logo del rice (original.png, fondo negro) para usarlo encima de
#  ventanas translúcidas: el negro pasa a ser transparencia y el resplandor se
#  conserva (alfa = brillo, color "despremultiplicado"). Recorta el sobrante.
#    logo.png       → para el lanzador (el ruido animado lo pone Quickshell)
#    logo-term.png  → para fastfetch en kitty, con el ruido del fondo "horneado"
#  Necesita numpy y Pillow.
# ─────────────────────────────────────────────────────────────────────────────
import os, numpy as np
from PIL import Image
D = os.path.dirname(os.path.abspath(__file__))
im = np.asarray(Image.open(os.path.join(D, "original.png")).convert("RGB")).astype(np.float32) / 255
# el negro del original no es 0 puro: se resta un piso para que quede limpio
a = np.clip((im.max(axis=2) - 0.035) / 0.965, 0, 1)
rgb = np.where(a[..., None] > 1e-3, np.clip(im / np.maximum(a[..., None], 1e-3), 0, 1), 0)
# Halo más suave: se conserva el resplandor original PEGADO a las letras (el
# filo naranja) y se apaga a medida que se aleja. HALO_PX = hasta dónde llega.
from PIL import ImageFilter
HALO_PX = 10
core = np.clip((im.mean(axis=2) - 0.45) / 0.25, 0, 1)                 # 1 en las letras
cm = Image.fromarray((core * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
near = np.asarray(cm.filter(ImageFilter.GaussianBlur(HALO_PX))).astype(np.float32) / 255
a = np.maximum(core, a * np.clip(near * 2.2, 0, 1))
rgba = np.dstack([rgb, a])
ys, xs = np.where(a > 0.02)
pad = 12
y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad, a.shape[0])
x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad, a.shape[1])
rgba = rgba[y0:y1, x0:x1]
Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(D, "logo.png"))
# Versión terminal: igual al logo (el ruido lo pone la capa global rice-noise)
t = rgba
Image.fromarray((t * 255).astype(np.uint8), "RGBA").save(os.path.join(D, "logo-term.png"))
print(rgba.shape)
