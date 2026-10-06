#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  crt-off.sh — apaga la pantalla como un tubo CRT y después corre la acción.
#    crt-off.sh poweroff | reboot | logout | test
#    crt-off.sh run <comando…>     (lo usa el modo consola para pasar a Windows)
#  "test" solo muestra la animación y vuelve todo como estaba.
# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
    poweroff) cmd="systemctl poweroff" ;;
    reboot)   cmd="systemctl reboot" ;;
    logout)   cmd="uwsm stop" ;;
    test)     cmd="" ;;
    run)      shift; cmd="$(printf '%q ' "$@")" ;;
    *) echo "uso: crt-off.sh poweroff|reboot|logout|test|run <cmd…>" >&2; exit 1 ;;
esac
RICE_OFF_CMD="$cmd" setsid -f qs -c rice-off </dev/null >/dev/null 2>&1
