-- Window rules wiki https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Generic floating position
hl.window_rule({ match = { float = true }, persistent_size = true })

-- Picture-in-Picture
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    size              = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
    pin               = true,
})

-- Gaming
local gamingApps = "^(steam_app.*|gamescope)$"
local gamingWorkspace = "name:gaming"

hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { xdg_tag = "^(.*game.*)$" }, workspace = gamingWorkspace, fullscreen_state = 2, content = "game", sync_fullscreen = true })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Launching\\.{3})$" }, float = true, center = true, workspace = gamingWorkspace })
hl.window_rule({
    match = {
        class         = gamingApps,
        title         = "^(.+)$",
        initial_title = "negative:^(.*\\\\home\\\\.*)$",
    },
    content          = "game",
    decorate         = false,
    fullscreen_state = 2,
    size             = { "monitor_w", "monitor_h" },
    sync_fullscreen  = true,
})
hl.window_rule({
    match = {
        class         = "^(steam_app.*)$",
        initial_title = "^$",
    },
    center           = true,
    float            = true,
    fullscreen       = false,
    fullscreen_state = 0,
    workspace        = gamingWorkspace,
})

-- Apps
hl.window_rule({ match = { class = "^(.*\\.exe)$", float = true }, monitor = PRIMARY_MONITOR, center = true, fullscreen_state = 0 })
hl.window_rule({ match = { class = "^(.*[Ll]auncher.*)$" }, float = true, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(vesktop|discord)$" }, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(.*[Cc]alc.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({ match = { class = "^(.*swash)$", title = "^(Swash)$" }, min_size = { "max(monitor_w, monitor_h)*0.35", "min(monitor_w, monitor_h)*0.35" }, float = true })
hl.window_rule({ match = { class = "^(dev\\.)?(noctalia\\.Noctalia(\\.Settings)?)$" }, float = true, size = { "monitor_w*0.70", "monitor_h*0.70" } })
hl.window_rule({
    match = {
        class = "^(org\\.kde\\.dolphin)$",
        title = "negative:^(Moving.*|Create New.*|Extract.*|Compress.*|Copying.*|Progress.*|Configure.*|Properties.*|Choose\\sApplication.*)$",
    },
    float = true,
    size = { "max(monitor_w, monitor_h)*0.50", "min(monitor_w, monitor_h)*0.55" },
    move = {
        "max(20, min(cursor_x - (window_w*0.50), monitor_w - window_w + 20))", -- X axis clamping
        "max(20, min(cursor_y - 50, monitor_h - window_h + 20))" -- Y axis clamping
    },
})

-- Opacity Overrides
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)$"

hl.window_rule({ match = { class = "^(firefox|zen)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" }) -- Override opacity in favor of terminal settings for opacity. If your terminal doesn't support transparency, you can remove this rule.
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })

-- Float Utility Windows
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
}
for _, m in ipairs(floatApps) do hl.window_rule({ match = m, float = true }) end

-- Float Common Modals
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$"},
}
for _, m in ipairs(modalMatches) do hl.window_rule({ match = m, float = true }) end

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Noctalia layer rule
hl.layer_rule({
  name = "noctalia",
  match = {
    namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
  },
  no_anim = true,
  ignore_alpha = 0.5,
  blur = true,
  blur_popups = true,
})

-- ─────────────────────────────────────────────────────────────────────────────
--  Rice: lanzador (Super+Espacio) y ventanitas flotantes del rice
--  "rice-launcher" = panel de apps · "rice-float" = menús (portapapeles, sesión)
-- ─────────────────────────────────────────────────────────────────────────────
hl.window_rule({
    name    = "rice-launcher",
    match   = { class = "^(rice-launcher)$" },
    float   = true,
    center  = true,
    size    = { "monitor_w*0.60", "monitor_h*0.56" }, -- 60% ancho, 56% alto de la pantalla
    -- (sin dim_around: oscurecer el fondo apagaba el blur y lo hacía ver negro)
    stay_focused = true,                 -- el foco no se escapa a otra ventana
    opacity = "1.0 override",            -- la transparencia la maneja kitty
})
hl.window_rule({
    name    = "rice-float",
    match   = { class = "^(rice-float)$" },
    float   = true,
    center  = true,
    size    = { "monitor_w*0.40", "monitor_h*0.45" },
    stay_focused = true,
    opacity = "1.0 override",
})

-- Rice: desenfoque detrás de la barra, las notificaciones y el OSD de volumen.
-- ignore_alpha = no desenfocar las zonas casi transparentes (así la barra,
-- que es transparente, solo desenfoca detrás del texto y del recuadro).
hl.layer_rule({
    name  = "rice-layers",
    match = { namespace = "^(waybar|swaync-control-center|swaync-notification-window|swayosd)$" },
    blur  = true,
    ignore_alpha = 0.3,
})

