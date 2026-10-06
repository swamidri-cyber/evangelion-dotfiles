# Simula el menú de Limine con cada fuente candidata (escala 2x, resaltado sutil)
#   python3 preview-font.py → fonts/comparar.png   (sin dependencias: usa ImageMagick)
import subprocess
FONTS = [("A  DEPARTURE MONO (actual)", "fonts/departure.f16"), ("B  VGA CLASICA", "fonts/vga.f16"),
         ("C  NOTO SANS MONO", "fonts/noto.f16"), ("D  DEJAVU SANS MONO", "fonts/dejavu.f16")]
SC, TW, TH = 2, 800, 460
FG, SEL_BG, SEL_FG, DIM = (0xff, 0xb3, 0x47), (0x3a, 0x1a, 0x08), (0xff, 0xd9, 0xa0), (0x7c, 0x4a, 0x1c)
crop = subprocess.run(["magick", "limine-wallpaper.png", "-crop", "800x420+560+330", "+repage", "-depth", "8", "rgb:-"], capture_output=True).stdout
lab_font = open("fonts/departure.f16", "rb").read()
def put(buf, x, y, col): i = (y * TW + x) * 3; buf[i:i + 3] = bytes(col)
def rect(buf, x0, y0, x1, y1, col):
    for y in range(y0, y1):
        for x in range(x0, x1): put(buf, x, y, col)
def text(buf, f, x, y, s, col, back=None):
    if back: rect(buf, x, y, x + len(s) * 8 * SC, y + 16 * SC, back)
    for i, ch in enumerate(s):
        c = ch.encode("cp437")[0]
        for r in range(16):
            b = f[c * 16 + r]
            for k in range(8):
                if b & (0x80 >> k):
                    for dy in range(SC):
                        for dx in range(SC): put(buf, x + (i * 8 + k) * SC + dx, y + r * SC + dy, col)
names = []
for n, (name, path) in enumerate(FONTS):
    f = open(path, "rb").read()
    buf = bytearray(TW * TH * 3); rect(buf, 0, 0, TW, 40, (12, 6, 3))
    buf[40 * TW * 3:] = crop
    text(buf, lab_font, 12, 4, name, SEL_FG)
    y = 190
    for s, sel in [("  LINUX  ", True), ("  WINDOWS  ", False), ("[+] - avanzado -", False)]:
        text(buf, f, 400 - len(s) * 8 * SC // 2, y, s, SEL_FG if sel else FG, SEL_BG if sel else None); y += 16 * SC
    for s, yy, col in [("ARRANCAR CACHYOS", 330, FG), ("Booting automatically in 5...", 362, DIM)]:
        text(buf, f, 400 - len(s) * 8 * SC // 2, yy, s, col)
    p = f"fonts/t{n}.rgb"; open(p, "wb").write(buf); names.append(p)
subprocess.run(["magick", "montage"] + [f"-size", f"{TW}x{TH}", "-depth", "8"] + [f"rgb:{p}" for p in names] +
               ["-tile", "2x", "-geometry", "+6+6", "-background", "black", "fonts/comparar.png"], check=True)
print("ok")
