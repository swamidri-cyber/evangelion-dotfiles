"""
vinput.py — mouse y teclado virtuales por /dev/uinput (sin dependencias).
Movimientos "humanos": curvas irregulares (Bézier con puntos de control al
azar), aceleración y frenado, temblor fino, a veces se pasa y corrige.
Uso desde otro script:  from vinput import V;  v = V();  v.move(800, 400); v.click()
"""
import fcntl, struct, os, time, random, math

EV_SYN, EV_KEY, EV_REL, EV_ABS = 0, 1, 2, 3
ABS_X, ABS_Y, REL_WHEEL = 0, 1, 8
BTN_LEFT, BTN_RIGHT, BTN_MIDDLE = 0x110, 0x111, 0x112
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT, UI_SET_ABSBIT = 0x40045564, 0x40045565, 0x40045566, 0x40045567
UI_DEV_SETUP, UI_ABS_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405c5503, 0x401c5504, 0x5501, 0x5502

# Teclas (códigos evdev). Teclado latam: letras y números en el mismo lugar que US.
K = {'esc': 1, 'enter': 28, 'space': 57, 'tab': 15, 'backspace': 14, 'up': 103, 'down': 108,
     'left': 105, 'right': 106, 'super': 125, 'ctrl': 29, 'shift': 42, 'alt': 56, 'delete': 111,
     'f1': 59, 'f11': 87, 'f12': 88, 'slash': 12, 'pageup': 104, 'pagedown': 109, 'home': 102, 'end': 107}
for i, c in enumerate('1234567890'): K[c] = 2 + i
for row, start in (('qwertyuiop', 16), ('asdfghjkl', 30), ('zxcvbnm', 44)):
    for i, c in enumerate(row): K[c] = start + i
K['-'] = 53; K['.'] = 52; K[','] = 51   # latam: - es la tecla de / en US

def _dev(name, setup):
    fd = os.open('/dev/uinput', os.O_WRONLY | os.O_NONBLOCK)
    setup(fd)
    fcntl.ioctl(fd, UI_DEV_SETUP, struct.pack('HHHH80sI', 0x06, 0x1234, 0x5678, 1, name.encode(), 0))
    fcntl.ioctl(fd, UI_DEV_CREATE)
    return fd

