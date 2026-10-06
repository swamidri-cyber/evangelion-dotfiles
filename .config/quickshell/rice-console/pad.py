#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  pad.py — lee los controles (Xbox por cable o Bluetooth) y escribe por stdout
#  una línea por acción, para rice-console (Quickshell la lee con un Process):
#
#     nav up|down|left|right     (cruceta o stick izquierdo, con autorrepetición)
#     press a|b|x|y|lb|rb|lt|rt|view|menu|guide|ls|rs
#     pad connected <nombre> / pad disconnected
#
#  Sin dependencias: lee /dev/input/event* directamente (formato input_event).
#  No "agarra" el control: los juegos lo siguen recibiendo normal.
# ─────────────────────────────────────────────────────────────────────────────
import fcntl, os, re, select, struct, sys, time

EV_KEY, EV_ABS = 0x01, 0x03
EVENT = struct.Struct('llHHi')          # timeval (2 longs), type, code, value
BUTTONS = {0x130: 'a', 0x131: 'b', 0x133: 'x', 0x134: 'y', 0x136: 'lb', 0x137: 'rb',
           0x13a: 'view', 0x13b: 'menu', 0x13c: 'guide', 0x13d: 'ls', 0x13e: 'rs'}
ABS_X, ABS_Y, ABS_Z, ABS_RZ, HAT_X, HAT_Y = 0x00, 0x01, 0x02, 0x05, 0x10, 0x11
REPEAT_DELAY, REPEAT_EVERY = 0.38, 0.11  # autorrepetición al mantener (s)

def out(line):
    sys.stdout.write(line + '\n'); sys.stdout.flush()

def joysticks():
    """event* de los dispositivos que el kernel marca como joystick (handler js)."""
    found = {}
    try:
        blocks = open('/proc/bus/input/devices').read().split('\n\n')
    except OSError:
        return found
    for b in blocks:
        h = re.search(r'H: Handlers=(.*)', b)
        n = re.search(r'N: Name="(.*)"', b)
        if h and re.search(r'\bjs\d+', h.group(1)):
            ev = re.search(r'\b(event\d+)', h.group(1))
            if ev:
                found['/dev/input/' + ev.group(1)] = n.group(1) if n else '?'
    return found

def absrange(fd, code):
    """Mínimo y máximo de un eje (ioctl EVIOCGABS → struct input_absinfo)."""
    req = (2 << 30) | (24 << 16) | (ord('E') << 8) | (0x40 + code)
    try:
        _, lo, hi, _, _, _ = struct.unpack('6i', fcntl.ioctl(fd, req, bytes(24)))
        return (lo, hi) if hi > lo else (-32768, 32767)
    except OSError:
        return (-32768, 32767)

class Pad:
    def __init__(self, path, name):
        self.fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        self.name = name
        self.range = {c: absrange(self.fd, c) for c in (ABS_X, ABS_Y, ABS_Z, ABS_RZ)}
        self.dir = {'x': None, 'y': None}       # dirección actual por eje
        self.src = {'stick': [0, 0], 'hat': [0, 0]}
        self.trig = {'lt': False, 'rt': False}

    def axis_dir(self):
        hx, hy = self.src['hat']; sx, sy = self.src['stick']
        x = hx or (1 if sx > 0.55 else -1 if sx < -0.55 else 0)
        y = hy or (1 if sy > 0.55 else -1 if sy < -0.55 else 0)
        return x, y

class Repeater:
    """Dirección mantenida → primera pulsación, pausa, y después repetición."""
    def __init__(self):
        self.held = None; self.next = 0
    def set(self, d):
        if d != self.held:
            self.held = d
            if d:
                out('nav ' + d); self.next = time.monotonic() + REPEAT_DELAY
    def tick(self):
        if self.held and time.monotonic() >= self.next:
            out('nav ' + self.held); self.next = time.monotonic() + REPEAT_EVERY

def main():
    pads, rep, last_scan = {}, Repeater(), 0
    while True:
        if time.monotonic() - last_scan > 2:   # control nuevo / desconectado
            last_scan = time.monotonic()
            now = joysticks()
            for p in list(pads):
                if p not in now:
                    os.close(pads.pop(p).fd); out('pad disconnected')
            for p, n in now.items():
                if p not in pads:
                    try:
                        pads[p] = Pad(p, n); out('pad connected ' + n)
                    except OSError:
                        pass
        r, _, _ = select.select([p.fd for p in pads.values()], [], [], 0.05)
        for pad in [p for p in pads.values() if p.fd in r]:
            try:
                data = os.read(pad.fd, EVENT.size * 64)
            except OSError:
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, typ, code, val = EVENT.unpack_from(data, i)
                if typ == EV_KEY and code in BUTTONS and val == 1:
                    out('press ' + BUTTONS[code])
                elif typ == EV_ABS:
                    if code in (HAT_X, HAT_Y):
                        pad.src['hat'][code - HAT_X] = val
                    elif code in (ABS_X, ABS_Y):
                        lo, hi = pad.range[code]   # normalizado a -1..1
                        pad.src['stick'][code] = (val - lo) / (hi - lo) * 2 - 1
                    elif code in (ABS_Z, ABS_RZ):
                        t = 'lt' if code == ABS_Z else 'rt'
                        lo, hi = pad.range[code]
                        down = (val - lo) / (hi - lo) > 0.4
                        if down and not pad.trig[t]:
                            out('press ' + t)
                        pad.trig[t] = down
                    x, y = pad.axis_dir()
                    rep.set({(0, -1): 'up', (0, 1): 'down', (-1, 0): 'left', (1, 0): 'right'}.get(
                        (0, y) if y else (x, 0), None) if (x or y) else None)
        rep.tick()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
