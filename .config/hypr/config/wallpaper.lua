-- ─────────────────────────────────────────────────────────────────────────────
--  Rice: fondo animado (Wallpaper Engine) que no gasta de más.
--
--  linux-wallpaperengine (lo lanza scripts/wallpaper.sh) dibuja el fondo
--  animado. Si en el escritorio que estás mirando hay al menos una ventana, el
--  fondo queda tapado y no tiene sentido animarlo: se congela el proceso
--  (SIGSTOP, consumo ~0, queda el último cuadro). Al volver a un escritorio
--  vacío se descongela (SIGCONT) y sigue donde estaba.
--  Si hay varios monitores, se congela solo cuando TODOS están tapados.
--  En pantalla completa linux-wallpaperengine además se pausa solo.
-- ─────────────────────────────────────────────────────────────────────────────
local wePaused = nil   -- nil = todavía no se decidió nada

local function covered(m)
    local sp = m.active_special_workspace         -- cajón (Super+Alt+S) abierto
    if sp and sp.windows > 0 then return true end
    local ws = m.active_workspace
    return ws ~= nil and ws.windows > 0
end

local function checkWallpaper()
    local all = true
    for _, m in ipairs(hl.get_monitors() or {}) do
        if not covered(m) then all = false; break end
    end
    if all ~= wePaused then
        wePaused = all
        -- "linux-wallpaper" = nombre del proceso (Linux lo corta a 15 letras)
        hl.exec_cmd("pkill -" .. (all and "STOP" or "CONT") .. " -x linux-wallpaper")
    end
end

-- Los eventos llegan un instante antes de que se actualice el conteo de
-- ventanas: se revisa 100 ms después.
local function later() hl.timer(checkWallpaper, { timeout = 100, type = "oneshot" }) end
for _, ev in ipairs({ "window.open", "window.close", "window.destroy", "window.move_to_workspace",
                      "workspace.active", "monitor.focused" }) do
    hl.on(ev, later)
end

-- Al lanzar un fondo nuevo, wallpaper.sh lo arranca andando: se olvida el
-- estado para que la próxima revisión vuelva a mandar la señal que haga falta.
-- (wallpaper.sh llama a: hyprctl dispatch rice_wallpaper_refresh)
function rice_wallpaper_refresh()
    wePaused = nil
    later()
end
