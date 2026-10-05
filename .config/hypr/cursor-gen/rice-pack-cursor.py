#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  Cursor "Rice-CRT" v2: hecho con el pack pixel art que pasó el usuario
#  (pack/pack.png → pack/extract.py → pack/grids.json), recoloreado con el
#  crema durazno de las alas del fondo y borde marrón casi negro.
#
#  Lo que el pack no trae (I de texto, flechas de redimensionar, signo de
#  pregunta) se toma de rice-crt-cursor.py (v1), que tiene el mismo estilo.
#  Escribe en ~/.local/share/icons/Rice-CRT (mismo nombre: no hay que tocar
#  ninguna configuración). Respaldo de la v1: cursor-gen/Rice-CRT-v1
#  Uso:  python3 rice-pack-cursor.py
# ─────────────────────────────────────────────────────────────────────────────
import json, os, shutil

D = os.path.dirname(os.path.abspath(__file__))

# Funciones y diseños de la v1 (todo lo anterior a "Armado del tema")
exec(open(os.path.join(D, "rice-crt-cursor.py")).read().split("# ── Armado del tema")[0])

COL.update({                  # carácter → ARGB (los de la v1 se pasan al crema)
    "X": 0xFF190C0A,          # borde marrón casi negro (lo oscuro del fondo)
    "o": 0xFFF9D8A7,          # crema durazno (lo claro de las alas)
    "y": 0xFFF9D8A7,
    "c": 0xFFF9D8A7,
    "s": 0xFFE6BC86,          # sombra apenas más tostada
})

P = json.load(open(os.path.join(D, "pack", "grids.json")))
def g(name): return grid(P[name])

def main_part(gr):
    """Se queda con el dibujo principal (sin las rayitas/puntos de 'clic')."""
    h, w = len(gr), len(gr[0])
    seen, best = set(), []
    for y in range(h):
        for x in range(w):
            if gr[y][x] == "." or (x, y) in seen: continue
            comp, stack = [], [(x, y)]; seen.add((x, y))
            while stack:
                cx, cy = stack.pop(); comp.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and gr[ny][nx] != "." and (nx, ny) not in seen:
                        seen.add((nx, ny)); stack.append((nx, ny))
            if len(comp) > len(best): best = comp
    xs = [p[0] for p in best]; ys = [p[1] for p in best]
    out = blank(max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)
    for x, y in best: out[y - min(ys)][x - min(xs)] = gr[y][x]
    return out

def filled(gr):
    """Íconos del pack que son solo borde (mover, destello): relleno crema + borde."""
    h, w = len(gr), len(gr[0])
    big = blank(w + 2, h + 2)
    for y in range(h):
        for x in range(w):
            if gr[y][x] != ".": big[y + 1][x + 1] = "o"
    return outline(big)

def tip(gr):
    """Punta: primer píxel del renglón de arriba."""
    return (next(i for i, ch in enumerate(gr[0]) if ch != "."), 0)

def center(gr): return (len(gr[0]) // 2, len(gr) // 2)

# ── Armado del tema ─────────────────────────────────────────────────────────
# Se vacía antes: algunos nombres eran enlaces en la v1 y escribir encima
# pisaría el archivo al que apuntan.
shutil.rmtree(os.path.join(OUT, "cursors"), ignore_errors=True)
os.makedirs(os.path.join(OUT, "cursors"))

arrow = main_part(g("arrow_click"))
write_cursor("default", [arrow], tip(arrow))
link("default", "left_ptr", "arrow", "top_left_arrow", "context-menu", "copy", "alias",
     "dnd-none", "dnd-move", "dnd-copy", "dnd-link", "dnd-ask",
     "center_ptr", "right_ptr", "draft", "x-cursor", "X_cursor")

hand = main_part(g("hand_click"))
write_cursor("pointer", [hand], tip(hand))
link("pointer", "hand", "hand1", "hand2", "pointing_hand", "grab", "openhand",
     "grabbing", "closedhand", "fcf21c00b30f7e3f83fe0dfd12e71cff", "9d800788f1b08800ae810202380a0822",
     "e29285e634086352946a0e7090d73106")

write_cursor("text", [IBEAM], (3, 7))
link("text", "xterm", "ibeam", "vertical-text")

frames = [g(f"hg{i}") for i in range(4)]
write_cursor("wait", frames, center(frames[0]), delay=280)
link("wait", "watch")

prog = g("arrow_wait")
write_cursor("progress", [prog], tip(prog))
link("progress", "left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f",
     "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599")

write_cursor("zoom-in", [g("zoom_in")], (5, 5))
write_cursor("zoom-out", [g("zoom_out")], (5, 5))

burst = filled(g("burst"))
write_cursor("crosshair", [burst], center(burst))
link("crosshair", "cross", "tcross", "cell", "plus", "cross_reverse", "diamond_cross")

move = filled(g("move"))
write_cursor("move", [move], center(move))
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

forbid = g("forbid")
write_cursor("not-allowed", [forbid], center(forbid))
link("not-allowed", "forbidden", "crossed_circle", "circle", "03b6e0fcb3499374a867c041f52298f0")

nodrop = g("nodrop")
write_cursor("no-drop", [nodrop], tip(nodrop))

write_cursor("help", [with_badge(arrow, QMARK, 10, 9, 18, 19)], tip(arrow))
link("help", "question_arrow", "whats_this", "left_ptr_help",
     "5c6cd98b3f3ebcb1f9c7f1c204630408", "d9ce0ab605698f320427677b8f8ce4a2")

with open(os.path.join(OUT, "index.theme"), "w") as f:
    f.write("[Icon Theme]\nName=Rice-CRT\nComment=Cursor pixel art crema del rice (pack del usuario)\n")
with open(os.path.join(OUT, "cursor.theme"), "w") as f:
    f.write("[Icon Theme]\nName=Rice-CRT\nInherits=Rice-CRT\n")
print("Listo:", OUT)
