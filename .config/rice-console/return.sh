#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  return.sh — al iniciar sesión en Linux (autostart.lua): si venimos de un
#  viaje a Windows del modo consola con una llamada en curso, la reabre:
#  Meet en el navegador, Discord (Vesktop). Lo usa una sola vez por viaje.
# ─────────────────────────────────────────────────────────────────────────────
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rice-console"
f="$STATE/to-windows.json"
[ -f "$f" ] || exit 0
age=$(( $(date +%s) - $(stat -c %Y "$f") ))
mv "$f" "$STATE/to-windows.done.json"
[ "$age" -lt 43200 ] || exit 0          # más de 12 h: era un viaje viejo

sleep 6                                  # que termine de arrancar el escritorio
meet=$(python3 -c 'import json,sys; c=(json.load(open(sys.argv[1])).get("call") or {}); print(c.get("meet",""))' "$STATE/to-windows.done.json" 2>/dev/null)
discord=$(python3 -c 'import json,sys; c=(json.load(open(sys.argv[1])).get("call") or {}); print("1" if c.get("discord") else "")' "$STATE/to-windows.done.json" 2>/dev/null)
[ -n "$meet" ]    && setsid -f uwsm app -- xdg-open "$meet" </dev/null >/dev/null 2>&1
[ -n "$discord" ] && setsid -f uwsm app -- vesktop </dev/null >/dev/null 2>&1
if [ -n "$meet$discord" ]; then
    notify-send -a "Modo consola" "De vuelta en Linux" "Reabrí tu llamada: ${meet:+Meet }${discord:+Discord}" 2>/dev/null
fi
