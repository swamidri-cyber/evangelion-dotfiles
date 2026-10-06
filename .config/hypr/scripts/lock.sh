#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  lock.sh — bloquea la pantalla con rice-lock (Quickshell, encendido de tubo).
#  Si rice-lock no llega a bloquear en 4 s, o se cae estando bloqueado,
#  entra hyprlock (misc:allow_session_lock_restore deja que tome el bloqueo).
#  Lo llama hypridle (lock_cmd) → Super+L, inactividad y antes de suspender.
# ─────────────────────────────────────────────────────────────────────────────
pgrep -x hyprlock >/dev/null && exit 0
pgrep -f "bin/qs -c rice-lock|^qs -c rice-lock" >/dev/null && exit 0
RUN="${XDG_RUNTIME_DIR:-/tmp}"
SHOT="$RUN/rice-lock-shot.png"; READY="$RUN/rice-lock-ready"
rm -f "$READY"
grim "$SHOT" 2>/dev/null                    # foto del escritorio (fondo y desbloqueo)
qs -c rice-lock >/dev/null 2>&1 &
QS=$!
for _ in $(seq 1 40); do
    [ -f "$READY" ] && break
    kill -0 "$QS" 2>/dev/null || break
    sleep 0.1
done
if [ ! -f "$READY" ]; then
    kill "$QS" 2>/dev/null
    exec hyprlock
fi
wait "$QS"; rc=$?
rm -f "$READY" "$SHOT"
[ "$rc" -ne 0 ] && exec hyprlock            # se cayó: hyprlock toma el bloqueo
exit 0
