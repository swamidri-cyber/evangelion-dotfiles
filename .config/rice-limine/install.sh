#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  Instala el menú de Limine con estética MAGI y la pantalla de carga de
#  Plymouth "rice-magi". Correr con sudo:  sudo ~/.config/rice-limine/install.sh
#  Deshacer:  sudo ~/.config/rice-limine/install.sh --deshacer
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Correlo con sudo"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT=/boot
THEME=/usr/share/plymouth/themes/rice-magi

if [ "${1:-}" = "--deshacer" ]; then
    cp "$BOOT/limine.conf.antes-rice" "$BOOT/limine.conf"
    plymouth-set-default-theme cachyos
    limine-mkinitcpio
    echo "Listo: Limine y Plymouth como antes."
    exit 0
fi

# 1. Limine: copia de seguridad, imágenes y config nueva
[ -f "$BOOT/limine.conf.antes-rice" ] || cp "$BOOT/limine.conf" "$BOOT/limine.conf.antes-rice"
install -m 755 "$DIR/limine-wallpaper.png" "$BOOT/rice-limine.png"
install -m 755 "$DIR/departure-8x16.f16"   "$BOOT/rice-limine-font.f16"
python3 "$DIR/gen-conf.py" < "$BOOT/limine.conf" > /tmp/rice-limine.conf
grep -q "^/   LINUX" /tmp/rice-limine.conf && grep -q "machine-id=" /tmp/rice-limine.conf
install -m 755 /tmp/rice-limine.conf "$BOOT/limine.conf"
echo "→ Limine listo (copia de la anterior: $BOOT/limine.conf.antes-rice)"

# 2. Plymouth: tema y initramfs nuevo (limine-mkinitcpio actualiza también las entradas)
mkdir -p "$THEME"
install -m 644 "$DIR"/plymouth/rice-magi/* "$THEME/"
plymouth-set-default-theme rice-magi
limine-mkinitcpio
grep -q "^/   LINUX" "$BOOT/limine.conf" || { echo "¡OJO! la herramienta pisó la config: restaurando"; cp "$BOOT/limine.conf.antes-rice" "$BOOT/limine.conf"; exit 1; }
echo "→ Plymouth listo (tema rice-magi)"
echo "Todo instalado. Reiniciá para verlo."
