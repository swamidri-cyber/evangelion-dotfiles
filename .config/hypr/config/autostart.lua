-- ─────────────────────────────────────────────────────────────────────────────
--  Programas que arrancan al iniciar Hyprland.
--  Qué se arranca depende de RICE_SHELL (definido en variables.lua).
--  "uwsm app --" lanza cada programa como servicio de la sesión: si uno se
--  cae no arrastra a los demás, y se cierran todos limpio al salir.
-- ─────────────────────────────────────────────────────────────────────────────

local app = "uwsm app -- "
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts/"

hl.on("hyprland.start", function ()
    -- Comunes a ambos modos
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("xhost +SI:localuser:root")
    -- Efectos del micrófono (EasyEffects, sin ventana): reducción de ruido, compuerta,
    -- ecualizador, compresor y limitador. Preajuste en ~/.local/share/easyeffects/input/
    hl.exec_cmd(app .. "easyeffects --service-mode --hide-window")
    hl.exec_cmd("sleep 4 && easyeffects -l Mic-escritorio")

    if RICE_SHELL == "rice" then
        -- Ventanas de contraseña (polkit). Sin esto fallan las apps que piden permisos.
        hl.exec_cmd("systemctl --user start hyprpolkitagent")
        -- Barra superior
        hl.exec_cmd(app .. "waybar")
        -- Notificaciones
        hl.exec_cmd(app .. "swaync")
        -- Indicador en pantalla de volumen/brillo
        hl.exec_cmd(app .. "swayosd-server")
        -- Bloqueo automático por inactividad (config en hypr/hypridle.conf)
        hl.exec_cmd(app .. "hypridle")
        -- Wallpaper: primero el demonio, después el script elige la imagen
        hl.exec_cmd(app .. "awww-daemon")
        hl.exec_cmd(scripts .. "wallpaper.sh restore")
        -- Historial del portapapeles (texto e imágenes)
        hl.exec_cmd(app .. "wl-paste --type text --watch cliphist store")
        hl.exec_cmd(app .. "wl-paste --type image --watch cliphist store")
        if RICE_LAUNCHER == "quickshell" then
            hl.exec_cmd(app .. "qs -c rice-launcher")          -- lanzador (Super+Espacio), espera oculto
        end
        hl.exec_cmd(app .. "qs -c rice-keys")                  -- hoja de atajos (Super+F1), espera oculta
        hl.exec_cmd(app .. "qs -c rice-shot")                  -- menú de capturas (Super+Shift+S), espera oculto
        hl.exec_cmd(app .. "qs -c rice-subs")                  -- subtítulos al azar en el escritorio
        hl.exec_cmd(app .. "qs -c rice-static")                -- estática en el brillo de la ventana activa
        hl.exec_cmd(app .. "qs -c rice-noise")                 -- ruido blanco suave sobre el fondo
        -- Ícono de red en la bandeja (si está instalado)
        hl.exec_cmd("command -v nm-applet && " .. app .. "nm-applet --indicator")
    else
        -- Modo original de CachyOS: Noctalia hace todo lo anterior
        hl.exec_cmd("noctalia")
    end
end)
