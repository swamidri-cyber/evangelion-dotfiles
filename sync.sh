#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  sync.sh — copia la configuración del rice desde $HOME a este repo.
#  Correlo cada vez que cambies algo y después: git add -A && git commit && git push
#  Deja afuera respaldos (.bak, .antes-*, .v1…), cosas de Noctalia y archivos
#  propios de la máquina.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$HOME"

EXCLUDES=(
  --exclude='*.bak' --exclude='*.bak[0-9]' --exclude='*.orig' --exclude='*.noctalia'
  --exclude='*.ice' --exclude='*.antes*' --exclude='*.v[0-9]' --exclude='*.fondo'
  --exclude='*.global' --exclude='*.parte[0-9]' --exclude='*noctalia*'
  --exclude='Rice-CRT-v1/' --exclude='cells.txt' --exclude='__pycache__/'
)

# Carpetas enteras de ~/.config
CONFIG_DIRS=(
  hypr quickshell waybar swaync kitty fastfetch gtk-3.0 gtk-4.0 swayosd mpv
  btop alacritty qt6ct uwsm rice-logo xsettingsd
)
mkdir -p "$REPO/.config"
for d in "${CONFIG_DIRS[@]}"; do
  rsync -a --delete "${EXCLUDES[@]}" ".config/$d/" "$REPO/.config/$d/"
done

# Carpetas del rice con cosas propias de la máquina que se dejan afuera:
# clave de SteamGridDB, lista de juegos escaneada, la máquina virtual de prueba
# de Limine/Plymouth (GB), los limine.conf copiados de /boot (machine-id) y
# las imágenes de prueba.
RICE_EXCLUDES=(
  --exclude='steamgriddb.key' --exclude='games.json' --exclude='hidden.json'
  --exclude='vm/' --exclude='limine.conf.*' --exclude='log.txt'
  --exclude='/p*.png' --exclude='/prev.png' --exclude='/probe*'
)
RICE_DIRS=(rice-console rice-sound rice-limine rice-demo)
for d in "${RICE_DIRS[@]}"; do
  [ -d ".config/$d" ] && rsync -a --delete "${EXCLUDES[@]}" "${RICE_EXCLUDES[@]}" ".config/$d/" "$REPO/.config/$d/"
done

# Archivos sueltos (rutas relativas a $HOME)
FILES=(
  .config/fish/config.fish
  .config/fish/conf.d/rice-colors.fish
  .config/fish/conf.d/rice-tools.fish
  .config/fish/functions/fish_prompt.fish
  .config/micro/settings.json
  .config/micro/colorschemes/rice-gruvbox.micro
  .config/eza/theme.yml
  .config/spicetify/Themes/Rice/color.ini
  .config/spicetify/Themes/Rice/user.css
  .config/vesktop/settings/quickCss.css
  .config/kdeglobals
  .config/easyeffectsrc
  .local/share/color-schemes/RiceGruvbox.colors
  .local/share/easyeffects/input/Mic-escritorio.json
  .local/share/gtksourceview-4/styles/rice-gruvbox.xml
  .local/share/gtksourceview-5/styles/rice-gruvbox.xml
  rice-rollback.sh
)
for f in "${FILES[@]}"; do
  [ -e "$f" ] && rsync -aR "$f" "$REPO/"
done

# Zen: el perfil tiene nombre aleatorio; en el repo va a zen/ (ver README)
ZEN="$(ls -d .config/zen/*Default* 2>/dev/null | head -1 || true)"
if [ -n "$ZEN" ]; then
  mkdir -p "$REPO/zen/chrome"
  cp "$ZEN/user.js" "$REPO/zen/"
  cp "$ZEN/chrome/userChrome.css" "$ZEN/chrome/userContent.css" "$REPO/zen/chrome/"
fi

# Fondos de pantalla (sin los descartados)
mkdir -p "$REPO/wallpapers"
rsync -a --delete --exclude='descartados/' "Imágenes/wallpapers/" "$REPO/wallpapers/"

echo "Sincronizado en $REPO"
