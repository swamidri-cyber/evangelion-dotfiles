#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  make-boot-sounds.py — sonidos del arranque MAGI (rice-boot), versión "PC
#  vieja": sucios, graves, con zumbido de línea, chasquidos y saturación.
#  Solo Python estándar. Salida: ~/.config/rice-sound/sfx/boot-*.wav
#
#    boot-power.wav  (6,4 s, ventilador y zumbido de fondo todo el arranque) interruptor + desmagnetizado del tubo (BWOOM) + chisporroteo
#                    de alta tensión + ventilador/disco arrancando + clics de
#                    cabezal + un bip de POST grave por un parlantito
#    boot-vote.wav   relé que cierra + bip grave sucio (cada voto)
#    boot-ok.wav     acorde grave de onda cuadrada, como de placa de sonido vieja
#    boot-out.wav    chasquido del tubo + estática que se va (la pantalla se abre)
#
#  Volver a generar:  python3 make-boot-sounds.py
# ─────────────────────────────────────────────────────────────────────────────
import math, os, random, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sfx')
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(1997)

def write(name, x, vol=0.9):
    peak = max(1e-6, max(abs(v) for v in x))
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(v / peak * vol * 32000)) for v in x))
    print('  ', name, f'{len(x) / RATE:.2f} s')

def silence(secs): return [0.0] * int(secs * RATE)

def put(dst, src, at, gain=1.0):
    i0 = int(at * RATE)
    if len(dst) < i0 + len(src): dst.extend([0.0] * (i0 + len(src) - len(dst)))
    for i, v in enumerate(src): dst[i0 + i] += v * gain
    return dst

def lowpass(x, cut):
    al = (1 / RATE) / (1 / (2 * math.pi * cut) + 1 / RATE); y, p = [], 0.0
    for v in x: p += al * (v - p); y.append(p)
    return y

def highpass(x, cut):
    lp = lowpass(x, cut); return [a - b for a, b in zip(x, lp)]

def sat(x, drive):  # saturación de válvula / parlante chico
    return [math.tanh(v * drive) for v in x]

def crush(x, bits=6, hold=4):  # baja resolución + sample-and-hold (placa vieja)
    q = 2 ** (bits - 1); y, last = [], 0.0
    for i, v in enumerate(x):
        if i % hold == 0: last = round(v * q) / q
        y.append(last)
    return y

def noise(n): return [rnd.random() * 2 - 1 for _ in range(n)]

def hum(dur, base=50, amp_env=lambda t: 1.0, wobble=0.0):
    """Zumbido de línea: fundamental + armónicas impares (transformador)."""
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        w = 1 + wobble * math.sin(2 * math.pi * 3.1 * t)
        s = (math.sin(2 * math.pi * base * t) + 0.6 * math.sin(2 * math.pi * base * 2 * t)
             + 0.45 * math.sin(2 * math.pi * base * 3 * t) + 0.25 * math.sin(2 * math.pi * base * 5 * t))
        out.append(s * amp_env(t) * w)
    return out

def click(gain=1.0, cut=2500, dur=0.012, body=90):
    n = int(dur * RATE)
    nz = lowpass(noise(n), cut)
    return [(nz[i] * math.exp(-i / RATE / 0.003) + 0.6 * math.sin(2 * math.pi * body * i / RATE) * math.exp(-i / RATE / 0.02)) * gain
            for i in range(n)] + [0.6 * gain * math.sin(2 * math.pi * body * (n + i) / RATE) * math.exp(-(n + i) / RATE / 0.02) for i in range(int(0.06 * RATE))]

def square(f, dur, vol=1.0, a=0.004, rel=0.03):
    out = []
    for i in range(int(dur * RATE)):
        t = i / RATE
        e = min(1, t / a) * min(1, max(0, dur - t) / rel)
        out.append((1 if math.sin(2 * math.pi * f * t) >= 0 else -1) * e * vol)
    return out

print('Generando sonidos de arranque en', OUT)

# ── Encendido ───────────────────────────────────────────────────────────────
TOTAL = 6.4      # dura todo el arranque (rice-boot: 6,3 s)
FADE_AT = 5.0    # el fondo se apaga junto con la pantalla (fósforo, 5,0 → 6,3 s)
def bed(t):      # envolvente del sonido de fondo: entra rápido, se sostiene, se va al final
    return min(1, t / 0.7) * min(1, max(0.0, 1 - (t - FADE_AT) / (TOTAL - 0.1 - FADE_AT)))
