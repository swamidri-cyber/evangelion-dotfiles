# ─────────────────────────────────────────────────────────────────────────────
#  Prompt minimalista del rice:
#
#      ~/proyectos  main
#      ❯ _
#
#  · Carpeta actual en gris cálido (abreviada)
#  · Rama de git en ocre, si estás dentro de un repo
#  · ❯ en ámbar; se pone rojo si el último comando falló
# ─────────────────────────────────────────────────────────────────────────────
function fish_prompt
    # Guardar el código de salida ANTES de ejecutar cualquier otra cosa
    set -l last_status $status

    # Línea en blanco entre comandos, para que respire (como en la captura)
    echo

    # Línea 1: carpeta + rama de git
    set_color 928374
    echo -n (prompt_pwd --full-length-dirs 2)
    set -l branch (command git symbolic-ref --short HEAD 2>/dev/null)
    if test -n "$branch"
        set_color d79921
        echo -n "  $branch"
    end
    echo

    # Línea 2: la flecha
    if test $last_status -eq 0
        set_color fe8019
    else
        set_color fb4934
    end
    echo -n '❯ '
    set_color normal
end
