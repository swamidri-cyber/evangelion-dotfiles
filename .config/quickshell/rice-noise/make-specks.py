#!/usr/bin/env python3
# Genera specks.png: ruido de PUNTITOS CLAROS (como el grano de la captura de
# inspiración). Solo suma luz: sobre lo oscuro casi no se ve, sobre lo claro
# brilla un poco. El resto es transparente. DENSITY = fracción con puntito.
# Uso: make-specks.py [densidad] [archivo]   (por defecto 0.09 specks.png = fondo)
#      make-specks.py 0.04 specks-apps.png   → la de adentro de las apps (más espaciada)
import os, random, struct, sys, zlib
S = 256
DENSITY = float(sys.argv[1]) if len(sys.argv) > 1 else 0.09
NAME = sys.argv[2] if len(sys.argv) > 2 else "specks.png"
random.seed(21)
rows = bytearray()
for y in range(S):
    rows.append(0)
    for x in range(S):
        if random.random() < DENSITY:
            rows += bytes((255, 244, 222, random.randint(90, 255)))   # crema muy claro
        else:
            rows += bytes((0, 0, 0, 0))
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), NAME), "wb").write(png)
