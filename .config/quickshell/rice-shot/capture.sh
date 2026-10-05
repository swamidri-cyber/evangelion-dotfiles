#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  capture.sh — las capturas del menú Super+Shift+S (rice-shot/shell.qml)
#
#    capture.sh full            → toda la pantalla
#    capture.sh rect            → rectángulo: de una punta a la otra (slurp)
#    capture.sh window          → clic en una ventana del escritorio actual
#    capture.sh freeze ARCHIVO  → foto de la pantalla para el modo lazo
#    capture.sh lasso ARCHIVO "x1,y1 x2,y2 …"  → recorta esa forma de la foto
#
#  Todas terminan en el editor swash (anotar, copiar, guardar), igual que Impr.
#  Esc durante una selección = cancelar sin hacer nada.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

name="swash-$(date +%Y-%m-%d_%H:%M:%S).png"
edit() { swash --stdin --name "$name"; }

# Colores del rice para la selección de slurp: fondo oscurecido, borde ámbar
slurp_rice() { slurp -b '#0d0b0988' -c '#fe8019ff' -s '#fe801918' -B '#fabd2f22' -w 1 "$@"; }

case "${1:-}" in
    full)
        grim - | edit ;;
    rect)
        g=$(slurp_rice) || exit 0
        grim -g "$g" - | edit ;;
    window)
        # Rectángulos de las ventanas visibles del escritorio actual → slurp -r
        # deja elegir una con un clic (se resalta al pasar el mouse).
        ws=$(hyprctl activeworkspace -j | jq '.id')
        g=$(hyprctl clients -j | jq -r --argjson ws "$ws" \
              '.[] | select(.workspace.id == $ws and .hidden == false and .mapped == true)
                   | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | slurp_rice -r) || exit 0
        grim -g "$g" - | edit ;;
    freeze)
        grim "$2" ;;
    lasso)
        # Máscara blanca con la forma dibujada → lo de afuera queda transparente
        # → se recorta al tamaño justo de la forma.
        magick "$2" \( +clone -fill black -colorize 100 -fill white -stroke white -draw "polygon $3" \) \
               -alpha off -compose CopyOpacity -composite -trim +repage png:- | edit
        rm -f "$2" ;;
    *)
        echo "uso: capture.sh full|rect|window|freeze ARCHIVO|lasso ARCHIVO PUNTOS" >&2; exit 1 ;;
esac
