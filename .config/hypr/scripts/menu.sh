#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  menu.sh — menús flotantes del rice (kitty + fzf, misma estética del lanzador)
#
#    menu.sh clipboard   → historial del portapapeles      (Super+V)
#    menu.sh session     → bloquear / salir / reiniciar…   (Super+Alt+C)
#    menu.sh wallpaper   → elegir wallpaper                (Super+Shift+W)
#
#  Cómo funciona: la primera vez se llama "desde afuera" y abre una ventana
#  kitty con clase "rice-float" (flotante y centrada por windowrules.lua),
#  que vuelve a ejecutar este script con --inside para mostrar el menú.
#  Esc cierra cualquier menú sin hacer nada.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SELF="$(realpath "$0")"

# Opciones de fzf comunes a todos los menús (colores del rice)
FZF_RICE=(
    --ansi --layout=reverse --info=hidden --no-scrollbar --cycle
    --pointer='▌' --marker=' ' --prompt='❯ '
    --color='bg:-1,bg+:#3c3836,fg:#a89984,fg+:#fabd2f,hl:#fe8019,hl+:#fe8019'
    --color='prompt:#fe8019,pointer:#fe8019,header:#d79921,query:#ebdbb2,gutter:-1'
    --bind='esc:abort'
)

# ── Abrir la ventana flotante (o cerrarla si ya hay una abierta) ────────────
if [ "${1:-}" != "--inside" ]; then
    pid=$(hyprctl clients -j | jq -r '.[] | select(.class == "rice-float") | .pid' | head -n1)
    [ -n "$pid" ] && { kill "$pid"; exit 0; }
    exec kitty --class rice-float --title "rice-${1:-menu}" \
        -o background='#1c120a' -o background_opacity=0.72 -o window_padding_width=22 \
        -o cursor_trail=0 -o confirm_os_window_close=0 \
        "$SELF" --inside "${1:-session}"
fi
shift

case "${1:-}" in
    # ── Portapapeles (cliphist) ─────────────────────────────────────────────
    clipboard)
        pick=$(cliphist list | fzf "${FZF_RICE[@]}" \
            --header=$'\n記録 ─ PORTAPAPELES\n' --header-first \
            --delimiter=$'\t' --with-nth=2) || exit 0
        printf '%s' "$pick" | cliphist decode | wl-copy
        ;;

    # ── Sesión ──────────────────────────────────────────────────────────────
    session)
        # Íconos Nerd Font: candado, salir, luna, flechas, power
        pick=$(printf '%s\n' \
            $'\uf023  Bloquear' \
            $'\U000f0343  Cerrar sesión' \
            $'\U000f0904  Suspender' \
            $'\uf021  Reiniciar' \
            $'\uf011  Apagar' \
            | fzf "${FZF_RICE[@]}" --no-input \
                --header=$'\n電源 ─ SESIÓN\n' --header-first) || exit 0
        case "$pick" in
            *Bloquear*)      setsid -f loginctl lock-session ;;
            *"Cerrar sesión"*) setsid -f uwsm stop ;;       # sale de Hyprland limpio (vuelve al login)
            *Suspender*)     setsid -f systemctl suspend ;;
            *Reiniciar*)     setsid -f systemctl reboot ;;
            *Apagar*)        setsid -f systemctl poweroff ;;
        esac
        ;;

    # ── Wallpaper ───────────────────────────────────────────────────────────
    wallpaper)
        # 壁 = estático (awww) · 動 = animado (Wallpaper Engine). A la derecha,
        # la vista previa dibujada por kitty (protocolo de imágenes).
        W="$HOME/.config/hypr/scripts/wallpaper.sh"
        pick=$("$W" list | fzf "${FZF_RICE[@]}" \
            --delimiter=$'\t' --with-nth=2 \
            --header=$'\n壁紙 ─ WALLPAPER   壁 estático · 動 animado\n' --header-first \
            --preview-window='right,62%,border-left' \
            --preview="kitty icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no \
                --place=\${FZF_PREVIEW_COLUMNS}x\${FZF_PREVIEW_LINES}@0x0 \"\$($W preview {1})\" 2>/dev/null" \
            | cut -f1) || exit 0
        case "$pick" in
            we:*) setsid -f "$W" we "${pick#we:}" >/dev/null 2>&1 ;;
            *)    setsid -f "$W" set "$pick" >/dev/null 2>&1 ;;
        esac
        ;;

    *)
        echo "Uso: $0 clipboard | session | wallpaper" >&2; exit 1 ;;
esac
