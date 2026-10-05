#!/usr/bin/env python3
# Genera grain.png: grano fuerte (claro y oscuro) para los subtítulos.
# Sin dependencias. Uso: python3 make-grain.py
import os, random, struct, zlib
S = 256
random.seed(7)
rows = bytearray()
for y in range(S):
    rows.append(0)
    for x in range(S):
        r = random.random()
        if r < 0.42:   rows += bytes((13, 11, 9, random.randint(40, 170)))     # grano oscuro
        elif r < 0.70: rows += bytes((255, 240, 208, random.randint(20, 110)))  # grano claro
        else:          rows += bytes((0, 0, 0, 0))
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "grain.png"), "wb").write(png)
