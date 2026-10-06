#!/bin/bash
# Graba los primeros 15 s de la sesión UNA sola vez (si existe la bandera).
# Activar: touch ~/.cache/rice-record-login
FLAG="$HOME/.cache/rice-record-login"
[ -f "$FLAG" ] || exit 0
rm -f "$FLAG"
OUT="$HOME/Vídeos/Grabaciones/inicio-sesion-$(date +%H%M%S).mkv"
setsid wf-recorder -o HDMI-A-1 -f "$OUT" >/tmp/record-login.log 2>&1 &
PID=$!
sleep 15
kill -INT $PID; sleep 3; kill -9 $PID 2>/dev/null
