"""
demo-rapido.py — el mismo recorrido que demo.py pero como alguien canchero
que hace todo rapidísimo: mouse ~2x, escribe rápido, pausas mínimas (espera
que las ventanas aparezcan en vez de tiempos fijos). Apunta a ~1:10 en vivo.
NO tocar el mouse ni el teclado mientras corre.
Uso: python3 demo-rapido.py salida.mkv
"""
import sys, time, random, subprocess, json
from vinput import V, EV_KEY, K, BTN_LEFT

OUT = sys.argv[1]
SINK = subprocess.run(['pactl', 'get-default-sink'], capture_output=True, text=True).stdout.strip()
v = V()
v.speed = 2.0
r = random.uniform
WPM = 750

def wait(a, b=None): time.sleep(a if b is None else r(a, b))
def sh(*cmd): return subprocess.run(cmd, capture_output=True, text=True).stdout
def spawn(*cmd): subprocess.Popen(['setsid', '-f', 'uwsm', 'app', '--', *cmd], stdin=subprocess.DEVNULL,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def clients(): return [c for c in json.loads(sh('hyprctl', 'clients', '-j')) if c['workspace']['id'] == 4]
def wait_windows(n, timeout=6):
    t0 = time.time()
    while len(clients()) < n and time.time() - t0 < timeout: time.sleep(0.05)
def wait_class(cls, timeout=6):
    t0 = time.time()
    while time.time() - t0 < timeout:
        for c in clients():
            if c['class'] == cls: return c
        time.sleep(0.05)
def wait_title(word, timeout=6):
    t0 = time.time()
    while time.time() - t0 < timeout:
        for c in clients():
            if word in c['title'].lower(): return c
        time.sleep(0.05)
def focused_title(): return json.loads(sh('hyprctl', 'activewindow', '-j') or '{}').get('title', '').lower()
def keydown(k): v._ev(v.k, EV_KEY, K[k], 1); v._syn(v.k)
def keyup(k): v._ev(v.k, EV_KEY, K[k], 0); v._syn(v.k)
def btn(state): v._ev(v.m, EV_KEY, BTN_LEFT, state); v._syn(v.m)
def flick(x, y, s=1.0): v.move(x + r(-15, 15), y + r(-15, 15), speed=s)

# ── Preparación (no se ve) ─────────────────────────────────────────────────
sh('swaync-client', '-C')
v.warp(1250, 700)
rec = subprocess.Popen(['wf-recorder', '-c', 'libx264', '-r', '30', '-p', 'preset=veryfast', '-p', 'crf=20',
                        f'--audio={SINK}.monitor', '-f', OUT], stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
wait(1.5)

# ── 1. Arranque MAGI (no se acelera) y un vistazo al escritorio ────────────
spawn('qs', '-c', 'rice-boot')
wait(7.3)
flick(1050, 520); v.fidget(1); wait(0.5)

# ── 2. Lanzador → btop ─────────────────────────────────────────────────────
v.key('super+space'); wait(0.5)
v.type('btop', WPM); wait(0.35); v.key('enter')
b = wait_class('Alacritty'); wait(1.4)        # btop.desktop abre en Alacritty
flick(700, 400); flick(1300, 650); wait(0.15)
v.key('super+q'); wait(0.35)
if wait_class('Alacritty', 0.2): v.key('super+q'); wait(0.3)

# ── 3. Ráfaga de terminales, eza en una, y cerrarlas al toque ──────────────
for i in range(4):
    v.key('super+enter'); wait(0.18, 0.3)
wait_windows(4); wait(0.5)
flick(1450, 780); v.type('eza --icons', WPM); v.key('enter'); wait(0.9)
for i in range(4):
    cs = clients()
    if not cs: break
    c = random.choice(cs)
    v.move(c['at'][0] + c['size'][0] * r(0.3, 0.7), c['at'][1] + c['size'][1] * r(0.3, 0.7), speed=1.3)
    v.key('super+q'); wait(0.12, 0.2)
wait(0.3)

# ── 4. Hoja de atajos ──────────────────────────────────────────────────────
v.key('super+f1'); wait(0.5)
flick(720, 400); flick(1180, 640); flick(1500, 470); wait(0.4)
v.key('esc'); wait(0.3)

# ── 5. CRT apagar / prender ────────────────────────────────────────────────
v.key('super+f12'); wait(1.0)
v.key('super+f12'); wait(0.7)

# ── 6. Calculadora ─────────────────────────────────────────────────────────
v.key('super+c'); c = wait_class('org.gnome.Calculator'); wait(0.6)
if c: flick(c['at'][0] + c['size'][0] / 2, c['at'][1] + c['size'][1] / 2)
v.type('2026-1995', WPM); v.key('enter'); wait(0.8)
v.key('super+q'); wait(0.3)

# ── 7. Zen ─────────────────────────────────────────────────────────────────
flick(900, 450)
spawn('zen-browser', '--new-window', 'https://github.com/swamidri-cyber/evangelion-dotfiles')
wait_class('zen', 8); wait(2.2)
flick(1000, 640)
v.scroll(-8); wait(0.6); v.scroll(-6); wait(0.6)
flick(70, 330); wait(0.4)
v.scroll(14); flick(960, 520)
v.key('super+q'); wait(0.4)

# ── 8. Dolphin: carpetas y arrastrar la ventana ────────────────────────────
v.key('super+e'); d = wait_class('org.kde.dolphin'); wait(0.6)
if d:
    ox, oy = d['at']
    v.move(ox + 95, oy + 205); v.click(); wait(0.6)                   # Imágenes
    flick(ox + 480, oy + 250); wait(0.3)
    v.move(ox + 85, oy + 228); v.click(); wait(0.6)                   # Vídeos
    flick(ox + 500, oy + 300); wait(0.2)
    keydown('super'); wait(0.05); btn(1); wait(0.05)
    v.move(ox + 500 + 640, oy + 300 + 180, speed=0.9)
    btn(0); keyup('super'); wait(0.4)
v.key('super+q'); wait(0.6)

# ── 9. Modo consola (botón del escritorio) ─────────────────────────────────
v.move(1736, 112); v.click(); wait(3.6)
for k in ('right', 'right', 'right', 'right', 'left', 'right', 'right', 'right', 'right'):
    v.key(k); wait(0.15, 0.3)
wait(0.4)
v.key('tab'); wait(0.9)                    # biblioteca
for (x, y) in ((420, 330), (760, 560), (1150, 330), (1500, 790), (980, 800)):
    flick(x, y); wait(0.2, 0.35)
v.key('ctrl+f'); wait(0.3); v.type('mine', WPM); wait(1.0)
v.key('esc'); wait(0.5)
v.key('tab'); wait(0.6)
v.key('super+g'); wait(3.0)                # salir del modo consola

# ── Cierre ─────────────────────────────────────────────────────────────────
flick(1000, 560, 0.6); wait(1.8)
rec.send_signal(2); rec.wait(timeout=15)
v.close()
