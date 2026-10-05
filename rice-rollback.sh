#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  rice-rollback.sh — vuelve la config del escritorio al estado del backup.
#
#  Cuándo usarlo: si después de un cambio Hyprland no arranca, la pantalla
#  queda negra o perdiste los atajos.
#
#  Cómo usarlo desde una TTY (sin entorno gráfico):
#     1. Ctrl+Alt+F3  → logueate con tu usuario
#     2. bash ~/rice-rollback.sh            (restaura todo lo del rice)
#        bash ~/rice-rollback.sh hypr       (restaura solo una carpeta)
#     3. Ctrl+Alt+F1 (o reiniciá) y volvé a entrar a Hyprland
#
#  No borra nada: lo que estaba antes de restaurar se mueve a
#  ~/config-broken-<fecha-hora> por si querés recuperar algo.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

BACKUP="$HOME/config-backup-2026-10-04"      # backup tomado antes del rice
BROKEN="$HOME/config-broken-$(date +%F_%H%M%S)"

# Carpetas que el rice modifica (vuelven a como estaban en el backup)
RESTORE=(hypr kitty fish gtk-3.0 gtk-4.0 noctalia uwsm)
# Carpetas que el rice crea desde cero (se apartan para que no interfieran)
CREATED=(waybar swaync fastfetch rice-launcher)

[ -d "$BACKUP" ] || { echo "No encuentro el backup en $BACKUP"; exit 1; }
[ $# -gt 0 ] && RESTORE=("$@") && CREATED=()

mkdir -p "$BROKEN"
for d in "${RESTORE[@]}" "${CREATED[@]}"; do
    [ -e "$HOME/.config/$d" ] && mv "$HOME/.config/$d" "$BROKEN/"
done
for d in "${RESTORE[@]}"; do
    [ -e "$BACKUP/$d" ] && cp -a "$BACKUP/$d" "$HOME/.config/"
done

echo "Restaurado: ${RESTORE[*]}"
echo "Estado anterior guardado en: $BROKEN"
# Si Hyprland está corriendo, que recargue la config restaurada
command -v hyprctl >/dev/null && hyprctl reload 2>/dev/null || true
