"""
demo.py — recorrido grabado del rice: arranque MAGI → escritorio → lanzador,
btop, terminales, hoja de atajos, efecto CRT, calculadora, Zen, Dolphin →
modo consola (recientes, biblioteca, búsqueda) → escritorio.
Graba con wf-recorder (imagen + sonido del sistema) en el archivo que se pase.
NO tocar el mouse ni el teclado mientras corre.
Uso: python3 demo.py salida.mkv
"""
import sys, time, random, subprocess, json, os
from vinput import V, EV_KEY, K, BTN_LEFT

OUT = sys.argv[1]
SINK = subprocess.run(['pactl', 'get-default-sink'], capture_output=True, text=True).stdout.strip()
v = V()
r = random.uniform

def wait(a, b=None): time.sleep(a if b is None else r(a, b))
def sh(*cmd): return subprocess.run(cmd, capture_output=True, text=True).stdout
def spawn(*cmd): subprocess.Popen(['setsid', '-f', 'uwsm', 'app', '--', *cmd], stdin=subprocess.DEVNULL,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def clients(): return [c for c in json.loads(sh('hyprctl', 'clients', '-j')) if c['workspace']['id'] == 4]
def wait_windows(n, timeout=6):
    t0 = time.time()
    while len(clients()) < n and time.time() - t0 < timeout: time.sleep(0.1)
def center_of(cls):
    for c in clients():
        if c['class'] == cls: return c['at'][0] + c['size'][0] / 2, c['at'][1] + c['size'][1] / 2
    return 960, 540
def keydown(k): v._ev(v.k, EV_KEY, K[k], 1); v._syn(v.k)
def keyup(k): v._ev(v.k, EV_KEY, K[k], 0); v._syn(v.k)
def btn(state): v._ev(v.m, EV_KEY, BTN_LEFT, state); v._syn(v.m)

# ── Preparación (no se ve) ─────────────────────────────────────────────────
sh('swaync-client', '-C')
v.warp(1250, 700)
rec = subprocess.Popen(['wf-recorder', '-c', 'libx264', '-r', '30', '-p', 'preset=veryfast', '-p', 'crf=20',
                        f'--audio={SINK}.monitor', '-f', OUT], stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
wait(1.5)

# ── 1. Arranque MAGI y escritorio ──────────────────────────────────────────
spawn('qs', '-c', 'rice-boot')
wait(7.5)
wait(2.5)                                   # escritorio solo: fondo con glitch y ruido
v.move(1100, 520); wait(0.6, 1.0)
v.fidget(2); wait(1.5)

# ── 2. Lanzador: buscar y abrir btop ───────────────────────────────────────
v.key('super+space'); wait(1.4)
v.move(980, 600, speed=0.8); wait(0.4)
v.type('bto'); wait(0.4); v.type('p'); wait(1.0)
v.key('enter'); wait(2.8)
v.fidget(2); wait(1.2)
v.key('super+q'); wait(1.0)

# ── 3. Muchas terminales (mosaico), una con eza, y cerrarlas ───────────────
for i in range(4):
    v.key('super+enter'); wait(0.55, 0.9)
wait_windows(4); wait(1.0)
v.move(1450, 780); wait(0.3)
v.type('eza --icons'); wait(0.3); v.key('enter'); wait(1.8)
v.move(480, 300); wait(0.4)
for i in range(4):
    cs = clients()
    if not cs: break
    c = random.choice(cs)
    v.move(c['at'][0] + c['size'][0] * r(0.3, 0.7), c['at'][1] + c['size'][1] * r(0.3, 0.7), speed=r(1.1, 1.5))
    wait(0.15, 0.35)
    v.key('super+q'); wait(0.35, 0.6)
wait(1.0)

# ── 4. Hoja de atajos ──────────────────────────────────────────────────────
v.key('super+f1'); wait(1.2)
v.move(720, 400); wait(0.5); v.move(1150, 640, speed=0.7); wait(0.6); v.move(1500, 470); wait(1.2)
v.key('esc'); wait(1.0)

# ── 5. Efecto CRT: apagar y prender ────────────────────────────────────────
v.key('super+f12'); wait(2.0)
v.key('super+f12'); wait(1.5)

# ── 6. Calculadora ─────────────────────────────────────────────────────────
v.key('super+c'); wait_windows(1); wait(1.4)
x, y = center_of('org.gnome.Calculator'); v.move(x + r(-40, 40), y + r(-30, 30)); wait(0.3)
v.type('2026-1995'); wait(0.4); v.key('enter'); wait(1.8)
v.key('super+q'); wait(1.0)

# ── 7. Zen ─────────────────────────────────────────────────────────────────
v.move(900, 450); wait(0.3)
spawn('zen-browser', '--new-window', 'https://github.com/swamidri-cyber/evangelion-dotfiles')
wait_windows(1, 8); wait(3.5)
v.move(1000, 640); wait(0.6)
v.scroll(-5); wait(1.2); v.scroll(-6); wait(1.5); v.scroll(8); wait(1.0)
v.move(70, 330); wait(1.2)                  # barra lateral de Zen
v.move(960, 520); wait(0.4)
v.key('super+q'); wait(1.2)

# ── 8. Dolphin: carpetas y arrastrar la ventana ────────────────────────────
v.key('super+e'); wait_windows(1); wait(1.8)
d = next((c for c in clients() if c['class'] == 'org.kde.dolphin'), None)
if d:
    ox, oy = d['at']
    v.move(ox + 95, oy + 205); wait(0.2); v.click(); wait(1.4)        # Imágenes
    v.move(ox + 480, oy + 250); wait(0.8); v.fidget(2); wait(0.5)
    v.move(ox + 85, oy + 228); wait(0.2); v.click(); wait(1.4)        # Vídeos
    v.move(ox + 500, oy + 300); wait(0.8)
    # Super + arrastrar: mover la ventana
    keydown('super'); wait(0.1); btn(1); wait(0.1)
    v.move(ox + 500 + 640, oy + 300 + 180, speed=0.6); wait(0.2)
    btn(0); wait(0.05); keyup('super'); wait(1.0)
v.key('super+q'); wait(1.5)

# ── 9. Modo consola: con el botón del escritorio ───────────────────────────
v.move(1736, 112); wait(0.4); v.click(); wait(4.2)
for k in ('right', 'right', 'right', 'left', 'right', 'right', 'right', 'right'):
    v.key(k); wait(0.35, 0.7)
wait(1.0)
v.key('tab'); wait(1.6)                    # biblioteca
for (x, y) in ((420, 330), (760, 560), (1150, 330), (1500, 790), (980, 800)):
    v.move(x + r(-20, 20), y + r(-20, 20)); wait(0.5, 0.9)
v.move(1300, 600); wait(0.4)
v.key('ctrl+f'); wait(0.7); v.type('mine'); wait(1.8)
v.key('esc'); wait(1.0)
v.key('tab'); wait(1.4)                    # vuelve a recientes
v.key('super+g'); wait(3.5)                # salir del modo consola (Super+G abre y cierra)

# ── Cierre ─────────────────────────────────────────────────────────────────
v.move(1000, 560, speed=0.7); wait(3.5)
rec.send_signal(2); rec.wait(timeout=15)
v.close()
