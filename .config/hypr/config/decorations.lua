-- ─────────────────────────────────────────────────────────────────────────────
--  Aspecto de las ventanas: gaps, bordes, esquinas, sombras, blur.
--  Los colores vienen de colors.lua (variables RICE_*).
--  Wiki: https://wiki.hypr.land/Configuring/Variables/
-- ─────────────────────────────────────────────────────────────────────────────

hl.config({
    general = {
        gaps_in  = 5,    -- espacio entre ventanas (px)
        gaps_out = 14,   -- espacio entre ventanas y el borde de la pantalla
        border_size = 1, -- borde fino, estilo línea de fósforo

        extend_border_grab_area = 10, -- zona invisible extra para agarrar el borde
        resize_on_border = true,      -- redimensionar arrastrando el borde

        col = {
            -- Ventana activa: degradé dorado → ámbar en diagonal
            active_border = {
                colors = { RICE_GOLD, RICE_AMBER },
                angle = 45,
            },
            -- Ventana inactiva: marrón oscuro, casi invisible
            inactive_border = RICE_BG2,
        },
    },

    -- Grupos de ventanas (pestañas, Super+G si lo configurás)
    group = {
        col = {
            border_active          = RICE_AMBER,
            border_inactive        = RICE_BG2,
            border_locked_active   = RICE_RUST,
            border_locked_inactive = RICE_BG2,
        },
        groupbar = {
            col = {
                active          = RICE_AMBER,
                inactive        = RICE_BG2,
                locked_active   = RICE_RUST,
                locked_inactive = RICE_BG2,
            },
        },
    },

    decoration = {
        rounding       = 8,   -- radio de las esquinas (px). 0 = cuadradas
        rounding_power = 2,   -- forma de la curva: 2 = círculo, más alto = "squircle"

        -- Opacidad de las ventanas (1.0 = opaca). Las terminales y navegadores
        -- tienen reglas propias en windowrules.lua que ignoran esto.
        active_opacity     = 0.96,
        inactive_opacity   = 0.88,
        fullscreen_opacity = 1,

        -- La ventana bajo el mouse (el foco sigue al mouse) queda iluminada y las
        -- demás se oscurecen un poco. dim_strength: 0 = nada, 1 = negro.
        dim_inactive = true,
        dim_strength = 0.18,
        dim_special = 0.3,    -- oscurece el fondo al abrir el scratchpad (Super+S)

        -- Sombra ámbar suave: da el efecto de "brillo" alrededor de la ventana
        -- activa, como un monitor de fósforo.
        shadow = {
            enabled        = true,
            range          = 18,   -- qué tan lejos se difumina (px)
            render_power   = 3,    -- caída de la sombra (1 = suave, 4 = dura)
            color          = RICE_GLOW,        -- ventana activa: brillo ámbar
            color_inactive = RICE_GLOW_FAINT,  -- inactiva: sombra oscura normal
        },

        -- Desenfoque detrás de ventanas/paneles transparentes (kitty, barra)
        blur = {
            enabled    = true,
            size       = 5,      -- radio del blur (más chico = se reconocen más las formas)
            passes     = 2,      -- más pasadas = más suave pero más GPU (antes 3)
            noise      = 0.04,   -- grano sobre el blur (suma al look analógico)
            brightness = 1.0,    -- 1.0 = no oscurece lo de atrás (antes 0.85)
            contrast   = 1.0,
            vibrancy   = 0.2,    -- satura los colores que se ven a través
            special    = true,   -- también desenfoca detrás del scratchpad
        },
    },
})
