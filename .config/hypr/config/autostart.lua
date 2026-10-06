-- ─────────────────────────────────────────────────────────────────────────────
--  Programas que arrancan al iniciar Hyprland.
--  Qué se arranca depende de RICE_SHELL (definido en variables.lua).
--  "uwsm app --" lanza cada programa como servicio de la sesión: si uno se
--  cae no arrastra a los demás, y se cierran todos limpio al salir.
-- ─────────────────────────────────────────────────────────────────────────────

local app = "uwsm app -- "
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts/"

hl.on("hyprland.start", function ()
    -- Grabación única del inicio de sesión (solo si existe ~/.cache/rice-record-login)
    hl.exec_cmd(scripts .. "record-login.sh")
    -- Comunes a ambos modos
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("xhost +SI:localuser:root")
    -- Cursor propio (Rice-CRT): se fija explícito al arrancar; si no, a veces
    -- queda el cursor blanco por defecto después de reiniciar
    hl.exec_cmd("hyprctl setcursor Rice-CRT 24")
    hl.exec_cmd("sleep 3 && hyprctl setcursor Rice-CRT 24")
    -- Efectos del micrófono (EasyEffects, sin ventana): reducción de ruido, compuerta,
    -- ecualizador, compresor y limitador. Preajuste en ~/.local/share/easyeffects/input/
    hl.exec_cmd(app .. "easyeffects --service-mode --hide-window")
    hl.exec_cmd("sleep 4 && easyeffects -l Mic-escritorio")

    if RICE_SHELL == "rice" then
        -- Arranque MAGI: tapa la pantalla mientras carga todo lo de abajo y
        -- después se abre como una compuerta (~5 s, cualquier tecla lo saltea)
        hl.exec_cmd(app .. "qs -c rice-boot")
        -- Sonidos del sistema y música ambiente (Super+F10 silencia)
        hl.exec_cmd(app .. "qs -c rice-sound")
        -- Sonido al escribir (todo el sistema; necesita el grupo "input")
        hl.exec_cmd(app .. os.getenv("HOME") .. "/.config/rice-sound/keytick.py")
        -- Ventanas de contraseña (polkit). Sin esto fallan las apps que piden permisos.
        hl.exec_cmd("systemctl --user start hyprpolkitagent")
        -- Barra superior (wait-boot.sh: espera a que MAGI tape la pantalla)
        hl.exec_cmd(scripts .. "wait-boot.sh " .. app .. "waybar")
        -- Notificaciones
        hl.exec_cmd(app .. "swaync")
        -- Indicador en pantalla de volumen/brillo
        hl.exec_cmd(app .. "swayosd-server")
        -- Bloqueo automático por inactividad (config en hypr/hypridle.conf)
        hl.exec_cmd(app .. "hypridle")
        -- Wallpaper: primero el demonio, después el script elige la imagen.
        -- El demonio también espera a MAGI: al arrancar muestra solo el último
        -- fondo guardado y se veía antes que el arranque
        hl.exec_cmd(scripts .. "wait-boot.sh " .. app .. "awww-daemon")
        hl.exec_cmd(scripts .. "wait-boot.sh " .. scripts .. "wallpaper.sh restore")
        -- El fondo con los efectos del arranque (interferencia, halo, grano). Tiene
        -- que mapearse DESPUÉS de awww para quedar encima de él
        hl.exec_cmd(scripts .. "wait-layer.sh awww-daemon " .. app .. "qs -c rice-wallfx")
        -- Historial del portapapeles (texto e imágenes)
        hl.exec_cmd(app .. "wl-paste --type text --watch cliphist store")
        hl.exec_cmd(app .. "wl-paste --type image --watch cliphist store")
        if RICE_LAUNCHER == "quickshell" then
            hl.exec_cmd(app .. "qs -c rice-launcher")          -- lanzador (Super+Espacio), espera oculto
        end
        hl.exec_cmd(app .. "qs -c rice-keys")                  -- hoja de atajos (Super+F1), espera oculta
        hl.exec_cmd(app .. "qs -c rice-shot")                  -- menú de capturas (Super+Shift+S), espera oculto
        hl.exec_cmd(scripts .. "wait-boot.sh " .. app .. "qs -c rice-subs")                  -- subtítulos al azar en el escritorio
        hl.exec_cmd(app .. "qs -c rice-static")                -- estática en el brillo de la ventana activa
        hl.exec_cmd(scripts .. "wait-boot.sh " .. app .. "qs -c rice-noise")                 -- ruido blanco suave sobre el fondo
        hl.exec_cmd(app .. "qs -c rice-console")               -- modo consola (Super+G / botón Xbox), espera oculto
        hl.exec_cmd(os.getenv("HOME") .. "/.config/rice-console/return.sh")  -- si volvés de Windows: reabre la llamada
        -- Ícono de red en la bandeja (si está instalado)
        hl.exec_cmd("command -v nm-applet && " .. app .. "nm-applet --indicator")
    else
        -- Modo original de CachyOS: Noctalia hace todo lo anterior
        hl.exec_cmd("noctalia")
    end
end)
