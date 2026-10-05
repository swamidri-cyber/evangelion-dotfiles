#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  Generador del cursor "Rice-CRT": pixel art estilo monitor de los 90, relleno
#  ámbar con brillo dorado y borde oscuro (paleta Gruvbox del rice).
#
#  Escribe archivos XCursor (sin dependencias: solo Python estándar) en
#    ~/.local/share/icons/Rice-CRT/cursors
#  Cada cursor lleva 3 tamaños (píxel x2, x3, x4 → nominal 24, 36, 48).
#  Uso:  python3 rice-crt-cursor.py
# ─────────────────────────────────────────────────────────────────────────────
import os, struct

OUT = os.path.expanduser("~/.local/share/icons/Rice-CRT")
COL = {                       # carácter → ARGB
    "X": 0xFF120C07,          # borde
    "o": 0xFFFE8019,          # ámbar
    "y": 0xFFFABD2F,          # brillo dorado
    "s": 0xFFAF3A03,          # sombra interna
    "c": 0xFFFBE08A,          # crema (arena del reloj)
    ".": 0x00000000,
}
SCALES = {2: 24, 3: 36, 4: 48}   # escala de píxel → tamaño nominal

# ── Utilidades de grilla ────────────────────────────────────────────────────
def grid(rows): return [list(r) for r in rows]

def blank(w, h): return [["."] * w for _ in range(h)]

def outline(g):
    """Pone borde X alrededor de todo lo que no sea transparente (8 vecinos)."""
    h, w = len(g), len(g[0])
    out = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] != ".": continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and g[yy][xx] not in ".X":
                        out[y][x] = "X"
    return out

def put(g, pts, ch="o"):
    for x, y in pts:
        if 0 <= y < len(g) and 0 <= x < len(g[0]): g[y][x] = ch

def paste(dst, src, ox, oy):
    for y, r in enumerate(src):
        for x, ch in enumerate(r):
            if ch != "." and 0 <= y + oy < len(dst) and 0 <= x + ox < len(dst[0]):
                dst[y + oy][x + ox] = ch

# ── Diseños ─────────────────────────────────────────────────────────────────
ARROW = grid([
    "X...........",
    "XX..........",
    "XyX.........",
    "XyoX........",
    "XyooX.......",
    "XyoooX......",
    "XyooooX.....",
    "XyoooooX....",
    "XyooooooX...",
    "XyoooooooX..",
    "XyoooooooX..",
    "XyoooXXXXX..",
    "XyoXXooX....",
    "XoX.XooX....",
    "XX...XooX...",
    "X....XosX...",
    "......XosX..",
    ".......XX...",
])

HAND = grid([
    "....XX..........",
    "...XyoX.........",
    "...XyoX.........",
    "...XyoX.........",
    "...XyoXXX.......",
    "...XyoXyoXXX....",
    "...XyoXyoXyoXX..",
    "XX.XyoXyoXyoXyX.",
    "XyXXyooooooooooX",
    "XyoXyooooooooooX",
    ".XyoXooooooooooX",
    ".XyooooooooooooX",
    "..XyoooooooooosX",
    "..XyooooooooosX.",
    "...XyoooooooosX.",
    "...XyooooooosX..",
    "....XyooooossX..",
    "....XXXXXXXXXX..",
])

IBEAM = grid([
    "XXX.XXX",
    "XooXooX",
    ".XXoXX.",
    "..XoX..",
    "..XoX..",
    "..XoX..",
    "..XoX..",
    "..XoX..",
    "..XoX..",
    "..XoX..",
    "..XoX..",
    "..XoX..",
    ".XXoXX.",
    "XooXooX",
    "XXX.XXX",
])

def hourglass(frame, frames=6, mini=False):
    """Reloj de arena: la arena pasa de arriba a abajo según el cuadro."""
    shape = grid([
        "XXXXXXXXXXXX",
        "XyyyyyyyyyyX",
        ".X........X.",
        ".X........X.",
        "..X......X..",
        "...X....X...",
        "....X..X....",
        ".....X.X....",
        ".....X.X....",
        "....X..X....",
        "...X....X...",
        "..X......X..",
        ".X........X.",
        ".X........X.",
        "XyyyyyyyyyyX",
        "XXXXXXXXXXXX",
    ])
    # arreglo de la cintura (simétrica)
    shape[6] = list("....X..X....")
    shape[7] = list(".....XX.....")
    shape[8] = list(".....XX.....")
    shape[9] = list("....X..X....")
    t = frame / (frames - 1)
    top_rows, bot_rows = [5, 4, 3, 2], [13, 12, 11, 10]      # de abajo hacia arriba
    top_fill = round(len(top_rows) * (1 - t))
    bot_fill = round(len(bot_rows) * t)
    for y in top_rows[:top_fill]:
        for x in range(12):
            if shape[y][x] == "." and any(shape[y][k] == "X" for k in range(x)) \
               and any(shape[y][k] == "X" for k in range(x + 1, 12)):
                shape[y][x] = "c"
    for y in bot_rows[:bot_fill]:
        for x in range(12):
            if shape[y][x] == "." and any(shape[y][k] == "X" for k in range(x)) \
               and any(shape[y][k] == "X" for k in range(x + 1, 12)):
                shape[y][x] = "o"
    if 0 < frame < frames - 1:                               # chorrito de arena
        for y in range(6, 13 - bot_fill + 1):
            if shape[y][5] in ".c": shape[y][5] = "c"
            if shape[y][6] in ".c" and y in (7, 8): shape[y][6] = "c"
    return shape

