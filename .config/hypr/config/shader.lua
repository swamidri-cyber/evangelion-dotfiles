-- ─────────────────────────────────────────────────────────────────────────────
--  Efecto CRT para toda la pantalla (glow, scanlines, grano, viñeta y,
--  opcionalmente, curvatura de vidrio con carcasa negra).
--  El shader en sí está en ~/.config/hypr/shaders/crt.frag (con sus perillas).
--
--  Super+F12 → prender / apagar todo el efecto (para jugar o hacer capturas)
--  Super+F11 → prender / apagar solo la curvatura
--  Pantalla completa real (videos de YouTube, Netflix, mpv, juegos…) → el
--  efecto se apaga solo mientras dure y vuelve al salir. No cuenta "maximizar"
--  (la ventana ocupando la pantalla pero con la barra): solo pantalla completa.
--  Modo juego automático: mientras haya un juego abierto (Steam/Proton,
--  gamescope, o una ventana que se declara "juego") se apagan el efecto, el
--  blur y las animaciones, para que el juego rinda al máximo. Al cerrarlo vuelve.
--
--  Arranque: CRT_ON_START y CURVE_ON_START eligen cómo empieza la sesión.
-- ─────────────────────────────────────────────────────────────────────────────

local HOME = os.getenv("HOME")
CRT_SHADER     = HOME .. "/.config/hypr/shaders/crt.frag"
-- Copia generada con la curvatura activada (no editar: se regenera sola)
CRT_CURVED     = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-crt-curved.frag"
CRT_ON_START   = true
CURVE_ON_START = true   -- curvatura activa al iniciar (Super+F11 la apaga)

-- El glow lee píxeles vecinos: hay que redibujar el monitor entero cuando algo
-- cambia, o quedan líneas brillantes "pegadas". 1 = monitor completo (solo
-- cuando hay cambios; con la pantalla quieta no gasta nada). 2 = por zonas.
hl.config({ debug = { damage_tracking = 1 } })

local crtOn, curveOn = CRT_ON_START, CURVE_ON_START
local fsPaused = false   -- true mientras hay algo en pantalla completa
local gameOn   = false   -- true mientras hay un juego abierto
local greenOn  = false   -- true mientras está abierto el modo consola (rice-console)
local holdOff  = false   -- true durante el apagado de tubo (rice-off ya muestra la foto con el efecto)
local cursorHidden = false   -- true mientras arranca el modo consola (sin flecha en pantalla)
local function applyCursor()
    hl.config({ cursor = { invisible = holdOff or cursorHidden } })
end

-- Genera una copia de crt.frag con la curvatura y/o el modo verde activados
-- (las variantes se escriben en $XDG_RUNTIME_DIR y se regeneran solas)
local function buildVariant(curve, green)
    local f = io.open(CRT_SHADER, "r")
    if not f then return nil end
    local src = f:read("a"); f:close()
    if curve then src = src:gsub("#define CURVE_ON 0", "#define CURVE_ON 1", 1) end
    if green then src = src:gsub("#define GREEN_MODE 0", "#define GREEN_MODE 1", 1) end
    local path = CRT_CURVED:gsub("curved", (curve and "curved" or "flat") .. (green and "-green" or ""))
    local out = io.open(path, "w")
    if not out then return nil end
    out:write(src); out:close()
    return path
end

-- El ruido de las apps (Quickshell rice-static) sigue al CRT: se le avisa por
-- IPC solo cuando cambia, y el estado queda en un archivo por si rice-static
-- arranca/reinicia después.
local noiseState = nil
local function syncNoise(on)
    if noiseState == on then return end
    noiseState = on
    local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/rice-crt-state", "w")
    if f then f:write(on and "on" or "off"); f:close() end
    hl.exec_cmd("qs -c rice-static ipc call static setNoise " .. tostring(on))
end

