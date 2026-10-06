# Lector de appcache/appinfo.vdf de Steam (formato binario v28/v29).
# Devuelve {appid: {"name", "type", ...}} con lo que Steam tiene cacheado.
import struct
def _kv(buf, pos, strings):
    out = {}
    while True:
        t = buf[pos]; pos += 1
        if t == 0x08: return out, pos
        if strings is not None:
            key = strings[struct.unpack_from('<I', buf, pos)[0]]; pos += 4
        else:
            e = buf.index(b'\0', pos); key = buf[pos:e].decode('utf-8', 'replace'); pos = e + 1
        if t == 0x00:
            out[key], pos = _kv(buf, pos, strings)
        elif t == 0x01:
            e = buf.index(b'\0', pos); out[key] = buf[pos:e].decode('utf-8', 'replace'); pos = e + 1
        elif t in (0x02, 0x04, 0x06):
            out[key] = struct.unpack_from('<i', buf, pos)[0]; pos += 4
        elif t == 0x03:
            out[key] = struct.unpack_from('<f', buf, pos)[0]; pos += 4
        elif t in (0x07, 0x0a):
            out[key] = struct.unpack_from('<Q', buf, pos)[0]; pos += 8
        else:
            raise ValueError(f"tipo {t:#x} en {pos}")
def load(path):
    buf = open(path, 'rb').read()
    magic, universe = struct.unpack_from('<II', buf, 0)
    strings = None; pos = 8
    if magic == 0x07564429:  # v29: tabla de strings al final
        off = struct.unpack_from('<Q', buf, 8)[0]; pos = 16
        n = struct.unpack_from('<I', buf, off)[0]; p = off + 4; strings = []
        for _ in range(n):
            e = buf.index(b'\0', p); strings.append(buf[p:e].decode('utf-8', 'replace')); p = e + 1
    apps = {}
    while True:
        appid = struct.unpack_from('<I', buf, pos)[0]
        if appid == 0: break
        size = struct.unpack_from('<I', buf, pos + 4)[0]
        start = pos + 8; nxt = start + size
        kvpos = start + 4 + 4 + 8 + 20 + 4 + 20
        try:
            kv, _ = _kv(buf, kvpos, strings)
            common = kv.get('appinfo', {}).get('common', {})
            apps[appid] = common
        except Exception:
            pass
        pos = nxt
    return apps
