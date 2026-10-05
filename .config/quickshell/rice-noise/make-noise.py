#!/usr/bin/env python3
# Genera noise.png: ruido blanco (gris al azar, opaco) para el fondo.
# La transparencia la pone shell.qml (perilla STRENGTH). Sin dependencias.
import os, random, struct, zlib
S = 256
random.seed(3)
rows = bytearray()
for y in range(S):
    rows.append(0)
    for x in range(S):
        v = random.randint(0, 255)
        rows += bytes((v, v, v, 255))
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "noise.png"), "wb").write(png)
