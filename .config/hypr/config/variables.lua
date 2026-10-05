-- Hyprland default apps

TERMINAL     = "kitty"
FILE_MANAGER = "dolphin"
BROWSER      = "zen-browser" -- Super+W. Antes: "firefox"
EDITOR       = "gnome-text-editor --new-window"
CALCULATOR   = "gnome-calculator"

-- Monitors
MONITOR1 = ""
MONITOR2 = ""
MONITOR3 = ""
PRIMARY_MONITOR = MONITOR1

-- Workspaces
NUM_WPM = 6 -- Cantidad de escritorios por monitor (máx. 10). Antes: 3

-- ─────────────────────────────────────────────────────────────────────────────
--  Shell de escritorio (barra, notificaciones, bloqueo, OSD, portapapeles…)
--
--    "noctalia" → el shell que venía con CachyOS (todo en uno)
--    "rice"     → Waybar + swaync + hyprlock/hypridle + hyprpolkitagent +
--                 awww + cliphist + swayosd (el rice retro)
--
--  Se aplica al volver a iniciar sesión. Los atajos cambian solos según esto
--  (ver binds.lua) y el autostart también (ver autostart.lua).
--  Si "rice" da problemas: volvé a poner "noctalia", guardá y reiniciá sesión.
-- ─────────────────────────────────────────────────────────────────────────────
RICE_SHELL = "rice"

-- ─────────────────────────────────────────────────────────────────────────────
--  Lanzador de apps (Super+Espacio) — usado por binds.lua y autostart.lua
--    "quickshell" = panel nuevo (~/.config/quickshell/rice-launcher), abre al instante
--    "kitty"      = versión anterior, kitty + fzf (~/.config/rice-launcher)
--  Los dos comparten las ★ y la info del sistema. Cambiá, guardá y reiniciá sesión.
-- ─────────────────────────────────────────────────────────────────────────────
RICE_LAUNCHER = "quickshell"