x = silence(TOTAL)
# 1. Interruptor mecánico: ¡chunk!
put(x, click(1.0, cut=1800, body=70), 0.0)
# 2. Desmagnetizado del tubo: BWOOOM grave que tiembla y se apaga
put(x, hum(1.5, 50, lambda t: (min(1, t / 0.015)) * math.exp(-t / 0.42), wobble=0.35), 0.02, 0.55)
# 3. Chisporroteo de alta tensión (crujidos sueltos, sordos)
for _ in range(70):
    at = 0.03 + rnd.random() ** 1.8 * 1.0
    put(x, lowpass(noise(int(0.003 * RATE)), 1500 + rnd.random() * 1500), at, 0.25 + rnd.random() * 0.5)
# 4. Ventilador + motor del disco: soplido grave y un tono de motor que sube
n = int((TOTAL - 0.1) * RATE)
whoosh = lowpass(lowpass(noise(n), 500), 700)
motor, ph = [], 0.0
for i in range(n):
    t = i / RATE
    f = 28 + 85 * (1 - math.exp(-t / 0.9))
    ph += 2 * math.pi * f / RATE
    motor.append(math.sin(ph) + 0.4 * math.sin(2 * ph))
fan = [(whoosh[i] * 2.2 + motor[i] * 0.22) * bed(0.1 + i / RATE) for i in range(n)]
put(x, fan, 0.1, 0.55)
# 5. Clics del cabezal del disco (tac-tac... tac)
for at in (0.95, 1.07, 1.12, 1.55, 1.6, 1.68, 2.3, 2.36, 3.3, 3.36, 4.2, 4.27, 4.32):
    put(x, click(0.32, cut=3000, dur=0.006, body=180), at)
# 6. Bip de POST grave por un parlantito saturado
beep = lowpass(sat(square(560, 0.2, 0.7), 1.5), 1600)
put(x, highpass(beep, 250), 1.35, 0.5)
# Todo pasa por "electrónica vieja": algo de saturación y un poco de zumbido de fondo
x = put(x, hum(TOTAL, 50, lambda t: 0.04 * bed(t)), 0.0)
x = lowpass(sat(x, 1.6), 5000)
write('boot-power.wav', x)

# ── Voto: relé + bip grave sucio ────────────────────────────────────────────
v = silence(0.3)
put(v, click(0.8, cut=2200, dur=0.008, body=120), 0.0)
put(v, lowpass(crush(sat(square(330, 0.16, 0.6), 2.0), bits=5, hold=5), 1400), 0.015, 0.7)
write('boot-vote.wav', lowpass(v, 4000), vol=0.75)

# ── 承認: acorde grave de onda cuadrada con vibrato de cinta ────────────────
dur = 1.2; ok = []
for i in range(int(dur * RATE)):
    t = i / RATE
    wob = 1 + 0.004 * math.sin(2 * math.pi * 5.5 * t)
    s = sum((1 if math.sin(2 * math.pi * f * wob * t) >= 0 else -1) for f in (196.0, 246.9, 293.7)) / 3
    s += 0.5 * math.sin(2 * math.pi * 98 * t)   # octava baja
    ok.append(s * min(1, t / 0.01) * math.exp(-t / 0.45))
ok = lowpass(lowpass(crush(sat(ok, 1.4), bits=6, hold=3), 1300), 1800)
ok = put(ok, click(0.5, cut=2000, body=80), 0.0)
write('boot-ok.wav', ok, vol=0.8)

# ── Salida: chasquido de tubo + estática que se aleja ──────────────────────
dur = 0.9; o = silence(dur)
put(o, click(1.0, cut=1600, body=60), 0.0)
st = lowpass(noise(int(dur * RATE)), 2200)
st = [v * math.exp(-i / RATE / 0.22) for i, v in enumerate(st)]
put(o, st, 0.01, 0.5)
put(o, hum(dur, 50, lambda t: math.exp(-t / 0.25)), 0.0, 0.3)
write('boot-out.wav', lowpass(sat(o, 1.5), 4500), vol=0.8)