def crosshair():
    g = blank(17, 17); c = 8
    put(g, [(c, y) for y in range(1, 6)] + [(c, y) for y in range(11, 16)])
    put(g, [(x, c) for x in range(1, 6)] + [(x, c) for x in range(11, 16)])
    put(g, [(c, c)], "y")
    return outline(g)

def double_arrow(kind):
    """h = ↔, v = ↕, d1 = ↘↖ (nwse), d2 = ↗↙ (nesw)."""
    n = 17; g = blank(n, n); c = n // 2
    if kind == "h":
        put(g, [(x, c) for x in range(2, n - 2)])
        for i in range(1, 4):
            put(g, [(1 + i, c - i), (1 + i, c + i), (n - 2 - i, c - i), (n - 2 - i, c + i)])
            put(g, [(x, c + d) for x in (1 + i, n - 2 - i) for d in range(-i, i + 1)])
        put(g, [(1, c), (n - 2, c)])
    elif kind == "v":
        return [list(r) for r in zip(*double_arrow("h"))]
    else:
        put(g, [(i, i) for i in range(2, n - 2)])
        put(g, [(i + 1, i) for i in range(2, n - 3)])
        for k in range(1, 6):                                  # puntas en "L"
            put(g, [(1 + k, 1), (1, 1 + k), (n - 2 - k, n - 2), (n - 2, n - 2 - k)])
        put(g, [(1, 1), (2, 2), (n - 2, n - 2), (n - 3, n - 3)])
        if kind == "d2":
            g = [r[::-1] for r in g]
        return outline(g)
    return outline(g)

def fleur():
    n = 19; g = blank(n, n); c = n // 2
    put(g, [(x, c) for x in range(2, n - 2)] + [(c, y) for y in range(2, n - 2)])
    for i in range(1, 4):
        put(g, [(x, c + d) for x in (1 + i, n - 2 - i) for d in range(-i, i + 1)])
        put(g, [(c + d, y) for y in (1 + i, n - 2 - i) for d in range(-i, i + 1)])
    put(g, [(1, c), (n - 2, c), (c, 1), (c, n - 2)])
    put(g, [(c, c)], "y")
    return outline(g)

def forbidden():
    n = 17; g = blank(n, n); c = 8
    for y in range(n):
        for x in range(n):
            d2 = (x - c) ** 2 + (y - c) ** 2
            if 30 <= d2 <= 52: g[y][x] = "o"
    put(g, [(c - 4 + i, c - 4 + i) for i in range(9)] + [(c - 3 + i, c - 4 + i) for i in range(8)])
    return outline(g)

QMARK = grid([
    ".ooo.",
    "o...o",
    "....o",
    "...o.",
    "..o..",
    "..o..",
    ".....",
    "..o..",
])

def with_badge(base, badge, ox, oy, w, h):
    g = blank(w, h); paste(g, base, 0, 0)
    b = blank(len(badge[0]) + 2, len(badge) + 2); paste(b, badge, 1, 1)
    paste(g, outline(b), ox, oy)
    return g

def mini_hourglass(frame):
    full = hourglass(frame)
    return [r[::2] for r in full[::2]]     # 6x8: versión chiquita

