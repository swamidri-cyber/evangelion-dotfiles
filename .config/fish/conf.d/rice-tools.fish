# ─────────────────────────────────────────────────────────────────────────────
#  Colores del rice para las herramientas de terminal: bat (y las páginas de
#  man, que CachyOS muestra con bat), fzf y eza (ver ~/.config/eza/theme.yml).
# ─────────────────────────────────────────────────────────────────────────────
set -gx BAT_THEME gruvbox-dark

# fzf: mismos colores que los menús del rice (scripts/menu.sh)
set -gx FZF_DEFAULT_OPTS "--layout=reverse --info=inline-right --pointer='▌' --prompt='❯' \
--color=bg:-1,bg+:#3c3836,fg:#a89984,fg+:#fabd2f,hl:#fe8019,hl+:#fe8019 \
--color=prompt:#fe8019,pointer:#fe8019,header:#d79921,info:#928374,query:#ebdbb2,gutter:-1,border:#504945,spinner:#fe8019,marker:#fe8019"
