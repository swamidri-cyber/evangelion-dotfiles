hl.config({
    dwindle = {
        preserve_split = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    misc = {
        col = {
            splash = RICE_AMBER, -- color del texto de bienvenida de Hyprland
        },
        -- Sin el fondo/logo por defecto de Hyprland: antes del arranque MAGI, negro
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        background_color = "rgb(000000)",
        -- Si el bloqueo (rice-lock) se cae, otro (hyprlock) puede tomar la posta
        allow_session_lock_restore = true,
        middle_click_paste = false,
        enable_swallow = true,
        swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
        vrr = 3,
    },
    render = {
        direct_scanout = 2,
        -- Use the option below if you find games constantly black screening for a couple seconds whenever direct scanout enables/disables
        -- non_shader_cm = 0,
    },
    xwayland = {
        force_zero_scaling = true
    },
})