-- Rice: lanzador de Quickshell (capa "rice-launcher"). ignore_alpha 0.25 = solo
-- desenfoca debajo del panel (fondo al 28%), no debajo del brillo de alrededor.
hl.layer_rule({
    name  = "rice-launcher-qs",
    match = { namespace = "^(rice-launcher)$" },
    blur  = true,
    ignore_alpha = 0.25,
    no_anim = true,     -- la animación (encendido CRT + rebote) la hace el propio panel
})

-- Rice: hoja de atajos (Super+F1, Quickshell, capa "rice-keys"). Igual que el lanzador.
hl.layer_rule({
    name  = "rice-keys-qs",
    match = { namespace = "^(rice-keys)$" },
    blur  = true,
    ignore_alpha = 0.25,
    no_anim = true,     -- la animación (encendido CRT + rebote) la hace el propio panel
})

-- Rice: menú de capturas (Super+Shift+S, Quickshell). El panel se anima solo;
-- la capa del lazo (pantalla congelada) aparece y desaparece sin animación.
hl.layer_rule({
    name  = "rice-shot-qs",
    match = { namespace = "^(rice-shot)$" },
    blur  = true,
    ignore_alpha = 0.25,
    no_anim = true,
})
hl.layer_rule({
    name  = "rice-shot-lasso",
    match = { namespace = "^(rice-shot-lasso)$" },
    no_anim = true,
})

-- ─────────────────────────────────────────────────────────────────────────────
--  Rice: ninguna ventana flotante nace cortada fuera de la pantalla.
--  Algunas apps (diálogos de Dolphin, apps de Proton/Wine) recuerdan una
--  posición o un tamaño viejos y aparecen medio afuera, casi siempre del lado
--  derecho. Un instante después de abrirse cada ventana se revisan las
--  flotantes: si alguna se sale del área útil (la pantalla menos la barra), se
--  achica si no entra y se corre hacia adentro. Solo actúa al abrir: si después
--  la arrastrás afuera a propósito, la deja.
-- ─────────────────────────────────────────────────────────────────────────────
local EDGE = { top = 55, right = 15, bottom = 15, left = 15 } -- 55 = barra (40) + margen

local function keepOnScreen()
    for _, w in ipairs(hl.get_windows() or {}) do
        local m = w.monitor
        if w.mapped and w.floating and not w.hidden and w.fullscreen == 0 and m
           and w.size.x > 20 and w.size.y > 20 then        -- ignora bordecitos de XWayland
            local x0, y0 = m.x + EDGE.left, m.y + EDGE.top
            local x1, y1 = m.x + m.width - EDGE.right, m.y + m.height - EDGE.bottom
            local wd, ht = math.min(w.size.x, x1 - x0), math.min(w.size.y, y1 - y0)
            local x = math.max(x0, math.min(w.at.x, x1 - wd))
            local y = math.max(y0, math.min(w.at.y, y1 - ht))
            local sel = "address:" .. w.address
            if wd ~= w.size.x or ht ~= w.size.y then
                hl.dispatch(hl.dsp.window.resize({ x = wd, y = ht, window = sel }))
            end
            if x ~= w.at.x or y ~= w.at.y then
                hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = sel }))
            end
        end
    end
end
-- 150 ms de espera: la app termina de fijar su tamaño y las reglas ya se aplicaron
hl.on("window.open", function()
    hl.timer(keepOnScreen, { timeout = 150, type = "oneshot" })
end)

-- Rice: la app de Wallpaper Engine (Proton) es una app de Steam pero no un
-- juego: ventana flotante normal en el escritorio actual, sin pantalla completa.
-- (Va al final para pisar las reglas de "Gaming" de más arriba.)
hl.window_rule({
    name  = "wallpaper-engine-ui",
    match = { class = "^(steam_app_431960)$" },
    workspace        = "unset",
    content          = "none",
    fullscreen_state = 0,
    decorate         = true,
})

-- Rice: el menú de wallpapers es más grande que los otros menús (tiene vista previa)
hl.window_rule({
    name  = "rice-wallpaper-menu",
    match = { class = "^(rice-float)$", title = "^(rice-wallpaper)$" },
    size  = { "monitor_w*0.62", "monitor_h*0.60" },
})

-- Rice: subtítulos del escritorio (Quickshell, capa "rice-subs"). El fundido
-- lo hace el propio texto; sin animación de Hyprland.
hl.layer_rule({
    name  = "rice-subs-qs",
    match = { namespace = "^(rice-subs)$" },
    no_anim = true,
})

-- Rice: estática alrededor de la ventana activa (Quickshell, capa "rice-static").
-- Es una capa transparente encima de todo: sin animación de Hyprland.
hl.layer_rule({
    name  = "rice-static-qs",
    match = { namespace = "^(rice-static)$" },
    no_anim = true,
})

-- Rice: ruido blanco sobre el fondo (Quickshell, capa "rice-noise"): sin animación de Hyprland.
hl.layer_rule({
    name  = "rice-noise-qs",
    match = { namespace = "^(rice-noise)$" },
    no_anim = true,
})
