#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  make-sounds.py — sintetiza todos los sonidos del rice (sin samples bajados):
#  bips de interfaz estilo NERV, zumbidos de tubo CRT y la música ambiente.
#  Solo Python estándar. Salida: ~/.config/rice-sound/sfx/*.wav
#  Volver a generar:  python3 make-sounds.py
# ─────────────────────────────────────────────────────────────────────────────
import math, os, random, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sfx')
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(7)

def write(name, samples, rate=RATE, stereo=False):
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for s in samples:
            if stereo:
                l, r = s
                frames += struct.pack('<hh', int(max(-1, min(1, l)) * 32000), int(max(-1, min(1, r)) * 32000))
            else:
                frames += struct.pack('<h', int(max(-1, min(1, s)) * 32000))
        w.writeframes(bytes(frames))
    print('  ', name)

def env(t, a, d, total):
    """Envolvente: ataque a, caída exponencial hasta total (s)."""
    if t < a:
        return t / a
    return math.exp(-(t - a) / d) * max(0.0, 1 - (t - a) / max(1e-6, total - a)) ** 0.3

def tone(freqs, dur, a=0.004, d=0.05, vol=0.3, wave_='sine', glide=0.0):
    n = int(dur * RATE); out = []
    ph = [0.0] * len(freqs)
    for i in range(n):
        t = i / RATE; s = 0.0
        for k, f in enumerate(freqs):
            f2 = f * (1 + glide * t / dur)
            ph[k] += 2 * math.pi * f2 / RATE
            if wave_ == 'sine':
                s += math.sin(ph[k])
            else:  # "square" suave: seno + algo de tercera armónica
                s += math.sin(ph[k]) + 0.3 * math.sin(3 * ph[k])
        out.append(s / len(freqs) * env(t, a, d, dur) * vol)
    return out

def lowpass(x, cut):
    rc = 1 / (2 * math.pi * cut); dt = 1 / RATE; al = dt / (rc + dt)
    y, prev = [], 0.0
    for v in x:
        prev += al * (v - prev); y.append(prev)
    return y

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]

def pad(x, secs):
    return [0.0] * int(secs * RATE) + x

def noise(dur, vol, cut=4000, a=0.002, d=0.03):
    n = int(dur * RATE)
    return lowpass([(rnd.random() * 2 - 1) * env(i / RATE, a, d, dur) * vol for i in range(n)], cut)

print('Generando sonidos en', OUT)

# ── Interfaz ─────────────────────────────────────────────────────────────────
write('nav.wav',    lowpass(tone([1760], 0.045, d=0.012, vol=0.22), 6000))                  # moverse
write('select.wav', mix(tone([1318.5], 0.07, d=0.03, vol=0.25),
                        pad(tone([1975.5], 0.09, d=0.04, vol=0.22), 0.055)))                # elegir (dos tonos)
write('back.wav',   mix(tone([987.8], 0.07, d=0.03, vol=0.22),
                        pad(tone([659.3], 0.09, d=0.04, vol=0.2), 0.05)))                   # volver
write('error.wav',  tone([220, 233], 0.25, d=0.12, vol=0.25, wave_='square'))               # rechazo
write('tick.wav',   noise(0.02, 0.35, cut=3000, d=0.004))                                   # clic seco

# Abrir / cerrar menú: "thunk" de tubo + zumbido que sube (o baja)
def crt_on(dur=0.32, up=True):
    n = int(dur * RATE); out = []; ph = 0.0
    for i in range(n):
        t = i / RATE
        f = (300 + 9000 * (t / dur) ** 2) if up else (9300 - 9000 * (t / dur) ** 0.5)
        ph += 2 * math.pi * f / RATE
        whine = math.sin(ph) * 0.035 * (1 - t / dur)
        thump = math.sin(2 * math.pi * 55 * t) * math.exp(-t / 0.05) * 0.5
        out.append(whine + thump)
    return lowpass(mix(out, noise(dur, 0.12, cut=2500, d=0.06)), 7000)
write('open.wav',  crt_on(up=True))
write('close.wav', crt_on(up=False))

# Abrir una app: burbujita suave
write('app.wav', lowpass(tone([880], 0.12, d=0.05, vol=0.16, glide=0.5), 5000))

# Cambio de canal (escritorios): ráfaga de estática corta
write('channel.wav', mix(noise(0.16, 0.22, cut=5000, a=0.003, d=0.06),
                         tone([15734], 0.16, d=0.06, vol=0.015)))                            # + el pitido del fly-back

# ── Teclado (sonido al escribir): "thock" suave de tecla mecánica ─────────
def key(pitch, vol=0.5, body=0.022, click=0.25):
    n = int(0.06 * RATE); out = []
    for i in range(n):
        t = i / RATE
        thock = math.sin(2 * math.pi * pitch * t) * math.exp(-t / body)
        out.append(thock * vol)
    clk = noise(0.012, click, cut=6000, a=0.0005, d=0.0025)
    return lowpass(mix(out, clk), 5000)
