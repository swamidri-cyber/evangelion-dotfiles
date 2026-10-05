#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  Paso 2 del fondo "被験体07": convierte el dibujo plano en una imagen de
#  monitor viejo / cámara: figura quemada a blanco, brillo ámbar (bloom),
#  ojo de pez, aberración cromática, viñeta y grano de película.
#  Uso: post.py face.png salida.png [semilla]
#  Necesita numpy y Pillow.
# ─────────────────────────────────────────────────────────────────────────────
import sys, numpy as np
from PIL import Image, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
rng = np.random.default_rng(int(sys.argv[3]) if len(sys.argv) > 3 else 7)
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255
H, W, _ = im.shape

orig = im.copy()
# 1) Sobreexposición: lo claro se quema a blanco cálido, la línea queda negra
lum = im.mean(axis=2, keepdims=True)
burn = np.clip((lum - 0.12) * 1.6, 0, 1)
warm_white = np.array([1.0, 0.95, 0.86])
im = np.where(lum > 0.45, burn * warm_white, im * 0.9)

# 2) Bloom: varias capas desenfocadas de lo brillante, del dorado al rojo
def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
                      .filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255
bright = np.clip((im - 0.55) / 0.45, 0, 1)
bloom = (blur(bright, 12) * [1.0, 0.75, 0.40] * 0.55 +
         blur(bright, 45) * [1.0, 0.45, 0.12] * 0.70 +
         blur(bright, 140) * [0.85, 0.22, 0.06] * 0.95)
im = 1 - (1 - im) * (1 - np.clip(bloom, 0, 1))          # mezcla "screen"

# La tinta del dibujo (líneas negras dentro de la figura) se recupera para que
# el brillo no la borre: queda marrón muy oscuro, como línea quemada.
olum = orig.mean(axis=2)
figure = blur((olum > 0.3).astype(np.float32)[..., None].repeat(3, 2), 6)[..., 0] > 0.05
ink = ((olum < 0.25) & figure).astype(np.float32)
ink = blur(ink[..., None].repeat(3, 2), 0.8)[..., :1]
im = im * (1 - ink * 0.82) + ink * np.array([0.10, 0.04, 0.02])

# El cuerpo se apaga hacia abajo: la cara manda
fade = np.clip(1 - (np.arange(H, dtype=np.float32) - 860) / 260, 0.25, 1)[:, None, None]
im = im * fade

# 3) Ojo de pez + aberración cromática (cada canal con su propia lente)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
cx, cy = W / 2, H / 2 + 20
u, v = (xx - cx) / (H / 2), (yy - cy) / (H / 2)
r2 = u * u + v * v
def sample(ch, s):
    k = 0.30
    f = s * (0.74 + k * r2 * 0.75)          # centro ampliado, bordes comprimidos
    sx = np.clip(cx + u * f * (H / 2), 0, W - 1.001)
    sy = np.clip(cy + v * f * (H / 2), 0, H - 1.001)
    x0, y0 = sx.astype(int), sy.astype(int)
    fx, fy = sx - x0, sy - y0
    c = im[..., ch]
    return (c[y0, x0] * (1 - fx) * (1 - fy) + c[y0, x0 + 1] * fx * (1 - fy) +
            c[y0 + 1, x0] * (1 - fx) * fy + c[y0 + 1, x0 + 1] * fx * fy)
im = np.stack([sample(0, 1.006), sample(1, 1.0), sample(2, 0.993)], axis=2)

# 4) Viñeta redonda fuerte (como mirar por un tubo)
vig = np.clip(1.25 - 0.55 * np.sqrt(r2) ** 1.6, 0, 1)[..., None]
im *= vig

# 5) Suavizado leve + grano de película (monocromo con un toque de color)
im = blur(im, 1.2)
grain = rng.normal(0, 0.045, (H, W, 1)) + rng.normal(0, 0.012, (H, W, 3))
im = im + grain * (0.35 + 0.65 * im)
im = np.clip(im, 0, 1)

# 6) Negros levemente cálidos (no negro puro digital)
im = im * 0.97 + np.array([0.018, 0.010, 0.005])
Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8)).save(dst)
print("ok", dst)
