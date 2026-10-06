#!/usr/bin/env bash
# Instala el ayudante root del modo consola. Correr UNA vez:
#   sudo bash ~/.config/rice-console/system/install.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "correr con sudo" >&2; exit 1; }
user="${SUDO_USER:?correr con sudo desde tu usuario}"
here="$(cd "$(dirname "$0")" && pwd)"

install -o root -g root -m 0755 "$here/rice-to-windows" /usr/local/bin/rice-to-windows

rule="/etc/sudoers.d/rice-console"
tmp=$(mktemp)
echo "$user ALL=(root) NOPASSWD: /usr/local/bin/rice-to-windows" > "$tmp"
visudo -cf "$tmp" >/dev/null
install -o root -g root -m 0440 "$tmp" "$rule"
rm -f "$tmp"
echo "listo: /usr/local/bin/rice-to-windows + $rule"
