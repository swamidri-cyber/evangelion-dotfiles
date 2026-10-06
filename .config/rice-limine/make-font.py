#!/usr/bin/env python3
# Convierte Departure Mono en una fuente de mapa de bits 8x16 (code page 437,
# 256 glifos, 1 byte por fila) para Limine (term_font). Usa ImageMagick.
#   python3 make-font.py  → departure-8x16.f16
import subprocess, sys
#   python3 make-font.py <fuente> <tamaño> <base> <salida>  → otra fuente
FONT = "/usr/share/fonts/OTF/DepartureMonoNerdFontMono-Regular.otf"
SIZE, BASE = 11, 12          # Departure Mono es nítida a 11 px; línea base en la fila 12
OUT = "departure-8x16.f16"
if len(sys.argv) == 5:
    FONT, SIZE, BASE, OUT = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
out = bytearray()
chars = bytes(range(256)).decode("cp437")
for i, ch in enumerate(chars):
    if i < 32 or i == 127 or ch.isspace():
        out += bytes(16); continue
    txt = ch.replace("\\", "\\\\").replace("'", "\\'").replace("%", "%%").replace("@", "\\@")
    raw = subprocess.run(["magick", "-size", "8x16", "xc:black", "-font", FONT, "-pointsize", str(SIZE),
                          "+antialias", "-fill", "white", "-annotate", f"+1+{BASE}", txt,
                          "-threshold", "50%", "-depth", "8", "gray:-"], capture_output=True).stdout
    if len(raw) != 128:
        out += bytes(16); continue
    for y in range(16):
        b = 0
        for x in range(8):
            if raw[y * 8 + x] > 127: b |= 0x80 >> x
        out.append(b)
open(OUT, "wb").write(out)
print("ok", len(out))
