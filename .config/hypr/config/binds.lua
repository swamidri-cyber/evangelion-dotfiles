local mainMod = "SUPER"
local noctCall = "noctalia msg "
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

-- ─────────────────────────────────────────────────────────────────────────────
--  Acciones que cambian según RICE_SHELL (variables.lua).
--  Cada atajo de abajo usa act.<nombre>; acá se decide qué comando corre.
-- ─────────────────────────────────────────────────────────────────────────────
local scripts = os.getenv("HOME") .. "/.config/hypr/scripts/"
local shot = 'swash --stdin --name "swash-$(date +%Y-%m-%d_%H:%M:%S).png"'
local act
if RICE_SHELL == "rice" then
    act = {
        settings      = launchPrefix .. "nwg-look",              -- ajustes de tema GTK
        control       = "swaync-client -t -sw",                   -- centro de notificaciones
        notifications = "swaync-client -t -sw",
        emoji         = "true",                                   -- (sin selector de emoji por ahora)
        lock          = "loginctl lock-session",                  -- hypridle → hyprlock
        session       = scripts .. "menu.sh session",
        clipboard     = scripts .. "menu.sh clipboard",
        wallpaper     = scripts .. "menu.sh wallpaper",
        vol_up        = "swayosd-client --output-volume +5",  -- de 5 en 5 (antes "raise" = 10)
        vol_down      = "swayosd-client --output-volume -5",
        vol_mute      = "swayosd-client --output-volume mute-toggle",
        mic_mute      = "swayosd-client --input-volume mute-toggle",
        media_toggle  = "playerctl play-pause",
        media_next    = "playerctl next",
        media_prev    = "playerctl previous",
        bright_up     = "swayosd-client --brightness raise",
        bright_down   = "swayosd-client --brightness lower",
        shot_region   = 'grim -g "$(slurp)" - | ' .. shot,         -- recorte → editor swash
        shot_full     = "grim - | " .. shot,
    }
else
    act = {
        settings      = noctCall .. "settings-toggle",
        control       = noctCall .. "panel-toggle control-center",
        notifications = noctCall .. "panel-toggle control-center notifications",
        emoji         = noctCall .. "panel-toggle launcher /emo",
        lock          = noctCall .. "session lock",
        session       = noctCall .. "panel-toggle session",
        clipboard     = noctCall .. "panel-toggle clipboard",
        wallpaper     = noctCall .. "panel-toggle wallpaper",
        vol_up        = noctCall .. "volume-up",
        vol_down      = noctCall .. "volume-down",
        vol_mute      = noctCall .. "volume-mute",
        mic_mute      = noctCall .. "mic-mute",
        media_toggle  = noctCall .. "media toggle",
        media_next    = noctCall .. "media next",
        media_prev    = noctCall .. "media previous",
        bright_up     = noctCall .. "brightness-up",
        bright_down   = noctCall .. "brightness-down",
        shot_region   = noctCall .. "screenshot-region",
        shot_full     = noctCall .. "screenshot-fullscreen",
    }
end