# ── Escritura XCursor ───────────────────────────────────────────────────────
def to_image(g, scale):
    h, w = len(g), len(g[0])
    px = []
    for y in range(h * scale):
        for x in range(w * scale):
            px.append(COL[g[y // scale][x // scale]])
    return w * scale, h * scale, px

def write_cursor(name, frames, hot, delay=0):
    """frames: lista de grillas (1 = estático). hot: (x, y) en la grilla."""
    chunks = []
    for scale, nominal in SCALES.items():
        for g in frames:
            w, h, px = to_image(g, scale)
            data = struct.pack("<9I", 36, 0xFFFD0002, nominal, 1, w, h,
                               hot[0] * scale, hot[1] * scale, delay)
            data += struct.pack("<%dI" % len(px), *px)
            chunks.append((nominal, data))
    ntoc = len(chunks)
    header = struct.pack("<4sIII", b"Xcur", 16, 0x10000, ntoc)
    pos = 16 + ntoc * 12
    toc, body = b"", b""
    for nominal, data in chunks:
        toc += struct.pack("<III", 0xFFFD0002, nominal, pos)
        body += data; pos += len(data)
    with open(os.path.join(OUT, "cursors", name), "wb") as f:
        f.write(header + toc + body)

def link(target, *names):
    for n in names:
        p = os.path.join(OUT, "cursors", n)
        if os.path.lexists(p): os.remove(p)
        os.symlink(target, p)

# ── Armado del tema ─────────────────────────────────────────────────────────
os.makedirs(os.path.join(OUT, "cursors"), exist_ok=True)

write_cursor("default", [ARROW], (0, 0))
link("default", "left_ptr", "arrow", "top_left_arrow", "context-menu", "copy", "alias",
     "dnd-none", "dnd-move", "dnd-copy", "dnd-link", "dnd-ask", "zoom-in", "zoom-out",
     "center_ptr", "right_ptr", "draft", "x-cursor", "X_cursor")

write_cursor("pointer", [HAND], (4, 0))
link("pointer", "hand", "hand1", "hand2", "pointing_hand", "grab", "openhand",
     "grabbing", "closedhand", "fcf21c00b30f7e3f83fe0dfd12e71cff", "9d800788f1b08800ae810202380a0822",
     "e29285e634086352946a0e7090d73106")

write_cursor("text", [IBEAM], (3, 7))
link("text", "xterm", "ibeam", "vertical-text")

write_cursor("wait", [hourglass(f) for f in range(6)], (6, 8), delay=140)
link("wait", "watch")

prog = [with_badge(ARROW, mini_hourglass(f), 9, 10, 18, 20) for f in range(6)]
write_cursor("progress", prog, (0, 0), delay=140)
link("progress", "left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f",
     "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599")

write_cursor("crosshair", [crosshair()], (8, 8))
link("crosshair", "cross", "tcross", "cell", "plus", "cross_reverse", "diamond_cross")

write_cursor("move", [fleur()], (9, 9))
link("move", "fleur", "all-scroll", "size_all", "4498f0e0c1937ffe01fd06f973665830",
     "9081237383d90e509aa00f00170e968f")

write_cursor("ew-resize", [double_arrow("h")], (8, 8))
link("ew-resize", "col-resize", "sb_h_double_arrow", "size_hor", "h_double_arrow",
     "e-resize", "w-resize", "left_side", "right_side", "split_h",
     "028006030e0e7ebffc7f7070c0600140", "14fef782d02440884392942c11205230")

write_cursor("ns-resize", [double_arrow("v")], (8, 8))
link("ns-resize", "row-resize", "sb_v_double_arrow", "size_ver", "v_double_arrow",
     "n-resize", "s-resize", "top_side", "bottom_side", "split_v",
     "00008160000006810000408080010102", "2870a09082c103050810ffdffffe0204")

write_cursor("nwse-resize", [double_arrow("d1")], (8, 8))
link("nwse-resize", "size_fdiag", "bd_double_arrow", "nw-resize", "se-resize",
     "top_left_corner", "bottom_right_corner", "c7088f0f3e6c8088236ef8e1e3e70000")

write_cursor("nesw-resize", [double_arrow("d2")], (8, 8))
link("nesw-resize", "size_bdiag", "fd_double_arrow", "ne-resize", "sw-resize",
     "top_right_corner", "bottom_left_corner", "fcf1c3c7cd4491d801f1e1c78f100000")

write_cursor("not-allowed", [forbidden()], (8, 8))
link("not-allowed", "forbidden", "crossed_circle", "no-drop", "circle",
     "03b6e0fcb3499374a867c041f52298f0")

write_cursor("help", [with_badge(ARROW, QMARK, 10, 9, 18, 19)], (0, 0))
link("help", "question_arrow", "whats_this", "left_ptr_help",
     "5c6cd98b3f3ebcb1f9c7f1c204630408", "d9ce0ab605698f320427677b8f8ce4a2")

with open(os.path.join(OUT, "index.theme"), "w") as f:
    f.write("[Icon Theme]\nName=Rice-CRT\nComment=Cursor pixel art ámbar del rice\n")
with open(os.path.join(OUT, "cursor.theme"), "w") as f:
    f.write("[Icon Theme]\nName=Rice-CRT\nInherits=Rice-CRT\n")
print("Listo:", OUT)
