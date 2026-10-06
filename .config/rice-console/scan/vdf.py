# Lector mínimo de archivos VDF de Steam (formato texto: "clave" "valor" / "clave" { ... })
import re
_tok = re.compile(r'"((?:[^"\\]|\\.)*)"|([{}])')
def loads(text):
    stack = [{}]; key = None
    for m in _tok.finditer(text):
        s, brace = m.group(1), m.group(2)
        if brace == '{':
            d = {}; stack[-1][key] = d; stack.append(d); key = None
        elif brace == '}':
            stack.pop()
        elif key is None:
            key = s
        else:
            stack[-1][key] = s.replace('\\\\', '\\'); key = None
    return stack[0]
def load(path):
    return loads(open(path, encoding='utf-8', errors='replace').read())
def ci(d, k):
    # acceso sin distinguir mayúsculas (Steam mezcla "Software"/"software")
    for kk, v in d.items():
        if kk.lower() == k.lower(): return v
    return {}
