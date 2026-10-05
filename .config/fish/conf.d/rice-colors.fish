# ─────────────────────────────────────────────────────────────────────────────
#  Colores de fish (resaltado mientras escribís) con la paleta Gruvbox ámbar.
#  Se usan variables globales (-g): si borrás este archivo, fish vuelve a sus
#  colores de siempre sin dejar rastros.
# ─────────────────────────────────────────────────────────────────────────────
if status is-interactive
    set -g fish_color_command        fabd2f          # comandos válidos: dorado
    set -g fish_color_error          fb4934          # comando inexistente: rojo
    set -g fish_color_param          ebdbb2          # argumentos: crema
    set -g fish_color_quote          b8bb26          # "texto entre comillas"
    set -g fish_color_redirection    fe8019          # > < |
    set -g fish_color_end            fe8019          # ; &
    set -g fish_color_operator       d79921
    set -g fish_color_comment        665c54          # # comentarios
    set -g fish_color_autosuggestion 665c54          # sugerencia gris a la derecha
    set -g fish_color_valid_path     --underline
    set -g fish_color_search_match   --background=3c3836
    set -g fish_color_selection      --background=3c3836
    set -g fish_pager_color_prefix   fe8019 --bold   # parte coincidente en el TAB
    set -g fish_pager_color_completion ebdbb2
    set -g fish_pager_color_description 928374
    set -g fish_pager_color_selected_background --background=3c3836
end