-- AZERTY fix: the number-row keys emit symbols (& é " ' ...) without Shift, so
-- binding to the digit characters fails. Bind by physical keycode instead.
-- Digit d -> evdev keycode: 1..9 => 10..18, 0 => 19
local function digitCode(d)
    return "code:" .. (d == 0 and 19 or (9 + d))
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D",           hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))

-- Change focus
-- Mover el foco: Super+Ctrl+flechas (Super+flechas solas = escritorios, ver más abajo)
hl.bind(mainMod .. " + CONTROL + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + CONTROL + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + CONTROL + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + CONTROL + Down",  hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + Tab",           hl.dsp.window.cycle_next())
if RICE_SHELL == "rice" then
    hl.bind(mainMod .. " + Tab", hl.dsp.window.cycle_next())
else
    hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd(noctCall .. "window-switcher"))
end

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + Up",                   hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Right",                hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left",                 hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Down",                 hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(1),     hl.dsp.window.move({ monitor = MONITOR1 }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(2),     hl.dsp.window.move({ monitor = MONITOR2 }))
hl.bind(mainMod .. " + SHIFT + " .. digitCode(3),     hl.dsp.window.move({ monitor = MONITOR3 }))
hl.bind(mainMod .. " + SHIFT + mouse_up",             hl.dsp.window.move({ monitor   = "-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down",           hl.dsp.window.move({ monitor   = "+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "m+1" }))
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + CONTROL + " .. digitCode(key), hl.dsp.window.move({ workspace = "m~" .. i }))
end
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + ALT + " .. digitCode(key), hl.dsp.window.move({ workspace = "m~" .. i, follow = false }))
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true})
hl.bind(mainMod .. " + Plus", function() zoomfunction(0.3) end, { repeating = true })

--# Zoom with keypad
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })


------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + Return",     hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(launchPrefix .. EDITOR))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("XF86Calculator",           hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind(mainMod .. " + W",          hl.dsp.exec_cmd(launchPrefix .. BROWSER))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
hl.bind(mainMod .. " + Z",          hl.dsp.exec_cmd(act.settings))
hl.bind(mainMod .. " + X",          hl.dsp.exec_cmd(act.control))
-- Lanzador del rice: Quickshell o kitty + fzf, según RICE_LAUNCHER (variables.lua).
-- Si el de Quickshell no está corriendo (se cerró), lo arranca y lo abre.
-- Para volver al de Noctalia: noctCall .. "panel-toggle launcher"
local qsLauncher = "qs -c rice-launcher ipc call launcher toggle"
local launcherCmd = RICE_LAUNCHER == "quickshell"
    and (qsLauncher .. " || { qs -c rice-launcher -d && sleep 0.6 && " .. qsLauncher .. "; }")
    or  (os.getenv("HOME") .. "/.config/rice-launcher/toggle.sh")
hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd(launcherCmd))
hl.bind(mainMod .. " + period",     hl.dsp.exec_cmd(act.emoji))
-- Hoja de atajos (Quickshell, ~/.config/quickshell/rice-keys). Si no está corriendo, la arranca.
local qsKeys = "qs -c rice-keys ipc call keys toggle"
hl.bind(mainMod .. " + F1",         hl.dsp.exec_cmd(qsKeys .. " || { qs -c rice-keys -d && sleep 0.6 && " .. qsKeys .. "; }"))
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd(act.lock))
hl.bind(mainMod .. " + ALT + C",    hl.dsp.exec_cmd(act.session))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(act.vol_up),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(act.vol_down), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(act.vol_mute), { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(act.mic_mute),    { locked = true })

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(act.media_toggle),   { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(act.media_toggle),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(act.media_next),     { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(act.media_prev), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(act.bright_up),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(act.bright_down), { locked = true, repeating = true })

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("hyprpicker -a -n"))
hl.bind("Print",               hl.dsp.exec_cmd(act.shot_region))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(act.shot_full))
-- Menú de capturas (Quickshell, ~/.config/quickshell/rice-shot): completa, lazo, rectángulo, ventana
local qsShot = "qs -c rice-shot ipc call shot toggle"
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(qsShot .. " || { qs -c rice-shot -d && sleep 0.6 && " .. qsShot .. "; }"))
-- Grabar la pantalla (empezar/terminar). Micrófono: clic en "MIC" de la waybar.
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/record.sh toggle"))

-- Theming and Wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(act.wallpaper))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(act.clipboard))

-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(act.notifications))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Super+número = ir a ese escritorio (1..NUM_WPM). Antes Super+1/2/3 iban a
-- los monitores 1/2/3; con un solo monitor no hacían nada.
for i = 1, NUM_WPM do
    hl.bind(mainMod .. " + " .. digitCode(i % 10), hl.dsp.focus({ workspace = i }))
end

-- Focus on workspace number
-- Absolute
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + ALT + " .. digitCode(key), hl.dsp.focus({ workspace = i }))
end
-- Relative
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + CONTROL + " .. digitCode(key), hl.dsp.focus({ workspace = "m~" .. i }))
end

-- Move to adjacent workspaces and next empty on a given monitor
-- Super+←/→ = escritorio anterior/siguiente (antes era con Ctrl; ahora Ctrl mueve el foco)
hl.bind(mainMod .. " + Right",                 hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + Left",                  hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + Down",                  hl.dsp.focus({ workspace = "emptym" }))   -- escritorio vacío (antes Super+Ctrl+↓)

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special" }))   -- antes Super+Shift+S (ahora es el menú de capturas)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())

-- Arroba con Ctrl+Alt+Q (como en Windows). En el teclado latam la @ es AltGr+Q;
-- este atajo le manda AltGr+Q (MOD5) a la ventana activa. code:24 = tecla Q.
hl.bind("CONTROL + ALT + code:24", hl.dsp.send_shortcut({ mods = "MOD5", key = "Q" }))
