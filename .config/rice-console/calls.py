#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  calls.py — ¿estoy en una llamada? Lo usa console.sh antes de pasar a
#  Windows, para que el agente de Windows la reconecte. Imprime JSON o null:
#
#    {"meet": "https://meet.google.com/abc-defg-hij", "discord": {"app": true}}
#
#  · Meet: una pestaña de meet.google.com abierta en Zen (de su sesión,
#    recovery.jsonlz4) MIENTRAS Zen usa el micrófono (PipeWire).
#  · Discord: Vesktop/Discord usando el micrófono. El canal no se puede leer
#    (Discord no lo guarda en disco), así que Windows solo abre Discord.
# ─────────────────────────────────────────────────────────────────────────────
import glob, json, os, re, subprocess

HOME = os.path.expanduser('~')

def lz4_block(src, size):
    """Descompresor LZ4 (formato bloque) mínimo, sin dependencias."""
    out = bytearray(); i = 0
    while i < len(src):
        tok = src[i]; i += 1
        lit = tok >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255: break
        out += src[i:i + lit]; i += lit
        if i >= len(src): break
        off = src[i] | (src[i + 1] << 8); i += 2
        ml = tok & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255: break
        ml += 4
        start = len(out) - off
        for k in range(ml):
            out.append(out[start + k])
    return bytes(out[:size])

def mozlz4(path):
    data = open(path, 'rb').read()
    if data[:8] != b'mozLz40\0':
        raise ValueError('no es mozlz4')
    size = int.from_bytes(data[8:12], 'little')
    return json.loads(lz4_block(data[12:], size))

def mic_apps():
    """Nombres de las apps que están grabando del micrófono ahora."""
    try:
        outs = json.loads(subprocess.run(['pactl', '-f', 'json', 'list', 'source-outputs'],
                                         capture_output=True, text=True, timeout=5).stdout or '[]')
    except Exception:
        return set()
    names = set()
    for o in outs:
        p = o.get('properties', {})
        for k in ('application.name', 'application.process.binary', 'application.id'):
            if p.get(k):
                names.add(p[k].lower())
    return names

def meet_tabs():
    urls = []
    for f in glob.glob(f'{HOME}/.config/zen/*/sessionstore-backups/recovery.jsonlz4'):
        try:
            s = mozlz4(f)
        except Exception:
            continue
        for w in s.get('windows', []):
            for t in w.get('tabs', []):
                ents = t.get('entries', [])
                if ents:
                    u = ents[min(t.get('index', 1), len(ents)) - 1].get('url', '')
                    if re.match(r'https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}', u):
                        urls.append(u.split('?')[0])
    return urls

mics = mic_apps()
call = {}
if any('zen' in n or 'firefox' in n for n in mics):
    tabs = meet_tabs()
    if tabs:
        call['meet'] = tabs[-1]
if any('vesktop' in n or 'discord' in n or 'electron' in n for n in mics):
    call['discord'] = {'app': True}
print(json.dumps(call) if call else 'null')
