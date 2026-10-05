#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  record.sh — grabar la pantalla (Super+Shift+D) con interruptor de micrófono
#
#    record.sh toggle   → empezar / terminar la grabación
#    record.sh mic      → prender / apagar el micrófono (sin cortar la grabación)
#    record.sh status   → para la waybar: "● REC 01:23" (vacío si no graba)
#    record.sh micstatus→ para la waybar: "MIC" prendido/apagado
#
#  Audio: se arma una mezcla propia ("rice_rec") que junta el sonido del
#  sistema + el micrófono. Apagar el micrófono silencia solo esa entrada de la
#  mezcla: no lo mutea en Discord ni en otras apps. Arranca con el micrófono
#  APAGADO (por privacidad); se prende con un clic en "MIC" de la waybar.
#
#  Videos: ~/Vídeos/Grabaciones/grabacion-AAAA-MM-DD_HH-MM-SS.mp4
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

RUN="${XDG_RUNTIME_DIR:-/tmp}/rice-rec"     # estado de la grabación en curso
OUT_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Grabaciones"
mkdir -p "$RUN"

recording() { [ -f "$RUN/pid" ] && kill -0 "$(cat "$RUN/pid")" 2>/dev/null; }
waybar_refresh() { pkill -RTMIN+8 -x waybar 2>/dev/null; }   # actualiza los indicadores al toque

# Entrada de la mezcla que corresponde a un loopback cargado (mod_mic / mod_sys)
input_of() {
    local mod; mod=$(cat "$RUN/$1" 2>/dev/null) || return 1
    # (con PipeWire, la columna "módulo" de la lista corta no coincide: se usa el JSON)
    pactl -f json list sink-inputs | jq -r --arg m "$mod" '.[] | select(.owner_module == $m) | .index' | head -n1 | grep .
}
mic_input() { input_of mod_mic; }

# Descarga la mezcla rice_rec (y lo que haya quedado colgado de un intento fallido)
unload_mix() {
    for m in mod_mic mod_sys mod_sink; do
        [ -f "$RUN/$m" ] && pactl unload-module "$(cat "$RUN/$m")" 2>/dev/null
    done
    pactl list modules short | awk '/rice_rec/ {print $1}' | xargs -r -n1 pactl unload-module 2>/dev/null
}

start() {
    if ! command -v wf-recorder >/dev/null; then
        notify-send -u critical -a "Grabación" -i dialog-error "No se puede grabar" \
            "Falta wf-recorder: sudo pacman -S wf-recorder"
        exit 1
    fi
    unload_mix
    mkdir -p "$OUT_DIR"
    local file="$OUT_DIR/grabacion-$(date +%Y-%m-%d_%H-%M-%S).mp4"
    local sink src
    sink=$(pactl get-default-sink); src=$(pactl get-default-source)
    # Si EasyEffects está andando, grabar el micrófono ya procesado (sin ruido, ecualizado)
    pactl list sources short | grep -q $'\teasyeffects_source\t' && src=easyeffects_source

    # Mezcla: sistema + micrófono → rice_rec
    pactl load-module module-null-sink sink_name=rice_rec \
        sink_properties=device.description=Grabacion-del-rice > "$RUN/mod_sink"
    pactl load-module module-loopback source="$sink.monitor" sink=rice_rec latency_msec=30 > "$RUN/mod_sys"
    pactl load-module module-loopback source="$src" sink=rice_rec latency_msec=30 source_dont_move=true > "$RUN/mod_mic"
    sleep 0.3
    # Estado inicial explícito: WirePlumber "recuerda" el mute de cada flujo por
    # nombre y a veces le aplica al sonido del sistema el mute de una grabación vieja.
    local si; si=$(input_of mod_sys) && pactl set-sink-input-mute "$si" 0  # sistema: prendido
    local mi; mi=$(mic_input)        && pactl set-sink-input-mute "$mi" 1  # micrófono: apagado
    echo off > "$RUN/mic"

    # setsid: que no muera junto con quien lo lanzó (terminal, waybar, etc.)
    setsid wf-recorder --audio=rice_rec.monitor -f "$file" < /dev/null > "$RUN/log" 2>&1 &
    echo $! > "$RUN/pid"
    sleep 0.6
    if ! recording; then          # wf-recorder se cayó al arrancar: no mentir que graba
        unload_mix
        rm -f "$RUN"/{pid,mic,mod_mic,mod_sys,mod_sink}
        notify-send -u critical -a "Grabación" -i dialog-error "La grabación no arrancó" \
            "$(tail -n 3 "$RUN/log")"
        exit 1
    fi
    echo "$file" > "$RUN/file"
    date +%s > "$RUN/start"
    notify-send -a "Grabación" -i media-record "● Grabando la pantalla" \
        "Super+Shift+D para terminar · clic en MIC (waybar) para el micrófono"
    waybar_refresh
}

stop() {
    local pid file
    pid=$(cat "$RUN/pid"); file=$(cat "$RUN/file" 2>/dev/null)
    kill -INT "$pid" 2>/dev/null
    for _ in $(seq 1 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done   # que cierre bien el archivo
    unload_mix
    rm -f "$RUN"/{pid,file,start,mic,mod_mic,mod_sys,mod_sink}
    notify-send -a "Grabación" -i video-x-generic "■ Grabación guardada" "${file/#$HOME/\~}"
    waybar_refresh
}

case "${1:-toggle}" in
    toggle)
        if recording; then stop; else rm -f "$RUN/pid"; start; fi ;;
    mic)
        recording || exit 0
        mi=$(mic_input) || exit 0
        if [ "$(cat "$RUN/mic")" = on ]; then
            pactl set-sink-input-mute "$mi" 1; echo off > "$RUN/mic"
        else
            pactl set-sink-input-mute "$mi" 0; echo on > "$RUN/mic"
        fi
        waybar_refresh ;;
    status)
        if [ -f "$RUN/pid" ] && ! recording; then     # wf-recorder se cayó solo: limpiar
            file=$(cat "$RUN/file" 2>/dev/null)
            unload_mix
            rm -f "$RUN"/{pid,file,start,mic,mod_mic,mod_sys,mod_sink}
            notify-send -u critical -a "Grabación" -i dialog-error "La grabación se cortó" "${file/#$HOME/\~}"
            echo '{"text":""}'
        elif recording; then
            s=$(( $(date +%s) - $(cat "$RUN/start") ))
            printf '{"text":"● REC %02d:%02d","class":"rec","tooltip":"Grabando · clic o Super+Shift+D para terminar"}\n' $((s / 60)) $((s % 60))
        else
            echo '{"text":""}'
        fi ;;
    micstatus)
        if recording; then
            if [ "$(cat "$RUN/mic")" = on ]; then
                echo '{"text":"󰍬 MIC","class":"on","tooltip":"Micrófono prendido · clic para apagarlo"}'
            else
                echo '{"text":"󰍭 MIC","class":"off","tooltip":"Micrófono apagado · clic para prenderlo"}'
            fi
        else
            echo '{"text":""}'
        fi ;;
esac
