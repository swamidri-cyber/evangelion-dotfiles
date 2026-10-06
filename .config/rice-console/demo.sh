#!/usr/bin/env bash
# Graba 6 demos del modo consola, una por fondo.
OUT="$HOME/Vídeos/Grabaciones"
# Que no se bloquee la pantalla mientras graba
[ -z "${INHIBITED:-}" ] && exec env INHIBITED=1 systemd-inhibit --what=idle --who=rice-demo --why="grabando demos" bash "$0" "$@"
# Si la sesión está bloqueada no tiene sentido grabar
pgrep -x hyprlock >/dev/null && { echo "pantalla bloqueada: desbloqueá y volvé a correr"; exit 1; }
mkdir -p "$OUT"
q() { timeout 5 qs -c rice-console ipc call console "$@" >/dev/null; }
k() { for x in "$@"; do q key "$x"; sleep 0.45; done; }   # teclas con ritmo humano
cur() { hyprctl dispatch "hl.dsp.cursor.move({x=$1,y=$2})" >/dev/null; }
glide() {  # mueve el mouse suave de (x1,y1) a (x2,y2) en n pasos
    local x1=$1 y1=$2 x2=$3 y2=$4 n=${5:-25}
    for i in $(seq 0 $n); do cur $(( x1 + (x2 - x1) * i / n )) $(( y1 + (y2 - y1) * i / n )); sleep 0.03; done
}
rec_start() { wf-recorder -c libx264 -r 30 -p preset=veryfast -p crf=20 -f "$OUT/$1" >/dev/null 2>&1 & REC=$!; sleep 1; }
rec_stop()  { sleep 1; kill -INT $REC; wait $REC 2>/dev/null; }
open_wall() { cur 1915 1075; q openWall "$1"; sleep 3.6; }
close_mode() { q close; sleep 1.2; }

# 1 — recientes con el control
rec_start modo-consola-1-angel.mp4
open_wall 0
k right right right right right right; sleep 1
k left left left; sleep 1
k a; sleep 1.2; k right right; sleep 0.8; k left left; sleep 0.8; k b; sleep 1
k right right; k a; sleep 1.5; k b; sleep 1
close_mode
rec_stop

# 2 — biblioteca: filtros y orden
rec_start modo-consola-2-sin-cara.mp4
open_wall 1
k rb; sleep 1.5
k right right right down down left; sleep 1
k x; sleep 1.2; k x; sleep 1.2; k x; sleep 1.2; k x; sleep 1.2; k x; sleep 1.2; k x; sleep 1.2; k x; sleep 1
k y; sleep 1.5; k down down down right right; sleep 1.2; k y; sleep 1.2
k a; sleep 1.5; k b; k lb; sleep 1.2
close_mode
rec_stop

# 3 — todo con el mouse
rec_start modo-consola-3-rei.mp4
open_wall 2
glide 1915 1075 195 730 30; sleep 0.6
glide 195 730 1140 730 60; sleep 0.8
glide 1140 730 670 730 30; sleep 0.6
hyprctl dispatch 'hl.dsp.cursor.move({x=670,y=730})' >/dev/null
q key a; sleep 1.2                                 # (clic: abre el menú)
glide 670 730 200 995 20; sleep 0.6; glide 200 995 420 995 15; sleep 0.8
q key b; sleep 0.8
glide 420 995 1020 82 25; sleep 0.4; q go library; sleep 1.5
glide 1020 82 300 400 25; glide 300 400 1500 650 50; sleep 0.8
q go recent; sleep 1
close_mode
rec_stop

# 4 — VALORANT: pasar a Windows (y cancelar)
rec_start modo-consola-4-verde1.mp4
open_wall 3
k right; sleep 1.2
k a; sleep 1.5
k a; sleep 2.5                                     # aparece el cartel (CANCELAR por defecto)
k left; sleep 1.2; k right; sleep 1.2; k left; sleep 1.2
k b; sleep 1.2; k b; sleep 1
close_mode
rec_stop

# 5 — juego no instalado: opciones de instalar
rec_start modo-consola-5-verde2.mp4
open_wall 4
k right right right right right right right; sleep 1.2
k a; sleep 1.5; k right; sleep 1; k right; sleep 1; k right; sleep 1; k b; sleep 1
k rb; sleep 1.2; k x; sleep 1.2; k down down right; sleep 1; k a; sleep 1.5; k right; sleep 1; k b; sleep 1
close_mode
rec_stop

# 6 — recorrida rápida + cerrar y volver a abrir
rec_start modo-consola-6-verde3.mp4
open_wall 5
k right right right right; k rb; sleep 0.8; k down right right; sleep 0.8; k lb; sleep 0.8
close_mode; sleep 1
open_wall 5
k right right; k a; sleep 1.2; k b; sleep 0.8
close_mode
rec_stop

cur 960 540
ls -la "$OUT"/modo-consola-*.mp4
