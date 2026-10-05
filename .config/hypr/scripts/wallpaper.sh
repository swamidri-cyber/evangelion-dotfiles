#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  wallpaper.sh — maneja el fondo de pantalla
#
#    wallpaper.sh restore         → pone el último fondo elegido (al iniciar sesión)
#    wallpaper.sh set <imagen>    → fondo estático (awww) con transición, y lo recuerda
#    wallpaper.sh we <id>         → fondo animado de Wallpaper Engine (linux-wallpaperengine)
#    wallpaper.sh list            → lista todo para el menú: "ruta-o-we:id<TAB>nombre"
#    wallpaper.sh preview <item>  → ruta de la imagen de vista previa de un ítem
#    wallpaper.sh pick            → menú para elegir (Super+Shift+W)
#
#  Fondos estáticos: ~/Imágenes/wallpapers (o la carpeta de tu idioma)
#  Fondos animados:  los que estés suscrito en el Workshop de Wallpaper Engine
#                    (hace falta tener Wallpaper Engine comprado en Steam: de ahí
#                    salen los recursos; NO hace falta abrir la app de Windows)
#  El último elegido se guarda en ~/.local/state/rice/wallpaper
#
#  Ahorro de recursos: el fondo animado se congela (SIGSTOP) cuando el
#  escritorio actual tiene ventanas que lo tapan, y sigue (SIGCONT) cuando
#  queda vacío. Eso lo decide Hyprland en config/wallpaper.lua.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

WALL_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/wallpapers"
WE_DIR="$HOME/.local/share/Steam/steamapps/workshop/content/431960"
WE_ASSETS="$HOME/.local/share/Steam/steamapps/common/wallpaper_engine/assets"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rice/wallpaper"
DEFAULT="$WALL_DIR/alas-ambar.png"
WE_FPS=30          # tope de cuadros por segundo del fondo animado
mkdir -p "$(dirname "$STATE")"

# Espera a que el demonio de awww esté listo (máx. ~5 s)
wait_daemon() {
    for _ in $(seq 1 50); do awww query >/dev/null 2>&1 && return 0; sleep 0.1; done
    return 1
}

# Corta el fondo animado si hay uno (primero lo descongela para que muera limpio)
stop_we() {
    pkill -CONT -x linux-wallpaper 2>/dev/null
    pkill -x linux-wallpaper 2>/dev/null
}

set_wall() {
    local img="$1"
    [ -f "$img" ] || { echo "No existe: $img" >&2; return 1; }
    wait_daemon || { echo "awww-daemon no responde" >&2; return 1; }
    stop_we
    # Transición tipo "encendido de monitor" desde el centro
    awww img "$img" --transition-type grow --transition-pos center \
        --transition-duration 1.2 --transition-fps 60
    echo "$img" > "$STATE"
}

set_we() {
    local id="$1"
    [ -d "$WE_DIR/$id" ] || { echo "No estás suscrito a $id" >&2; return 1; }
    command -v linux-wallpaperengine >/dev/null || { echo "Falta linux-wallpaperengine" >&2; return 1; }
    stop_we
    # Debajo queda su vista previa en awww: se ve mientras carga y si se cae
    local prev; prev=$(preview_of "we:$id")
    [ -n "$prev" ] && wait_daemon && awww img "$prev" --transition-type grow \
        --transition-pos center --transition-duration 1.2 --transition-fps 60
    # Un fondo por cada monitor conectado
    local args=()
    for mon in $(hyprctl monitors -j | jq -r '.[].name'); do
        args+=(--screen-root "$mon" --bg "$id" --scaling fill)
    done
    # --silent: sin sonido propio (los audio-reactivos igual escuchan lo que suena)
    setsid -f linux-wallpaperengine --assets-dir "$WE_ASSETS" --fps "$WE_FPS" \
        --silent "${args[@]}" >/dev/null 2>&1 </dev/null
    echo "we:$id" > "$STATE"
    # Que Hyprland decida enseguida si hay que congelarlo (ver config/wallpaper.lua)
    sleep 2; hyprctl dispatch rice_wallpaper_refresh >/dev/null 2>&1
}

# Imagen de vista previa de un ítem (para el menú y como respaldo en awww)
preview_of() {
    case "$1" in
        we:*) find "$WE_DIR/${1#we:}" -maxdepth 1 -iname 'preview.*' | head -n1 ;;
        *)    echo "$1" ;;
    esac
}

list_all() {
    # Estáticos: ruta<TAB>壁 nombre
    find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' \
        -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) -printf '%p\t壁 %f\n' | sort -t$'\t' -k2
    # Animados: we:id<TAB>動 título (solo escenas y videos: los "web" no andan bien)
    [ -d "$WE_DIR" ] || return 0
    for d in "$WE_DIR"/*/; do
        [ -f "$d/project.json" ] || continue
        jq -r --arg id "$(basename "$d")" \
            'select((.type // "" | ascii_downcase) | test("scene|video"))
             | "we:\($id)\t動 \(.title // $id)"' "$d/project.json" 2>/dev/null
    done | sort -t$'\t' -k2
}

case "${1:-restore}" in
    restore)
        cur=$(cat "$STATE" 2>/dev/null || true)
        case "$cur" in
            we:*) set_we "${cur#we:}" || set_wall "$DEFAULT" ;;
            *)    [ -f "${cur:-}" ] || cur="$DEFAULT"; set_wall "$cur" ;;
        esac ;;
    set)     set_wall "${2:?Falta la ruta de la imagen}" ;;
    we)      set_we "${2:?Falta el id del Workshop}" ;;
    list)    list_all ;;
    preview) preview_of "${2:?Falta el ítem}" ;;
    pick)
        # Se abre en una ventanita flotante "rice-float" con fzf
        exec "$HOME/.config/hypr/scripts/menu.sh" wallpaper ;;
    *)
        echo "Uso: $0 restore | set <imagen> | we <id> | list | preview <ítem> | pick" >&2; exit 1 ;;
esac
