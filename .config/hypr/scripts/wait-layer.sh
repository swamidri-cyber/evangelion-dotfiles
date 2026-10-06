#!/bin/bash
# Espera (máx. 10 s) a que exista la capa con ese namespace y después corre el
# comando. Uso: wait-layer.sh <namespace> <comando…>
ns="$1"; shift
for _ in $(seq 1 100); do
    hyprctl layers 2>/dev/null | grep -q "namespace: $ns," && break
    sleep 0.1
done
exec "$@"
