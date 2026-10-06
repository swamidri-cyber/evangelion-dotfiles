#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  keytick.py — sonido suave al escribir, en todo el sistema (autostart.lua).
#
#  Lee los teclados (/dev/input/event*, solo los que tienen letras: no el
#  control ni el mouse) y por cada tecla apretada mezcla un "thock" en un
#  único canal de audio abierto con pw-cat (sin demora por proceso nuevo).
#  Mantener apretada una tecla no repite el sonido.
#
#  Necesita leer el teclado: el usuario tiene que estar en el grupo "input"
#  (sudo usermod -aG input $USER y volver a iniciar sesión). Sin permiso,
#  espera en silencio y reintenta.
#
#  Ajustes (~/.config/rice-sound/settings.json): "enabled" (Super+F10 silencia
#  todo) y "typing" (volumen 0..1, 0 = apagado).
# ─────────────────────────────────────────────────────────────────────────────
import json, os, random, re, select, struct, subprocess, sys, time, wave

DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS = os.path.join(DIR, 'settings.json')
RATE = 44100
CHUNK = 256                      # ~6 ms por bloque: poca demora
EVENT = struct.Struct('llHHi')
EV_KEY = 0x01
KEY_A, KEY_SPACE, KEY_ENTER, KEY_KPENTER, KEY_BACKSPACE = 30, 57, 28, 96, 14

def load(name):
    with wave.open(os.path.join(DIR, 'sfx', name + '.wav')) as w:
        data = w.readframes(w.getnframes())
    return list(struct.unpack('<%dh' % (len(data) // 2), data))

SOUNDS = {n: load(n) for n in ('key1', 'key2', 'key3', 'space', 'enter', 'bksp')}

def keyboards():
    """event* de dispositivos con tecla A (teclados de verdad)."""
    found = []
    try:
        blocks = open('/proc/bus/input/devices').read().split('\n\n')
    except OSError:
        return found
    for b in blocks:
        h = re.search(r'H: Handlers=.*\b(event\d+)', b)
        k = re.search(r'B: KEY=([0-9a-f ]+)', b)
        if not h or not k:
            continue
        words = k.group(1).split()[::-1]           # palabra menos significativa primero
        bits = 64 if sys.maxsize > 2**32 else 32
        w, bit = divmod(KEY_A, bits)
        if w < len(words) and int(words[w], 16) >> bit & 1:
            found.append('/dev/input/' + h.group(1))
    return found

def settings():
    try:
        c = json.load(open(SETTINGS))
    except Exception:
        c = {}
    return bool(c.get('enabled', True)), float(c.get('typing', 0.25))

def main():
    player = subprocess.Popen(['pw-cat', '--playback', '--rate', str(RATE), '--channels', '1',
                               '--format', 's16', '--latency', '12ms',
                               '--media-role', 'Notification', '-'],
                              stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    fds, last_scan, last_cfg = {}, 0, 0
    enabled, vol = settings()
    voices = []                                    # [muestras, posición, volumen]
    silence = b'\0' * (CHUNK * 2)
    while True:
        now = time.monotonic()
        if now - last_scan > 3:                    # teclados nuevos / permisos
            last_scan = now
            for p in keyboards():
                if p not in fds:
                    try:
                        fds[p] = os.open(p, os.O_RDONLY | os.O_NONBLOCK)
                    except OSError:
                        pass
        if now - last_cfg > 2:
            last_cfg = now
            enabled, vol = settings()
        r = []
        if fds:
            try:
                r, _, _ = select.select(list(fds.values()), [], [], 0)
            except (OSError, ValueError):
                r = []
        for fd in r:
            try:
                data = os.read(fd, EVENT.size * 64)
            except OSError:                        # teclado desconectado
                for p, f in list(fds.items()):
                    if f == fd:
                        os.close(f); del fds[p]
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, typ, code, val = EVENT.unpack_from(data, i)
                if typ == EV_KEY and val == 1 and enabled and vol > 0:
                    name = ('space' if code == KEY_SPACE else
                            'enter' if code in (KEY_ENTER, KEY_KPENTER) else
                            'bksp' if code == KEY_BACKSPACE else
                            random.choice(('key1', 'key2', 'key3')))
                    voices.append([SOUNDS[name], 0, vol * random.uniform(0.85, 1.0)])
        # Mezclar un bloque (o silencio) y mandarlo: pw-cat marca el ritmo
        if voices:
            buf = [0.0] * CHUNK
            for v in voices:
                s, pos, g = v
                n = min(CHUNK, len(s) - pos)
                for j in range(n):
                    buf[j] += s[pos + j] * g
                v[1] += n
            voices = [v for v in voices if v[1] < len(v[0])]
            out = struct.pack('<%dh' % CHUNK, *(max(-32767, min(32767, int(x))) for x in buf))
        else:
            out = silence
        try:
            player.stdin.write(out); player.stdin.flush()
        except BrokenPipeError:
            time.sleep(1)
            return main()                          # se cayó pw-cat: reabrir

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
