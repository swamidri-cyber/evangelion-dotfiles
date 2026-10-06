#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  console.sh — lo que hace el modo consola al elegir "JUGAR"/"INSTALAR".
#
#   console.sh linux   <uri>      abre el juego en Linux (Steam: steam://…)
#   console.sh windows <json>     guarda el pedido, anota la llamada en curso
#                                 (Meet / Discord) y reinicia en Windows con
#                                 rice-to-windows (helper root, ver PENDIENTES)
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rice-console"
mkdir -p "$STATE"

case "${1:-}" in
linux)
    uri="${2:?falta la uri}"
    case "$uri" in
        steam://*) exec setsid -f uwsm app -- steam "$uri" </dev/null >/dev/null 2>&1 ;;
        *)         exec setsid -f uwsm app -- xdg-open "$uri" </dev/null >/dev/null 2>&1 ;;
    esac
    ;;
windows)
    req="${2:?falta el pedido}"
    # Llamada en curso: la detecta calls.py (si existe) para que Windows reconecte
    call='null'
    if [ -x "$HOME/.config/rice-console/calls.py" ]; then
        call=$("$HOME/.config/rice-console/calls.py" 2>/dev/null || echo null)
    fi
    printf '{"request": %s, "call": %s, "from": "linux", "time": %s}\n' \
        "$req" "${call:-null}" "$(date +%s)" > "$STATE/to-windows.json"
    if ! command -v rice-to-windows >/dev/null; then
        rm -f "$STATE/to-windows.json"
        echo "falta instalar rice-to-windows (ver ~/.config/rice-console/PENDIENTES.md)" >&2
        exit 2
    fi
    # sudo -n: sin pedir contraseña (regla de sudoers de PENDIENTES.md).
    # Primero se verifica que esté permitido; recién ahí la pantalla se apaga
    # como un tubo (crt-off.sh) y el ayudante reinicia en Windows.
    if ! sudo -n -l /usr/local/bin/rice-to-windows >/dev/null 2>&1; then
        rm -f "$STATE/to-windows.json"
        echo "falta la regla de sudo para rice-to-windows (ver PENDIENTES.md)" >&2
        exit 3
    fi
    exec "$HOME/.config/hypr/scripts/crt-off.sh" run sh -c \
        'sudo -n /usr/local/bin/rice-to-windows "$1" || { rm -f "$1"; exit 1; }' sh "$STATE/to-windows.json"
    ;;
*)
    echo "uso: console.sh linux <uri> | windows <json>" >&2
    exit 1
    ;;
esac