write('key1.wav',  key(190))
write('key2.wav',  key(205, click=0.22))
write('key3.wav',  key(178, click=0.28))
write('space.wav', key(130, vol=0.6, body=0.03, click=0.2))
write('enter.wav', mix(key(150, vol=0.6, body=0.03), pad(key(240, vol=0.25), 0.018)))
write('bksp.wav',  key(160, vol=0.45, body=0.018, click=0.3))

# ── Arranque MAGI ────────────────────────────────────────────────────────────
write('magi-boot.wav', lowpass(mix(crt_on(0.6, True), pad(noise(0.5, 0.06, cut=1500, d=0.3), 0.1)), 6000))
write('magi-vote.wav', tone([1046.5, 2093], 0.16, d=0.06, vol=0.28))                        # cada voto
write('magi-ok.wav',   mix(tone([523.3, 659.3, 784], 0.9, a=0.01, d=0.35, vol=0.22),
                           pad(tone([1046.5], 0.7, a=0.01, d=0.3, vol=0.12), 0.08)))         # 承認

# ── Apagado de tubo ──────────────────────────────────────────────────────────
def crt_off(dur=1.1):
    n = int(dur * RATE); out = []; ph = 0.0
    for i in range(n):
        t = i / RATE
        f = 15734 * math.exp(-t * 2.2) + 80
        ph += 2 * math.pi * f / RATE
        zap = math.sin(ph) * 0.06 * math.exp(-t * 2.5)
        pop = math.sin(2 * math.pi * 70 * t) * math.exp(-t / 0.04) * 0.55
        out.append(zap + pop)
    return lowpass(mix(out, noise(0.3, 0.2, cut=3000, d=0.08)), 6000)
write('off.wav', crt_off())

# ── Música ambiente: drone suave en loop perfecto (60 s, estéreo) ────────────
#  Notas de un acorde menor con novena (La menor add9) en registro grave/medio,
#  cada voz con su "respiración" lenta; frecuencias y LFOs elegidos para que
#  cierren justo a los 60 s y el loop no tenga salto. Un poco de zumbido de
#  tubo (60 Hz + armónicos) y campanitas de vidrio muy de vez en cuando.
AMB_RATE = 22050
LEN = 60.0
N = int(LEN * AMB_RATE)

def snap(f):  # frecuencia con número entero de ciclos en LEN
    return round(f * LEN) / LEN

voices = [  # (frecuencia, volumen, período de respiración en s, paneo -1..1)
    (snap(55.0),    0.20, 30, 0.0),
    (snap(110.0),   0.13, 20, -0.3),
    (snap(130.81),  0.08, 15, 0.35),
    (snap(164.81),  0.07, 12, -0.4),
    (snap(246.94),  0.035, 10, 0.5),
    (snap(110.25),  0.06, 60, 0.3),     # desafinada: batido lento
]
chimes = [(7.5, 1318.5, 0.6), (22.0, 987.8, -0.5), (37.5, 1174.7, 0.2), (51.0, 1568.0, -0.2)]
amb = []
for i in range(N):
    t = i / AMB_RATE
    l = r = 0.0
    for f, v, per, pan in voices:
        breath = 0.55 + 0.45 * math.sin(2 * math.pi * t / per)
        s = math.sin(2 * math.pi * f * t) * v * breath
        l += s * (1 - pan) * 0.5; r += s * (1 + pan) * 0.5
    hum = (math.sin(2 * math.pi * 60 * t) * 0.012 + math.sin(2 * math.pi * 180 * t) * 0.004)
    l += hum; r += hum
    for ct, cf, cpan in chimes:   # campanita: ataque suave, cola larga
        dt = (t - ct) % LEN
        if dt < 4.0:
            e = (dt / 0.02 if dt < 0.02 else math.exp(-(dt - 0.02) / 1.1)) * 0.035
            c = (math.sin(2 * math.pi * cf * dt) + 0.4 * math.sin(2 * math.pi * cf * 2.76 * dt)) * e
            l += c * (1 - cpan) * 0.5; r += c * (1 + cpan) * 0.5
    amb.append((l, r))
# suavizado general (filtro pasa bajos por canal)
def lp2(seq, cut, rate):
    rc = 1 / (2 * math.pi * cut); dt = 1 / rate; al = dt / (rc + dt)
    out, pl, pr = [], 0.0, 0.0
    for a, b in seq:
        pl += al * (a - pl); pr += al * (b - pr); out.append((pl, pr))
    return out
amb = lp2(amb + amb, 2200, AMB_RATE)[N:]   # primera vuelta solo calienta el filtro: loop sin clic
write('ambient.wav', amb, rate=AMB_RATE, stereo=True)
print('listo')
