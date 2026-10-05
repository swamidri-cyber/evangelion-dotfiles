-- ─────────────────────────────────────────────────────────────────────────────
--  Animaciones: suaves y "analógicas", sin rebotes exagerados.
--  Wiki: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
--
--  speed = duración en décimas de segundo (5 = 0.5 s). Más alto = más lento.
--  Para desactivar una animación: enabled = false.
-- ─────────────────────────────────────────────────────────────────────────────

-- Curvas bezier: {x1,y1},{x2,y2} definen la aceleración (ver cubic-bezier.com)
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("crt",            { type = "bezier", points = { {0.16, 1},    {0.3, 1}     } }) -- arranque rápido, frenado largo y suave

-- Resorte suave para mover/redimensionar ventanas (sin rebote visible)
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 300, dampening = 30 })

-- Valores por defecto para todo lo que no se configure abajo
hl.animation({ leaf = "global",        enabled = true, speed = 5,   bezier = "crt" })

-- Ventanas: se prenden como un tubo de TV (igual que el lanzador)
--  · Al abrir: estilo "gnomed" = la ventana nace como una franja que se abre
--    hacia arriba y abajo, con un resorte que se pasa de largo y rebota.
--  · Al cerrar: se aplasta en una línea, como una tele que se apaga.
--  · Rebote irregular: justo antes de abrir cada ventana se sortean la
--    rigidez y la amortiguación del resorte, así nunca rebota igual.
--  Antes: windowsIn/windowsOut con bezier "crt"/"almostLinear" y style = "popin 90%".
hl.animation({ leaf = "windows",       enabled = true, speed = 4,   spring = "easy" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2,   bezier = "almostLinear", style = "gnomed" })

local function rnd(a, b) return a + math.random() * (b - a) end
local function crtBounce()
    hl.curve("crtBounce", {
        type       = "spring",
        mass       = 1,
        stiffness  = rnd(140, 280),   -- más alto = rebota más rápido
        dampening  = rnd(7, 14),      -- más bajo = más rebotes antes de quedarse quieta
    })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, spring = "crtBounce", style = "gnomed" })
end
math.randomseed(os.time())
crtBounce()                                    -- valor inicial
hl.on("window.open_early", crtBounce)          -- y uno nuevo antes de cada ventana

-- Bordes: el degradé cambia de color con suavidad al cambiar de foco
hl.animation({ leaf = "border",        enabled = true, speed = 6,   bezier = "easeOutQuint" })

-- Fundidos (opacidad)
hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "quick" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 2,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.5, bezier = "almostLinear" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = 3,   bezier = "quick" })        -- oscurecer/iluminar al pasar el mouse

-- Capas (barra, notificaciones, lanzador): fundido + leve desplazamiento
hl.animation({ leaf = "layers",        enabled = true, speed = 4,   bezier = "crt" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   bezier = "crt",          style = "popin 92%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, bezier = "linear",       style = "fade" })

-- Workspaces: deslizan con un leve fundido (slidefade 15%)
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,   bezier = "crt",          style = "slidefade 15%" })

-- Scratchpad (Super+S): baja desde arriba
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 3, bezier = "crt",   style = "slidefadevert -30%" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "quick", style = "slidefadevert -30%" })

-- Zoom (Super + / Super -)
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,   bezier = "quick" })
