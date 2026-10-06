#!/bin/bash
# Espera (máx. 8 s) a que el arranque MAGI (rice-boot) esté tapando la pantalla,
# así el fondo y la barra no se ven antes que él. Uso: wait-boot.sh <comando…>
for _ in $(seq 1 80); do
    hyprctl layers 2>/dev/null | grep -q "namespace: rice-boot" && break
    sleep 0.1
done
exec "$@"
