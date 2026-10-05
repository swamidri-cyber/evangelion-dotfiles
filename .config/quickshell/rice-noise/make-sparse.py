#!/usr/bin/env python3
# Genera noise-sparse.png: ruido ESPACIADO para apps y logo — la mayoría de los
# píxeles transparentes y unos pocos granos sueltos (claros y oscuros), así se
# sigue viendo lo de atrás. DENSITY = fracción de píxeles con grano.
import os, random, struct, zlib
S, DENSITY = 256, 0.07
random.seed(11)
rows = bytearray()
for y in range(S):
    rows.append(0)
    for x in range(S):
        if random.random() < DENSITY:
            v = random.choice((random.randint(190, 255), random.randint(0, 40)))
            rows += bytes((v, v, v, 255))
        else:
            rows += bytes((0, 0, 0, 0))
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "noise-sparse.png"), "wb").write(png)
