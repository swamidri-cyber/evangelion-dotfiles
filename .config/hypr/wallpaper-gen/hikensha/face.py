#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  Fondo "被験体07" (sujeto 07): personaje original de un anime de los 90 que
#  no existe. Paso 1: el dibujo en vectores (SVG) — line art negro sobre
#  figura blanca, fondo negro. Paso 2 (post.py): sobreexposición, brillo
#  ámbar, ojo de pez, aberración cromática y grano.
# ─────────────────────────────────────────────────────────────────────────────
import sys

INK = "#0a0806"
SKIN = "#f4efe6"
SHADE = "#b9ad9c"      # sombra de cel (se quema a casi blanco en el post)
HAIR = "#e6ddcc"
HAIRSH = "#8f8270"

def eye(cx, cy, flip=1):
    """Ojo grande de los 90: alto, muy abierto, iris chico flotando (shock)."""
    f = flip
    p = []
    # blanco del ojo (más alto que ancho hacia el centro de la cara)
    p.append(f'<path d="M{cx-44*f},{cy+2} C{cx-40*f},{cy-30} {cx+6*f},{cy-46} {cx+42*f},{cy-22} '
             f'C{cx+46*f},{cy+10} {cx+20*f},{cy+34} {cx-6*f},{cy+34} C{cx-28*f},{cy+32} {cx-42*f},{cy+20} {cx-44*f},{cy+2} Z" fill="#ffffff"/>')
    # iris chico con anillos, pupila mínima
    p.append(f'<circle cx="{cx}" cy="{cy-2}" r="17" fill="#3a3129" stroke="{INK}" stroke-width="3"/>')
    p.append(f'<circle cx="{cx}" cy="{cy-2}" r="11" fill="none" stroke="#7a6a58" stroke-width="2"/>')
    p.append(f'<circle cx="{cx}" cy="{cy-2}" r="3" fill="{INK}"/>')
    p.append(f'<rect x="{cx-10*f-4}" y="{cy-14}" width="7" height="7" fill="#ffffff"/>')
    p.append(f'<circle cx="{cx+8*f}" cy="{cy+7}" r="2" fill="#ffffff"/>')
    # párpado superior grueso con pestaña exterior
    p.append(f'<path d="M{cx-46*f},{cy+4} C{cx-42*f},{cy-34} {cx+6*f},{cy-52} {cx+44*f},{cy-24} '
             f'L{cx+56*f},{cy-30} L{cx+46*f},{cy-14}" fill="none" stroke="{INK}" '
             f'stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>')
    # párpado inferior: trazo corto, no se une con el de arriba
    p.append(f'<path d="M{cx-26*f},{cy+30} C{cx-8*f},{cy+38} {cx+18*f},{cy+34} {cx+32*f},{cy+20}" '
             f'fill="none" stroke="{INK}" stroke-width="2.5" stroke-linecap="round"/>')
    # pliegue del párpado y ojera
    p.append(f'<path d="M{cx-34*f},{cy-40} C{cx-10*f},{cy-60} {cx+22*f},{cy-60} {cx+40*f},{cy-44}" '
             f'fill="none" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
    p.append(f'<path d="M{cx-24*f},{cy+46} C{cx-4*f},{cy+54} {cx+18*f},{cy+50} {cx+30*f},{cy+40}" '
             f'fill="none" stroke="{SHADE}" stroke-width="3" stroke-linecap="round"/>')
    return "\n".join(p)

def svg():
    o = []
    o.append('<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">')
    o.append('<rect width="1920" height="1080" fill="#000"/>')

    # ── Anillo HUD tenue detrás de la cabeza ──
    o.append('<g fill="none" stroke="#7a4a1c" stroke-linecap="butt">'
             '<circle cx="960" cy="520" r="400" stroke-width="2" stroke-dasharray="180 40 30 40"/>'
             '<circle cx="960" cy="520" r="430" stroke-width="10" stroke-dasharray="4 18" opacity="0.7"/>'
             '<circle cx="960" cy="520" r="470" stroke-width="1.5" stroke-dasharray="600 300"/>'
             '</g>')

    # ── Hombros y traje (cuello alto tipo plugsuit) ──
    o.append(f'<path d="M560,1080 C600,930 760,880 880,860 L1040,860 C1160,880 1320,930 1360,1080 Z" '
             f'fill="{SKIN}" stroke="{INK}" stroke-width="6"/>')
    o.append(f'<path d="M700,1080 C730,980 800,940 880,920" fill="none" stroke="{INK}" stroke-width="4"/>')
    o.append(f'<path d="M1220,1080 C1190,980 1120,940 1040,920" fill="none" stroke="{INK}" stroke-width="4"/>')
    o.append(f'<path d="M560,1080 C600,930 760,880 880,860 L860,920 C780,950 700,1000 680,1080 Z" fill="{SHADE}"/>')
    # placa del pecho con el número
    o.append(f'<path d="M905,960 L1015,960 L1030,1040 L890,1040 Z" fill="#ffffff" stroke="{INK}" stroke-width="4"/>')
    o.append(f'<text x="960" y="1018" font-family="DepartureMono Nerd Font" font-size="44" '
             f'text-anchor="middle" fill="{INK}">07</text>')

    # ── Cuello ──
    o.append(f'<path d="M905,690 L900,880 L1020,880 L1015,690 Z" fill="{SKIN}" stroke="{INK}" stroke-width="5"/>')
    o.append(f'<path d="M905,700 L1015,700 L1012,760 C980,740 940,740 906,770 Z" fill="{SHADE}"/>')
    # collar de interfaz
    o.append(f'<rect x="888" y="800" width="144" height="46" rx="6" fill="#ffffff" stroke="{INK}" stroke-width="5"/>')
    o.append(f'<rect x="900" y="812" width="40" height="22" fill="{INK}"/>')
    o.append(f'<circle cx="1008" cy="823" r="8" fill="none" stroke="{INK}" stroke-width="3"/>')
    o.append(f'<line x1="950" y1="823" x2="992" y2="823" stroke="{INK}" stroke-width="3" stroke-dasharray="6 4"/>')
    o.append(f'<text x="920" y="830" font-family="Noto Sans CJK JP" font-size="16" '
             f'text-anchor="middle" fill="#ffffff">零七</text>')

    o.append('<g transform="translate(960,640) scale(1.22) translate(-960,-640)">')
    # ── Pelo de atrás (bob desparejo) ──
    o.append(f'<path d="M780,600 C740,470 760,300 880,250 C960,215 1060,225 1120,280 '
             f'C1190,345 1190,500 1150,640 L1130,600 L1120,690 L1095,620 L1080,700 L1060,560 '
             f'L880,560 L860,700 L845,615 L820,690 L812,600 L795,660 Z" '
             f'fill="{HAIRSH}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>')

    # ── Cara ──
    o.append(f'<path d="M832,420 C826,520 838,600 880,660 C910,700 940,722 960,724 '
             f'C980,722 1010,700 1040,660 C1082,600 1094,520 1088,420 Z" '
             f'fill="{SKIN}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>')
    # sombra de cel bajo el flequillo
    o.append(f'<path d="M834,420 L1086,420 L1088,470 C1040,500 1010,470 980,505 C950,470 900,500 836,476 Z" fill="{SHADE}"/>')
    # orejas
    o.append(f'<path d="M834,520 C808,512 806,570 838,590" fill="{SKIN}" stroke="{INK}" stroke-width="5"/>')
    o.append(f'<path d="M1086,520 C1112,512 1114,570 1082,590" fill="{SKIN}" stroke="{INK}" stroke-width="5"/>')

    # ── Líneas de shock (縦線): rayas verticales sobre la parte alta de la cara ──
    for i, x in enumerate(range(850, 1080, 14)):
        top = 470 + (i % 3) * 6
        o.append(f'<line x1="{x}" y1="{top}" x2="{x}" y2="{top + 26 + (i % 4) * 8}" '
                 f'stroke="{SHADE}" stroke-width="3"/>')

    # ── Ojos ──
    o.append(eye(894, 556, -1))
    o.append(eye(1026, 556, 1))

    # ── Nariz, boca ──
    o.append(f'<path d="M966,600 L958,630 L968,632" fill="none" stroke="{INK}" stroke-width="3" stroke-linecap="round"/>')
    o.append(f'<path d="M936,672 C950,666 972,666 986,670 C978,684 946,686 936,672 Z" fill="{INK}"/>')
    o.append(f'<path d="M948,676 C958,680 970,680 978,676" fill="none" stroke="#5a2a20" stroke-width="3"/>')

    # ── Lágrima seca y apósito en la mejilla ──
    o.append(f'<path d="M870,590 C866,620 868,650 874,672" fill="none" stroke="{SHADE}" stroke-width="3"/>')
    o.append(f'<g transform="rotate(-18 1046 640)">'
             f'<rect x="1010" y="626" width="72" height="28" rx="8" fill="#ffffff" stroke="{INK}" stroke-width="4"/>'
             f'<rect x="1034" y="630" width="24" height="20" fill="#ece3d2" stroke="{INK}" stroke-width="2"/>'
             f'<line x1="1018" y1="634" x2="1026" y2="646" stroke="{INK}" stroke-width="2"/>'
             f'<line x1="1066" y1="634" x2="1074" y2="646" stroke="{INK}" stroke-width="2"/></g>')

    # ── Flequillo (mechones en punta, uno cruza el ojo) ──
    o.append(f'<path d="M800,470 C800,330 880,262 960,258 C1060,256 1140,320 1124,480 '
             f'L1106,448 L1096,526 L1078,456 L1062,478 L1044,432 L1034,546 L1008,444 L990,476 '
             f'L972,428 L954,536 L934,440 L916,482 L898,432 L880,520 L862,450 L842,540 L826,520 Z" '
             f'fill="{HAIR}" stroke="{INK}" stroke-width="6" stroke-linejoin="round"/>')
    # mechones de los costados que caen sobre la cara
    o.append(f'<path d="M808,450 L842,600 L826,560 L818,640 L800,540 Z" fill="{HAIR}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
    o.append(f'<path d="M1114,450 L1080,600 L1096,560 L1104,640 L1122,540 Z" fill="{HAIR}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
    # brillos y líneas del pelo
    o.append(f'<path d="M870,330 C910,300 1010,296 1060,330 L1050,346 C1000,320 920,322 880,346 Z" fill="#ffffff"/>')
    for d in ["M900,300 C890,360 896,420 900,470", "M960,262 C956,330 960,400 972,420",
              "M1030,280 C1046,340 1050,400 1046,486", "M850,360 C840,410 846,460 862,500",
              "M1090,340 C1100,390 1100,430 1092,500"]:
        o.append(f'<path d="{d}" fill="none" stroke="{HAIRSH}" stroke-width="3"/>')

    o.append('</g>')
    # ── Texto HUD ──
    o.append('<g font-family="DepartureMono Nerd Font" font-size="18" fill="#8a5a24">'
             '<text x="560" y="210">SUBJ.07 // SYNC 41.3%</text>'
             '<text x="1240" y="210" text-anchor="start">PSY.CONTAM ▮▮▮▯▯</text>'
             '</g>')
    o.append('<g font-family="Noto Sans CJK JP" font-size="22" fill="#8a5a24">'
             '<text x="560" y="240">被験体 零七</text>'
             '<text x="1240" y="240">精神汚染 警告</text></g>')
    o.append('</svg>')
    return "\n".join(o)

open(sys.argv[1] if len(sys.argv) > 1 else "face.svg", "w").write(svg())