class V:
    def __init__(self, w=1920, h=1080):
        self.w, self.h = w, h
        def mouse(fd):
            for ev in (EV_KEY, EV_ABS, EV_REL): fcntl.ioctl(fd, UI_SET_EVBIT, ev)
            for b in (BTN_LEFT, BTN_RIGHT, BTN_MIDDLE): fcntl.ioctl(fd, UI_SET_KEYBIT, b)
            fcntl.ioctl(fd, UI_SET_RELBIT, REL_WHEEL)
            for code, mx in ((ABS_X, w - 1), (ABS_Y, h - 1)):
                fcntl.ioctl(fd, UI_SET_ABSBIT, code)
                fcntl.ioctl(fd, UI_ABS_SETUP, struct.pack('HHiiiiii', code, 0, 0, 0, mx, 0, 0, 0))
        def kbd(fd):
            fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
            for k in range(1, 249): fcntl.ioctl(fd, UI_SET_KEYBIT, k)
        self.m = _dev('rice-demo mouse', mouse)
        self.k = _dev('rice-demo keyboard', kbd)
        self.x, self.y = w / 2, h / 2
        self.speed = 1.0                     # multiplica la velocidad de todos los movimientos
        time.sleep(1.0)                      # que el compositor vea los dispositivos

    def _ev(self, fd, t, c, v):
        os.write(fd, struct.pack('llHHi', 0, 0, t, c, v))
    def _syn(self, fd): self._ev(fd, EV_SYN, 0, 0)

    def _put(self, x, y):
        x = min(max(x, 0), self.w - 1); y = min(max(y, 0), self.h - 1)
        self._ev(self.m, EV_ABS, ABS_X, int(round(x))); self._ev(self.m, EV_ABS, ABS_Y, int(round(y))); self._syn(self.m)
        self.x, self.y = x, y

    def warp(self, x, y): self._put(x, y)

    def move(self, x, y, speed=1.0):
        """Va de donde está a (x, y) con una curva irregular y velocidad humana."""
        x0, y0 = self.x, self.y
        dx, dy = x - x0, y - y0
        d = math.hypot(dx, dy)
        if d < 1: return
        # Pasarse un poco y corregir en recorridos largos (a veces)
        if d > 350 and random.random() < 0.45:
            ox = x + dx / d * random.uniform(8, 22) + random.uniform(-6, 6)
            oy = y + dy / d * random.uniform(8, 22) + random.uniform(-6, 6)
            self._curve(x0, y0, ox, oy, d, speed)
            time.sleep(random.uniform(0.03, 0.08))
            self._curve(ox, oy, x + random.uniform(-1.5, 1.5), y + random.uniform(-1.5, 1.5), 25, speed)
        else:
            self._curve(x0, y0, x + random.uniform(-1.5, 1.5), y + random.uniform(-1.5, 1.5), d, speed)

    def _curve(self, x0, y0, x1, y1, d, speed):
        dx, dy = x1 - x0, y1 - y0
        nx, ny = (-dy / d, dx / d) if d else (0, 0)
        bend = d * random.uniform(0.08, 0.30) * random.choice((-1, 1))
        c1 = (x0 + dx * random.uniform(0.2, 0.4) + nx * bend * random.uniform(0.6, 1.2),
              y0 + dy * random.uniform(0.2, 0.4) + ny * bend * random.uniform(0.6, 1.2))
        c2 = (x0 + dx * random.uniform(0.6, 0.85) + nx * bend * random.uniform(-0.4, 0.7),
              y0 + dy * random.uniform(0.6, 0.85) + ny * bend * random.uniform(-0.4, 0.7))
        # Duración tipo ley de Fitts, con variación
        dur = (0.12 + 0.11 * math.log2(1 + d / 12)) * random.uniform(0.85, 1.2) / (speed * self.speed)
        steps = max(6, int(dur * 125))
        wob_f, wob_a = random.uniform(1.5, 3.5), min(3.0, d / 120)
        for i in range(1, steps + 1):
            u = i / steps
            # aceleración y frenado asimétricos (arranca rápido, frena largo)
            s = 1 - (1 - u) ** random.uniform(2.2, 2.6) if u < 1 else 1
            s = min(1.0, s)
            b = lambda p0, p1, p2, p3: (1 - s) ** 3 * p0 + 3 * (1 - s) ** 2 * s * p1 + 3 * (1 - s) * s * s * p2 + s ** 3 * p3
            px, py = b(x0, c1[0], c2[0], x1), b(y0, c1[1], c2[1], y1)
            w = math.sin(u * math.pi * wob_f) * wob_a * (1 - u)
            self._put(px + nx * w + random.uniform(-0.6, 0.6), py + ny * w + random.uniform(-0.6, 0.6))
            time.sleep(dur / steps)

    def fidget(self, n=3):
        """Movimientos chicos e irregulares (como cuando uno 'mira' algo)."""
        for _ in range(n):
            self.move(self.x + random.uniform(-60, 60), self.y + random.uniform(-40, 40), speed=random.uniform(0.7, 1.3))
            time.sleep(random.uniform(0.05, 0.3) / self.speed)

    def click(self, btn=BTN_LEFT):
        time.sleep(random.uniform(0.04, 0.12))
        self._ev(self.m, EV_KEY, btn, 1); self._syn(self.m)
        time.sleep(random.uniform(0.06, 0.12))
        self._ev(self.m, EV_KEY, btn, 0); self._syn(self.m)

    def scroll(self, n):
        for _ in range(abs(n)):
            self._ev(self.m, EV_REL, REL_WHEEL, 1 if n > 0 else -1); self._syn(self.m)
            time.sleep(random.uniform(0.04, 0.10))

    def key(self, combo, hold=None):
        """combo como 'super+space' o 'enter'."""
        ks = [K[p] for p in combo.split('+')]
        for k in ks:
            self._ev(self.k, EV_KEY, k, 1); self._syn(self.k); time.sleep(0.015)
        time.sleep(hold if hold else random.uniform(0.05, 0.10))
        for k in reversed(ks):
            self._ev(self.k, EV_KEY, k, 0); self._syn(self.k); time.sleep(0.01)

    def type(self, text, wpm=320):
        base = 60 / (wpm * 5)
        for ch in text:
            if ch == ' ': self.key('space')
            elif ch.isupper(): self.key('shift+' + ch.lower())
            else: self.key(ch)
            time.sleep(base * random.uniform(0.5, 1.8) + (0.12 if random.random() < 0.06 else 0))

    def close(self):
        for fd in (self.m, self.k):
            fcntl.ioctl(fd, UI_DEV_DESTROY); os.close(fd)