local function apply()
    local path = ""
    local on = crtOn and not fsPaused and not gameOn and not holdOff
    syncNoise(on)
    if on then
        path = CRT_SHADER
        if curveOn or greenOn then path = buildVariant(curveOn, greenOn) or CRT_SHADER end
    end
    hl.config({
        decoration = { screen_shader = path },
        cursor     = { no_hardware_cursors = (on and curveOn) and 1 or 2 }, -- 2 = automático
    })
end

apply()

-- Modo consola: el menú de juegos (Quickshell rice-console) lo llama al abrir
-- y cerrar:  hyprctl dispatch "riceConsole(true)"  /  "riceConsole(false)"
function riceConsole(on)
    greenOn = on and true or false
    apply()
    return hl.dsp.exec_cmd("true")   -- hyprctl dispatch espera una acción: una vacía
end

-- Apagado de tubo (rice-off): saca una foto de la pantalla CON el efecto y
-- pide apagarlo mientras la anima, para no aplicarlo dos veces.
--   hyprctl dispatch "riceShaderHold(true)"  /  "riceShaderHold(false)"
function riceShaderHold(on)
    holdOff = on and true or false
    apply()
    applyCursor()   -- sin flecha flotando en el medio
    return hl.dsp.exec_cmd("true")
end

-- Ocultar el cursor (lo usa el modo consola mientras arranca)
--   hyprctl dispatch "riceCursorHide(true)"  /  "riceCursorHide(false)"
function riceCursorHide(on)
    cursorHidden = on and true or false
    applyCursor()
    return hl.dsp.exec_cmd("true")
end

hl.bind("SUPER + F12", function() crtOn = not crtOn; apply() end)
hl.bind("SUPER + F11", function() curveOn = not curveOn; crtOn = true; apply() end)

-- Pausa automática en pantalla completa. fullscreen_mode: 1 = maximizada,
-- 2 = pantalla completa de verdad (lo que pide un video al tocar ⛶ o la F).
-- Se revisa cada vez que algo podría cambiarlo: entrar/salir de pantalla
-- completa, cambiar de escritorio o de monitor, cerrar o mover una ventana.
-- No pisa a Super+F12: si apagaste el efecto a mano, sigue apagado al salir.
local function checkFullscreen()
    local ws = hl.get_active_workspace()
    local paused = ws ~= nil and ws.has_fullscreen and ws.fullscreen_mode == 2
    if paused ~= fsPaused then
        fsPaused = paused
        apply()
    end
end
for _, ev in ipairs({ "window.fullscreen", "workspace.active", "monitor.focused",
                      "window.close", "window.destroy", "window.move_to_workspace" }) do
    hl.on(ev, checkFullscreen)
end

-- Modo juego. Un juego se reconoce por:
--   · clase "steam_app_<número>" (juegos de Steam, también con Proton)
--   · gamescope (el compositor de Steam para juegos)
--   · content_type "game" (la ventana avisa que es un juego)
-- Para sumar otro juego a mano: agregá su clase a GAME_CLASSES
-- (la clase se ve con: hyprctl clients | grep class).
GAME_CLASSES = { "^steam_app_", "^gamescope", "^steam_proton" }
-- Apps de Steam que NO son juegos (no apagan el CRT). 431960 = Wallpaper Engine
NOT_GAMES = { "^steam_app_431960$" }
local function isGame(w)
    for _, pat in ipairs(NOT_GAMES) do
        if (w.class or ""):match(pat) or (w.initial_class or ""):match(pat) then return false end
    end
    if w.content_type == "game" then return true end
    for _, pat in ipairs(GAME_CLASSES) do
        if (w.class or ""):match(pat) or (w.initial_class or ""):match(pat) then return true end
    end
    return false
end
local function checkGame()
    local found = false
    for _, w in ipairs(hl.get_windows() or {}) do
        if w.mapped and isGame(w) then found = true; break end
    end
    if found ~= gameOn then
        gameOn = found
        hl.config({
            decoration = { blur = { enabled = not found } },
            animations = { enabled = not found },
        })
        apply()
    end
end
for _, ev in ipairs({ "window.open", "window.class", "window.close", "window.destroy" }) do
    hl.on(ev, checkGame)
end
checkGame()
