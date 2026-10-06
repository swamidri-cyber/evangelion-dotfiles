-- ─────────────────────────────────────────────────────────────────────────────
--  dolphin-hide.lua — si el video se abrió desde Dolphin, Dolphin se esconde
--  (escritorio oculto "special:minimizado") mientras el video se reproduce.
--  Vuelve a su escritorio al pausar o al cerrar mpv; al reanudar se esconde
--  de nuevo.
--
--  "Abierto desde Dolphin" = Dolphin es proceso padre de mpv, o era la ventana
--  activa al arrancar mpv. Usa hyprctl (Hyprland con config Lua).
-- ─────────────────────────────────────────────────────────────────────────────
local utils = require "mp.utils"

local dolphin = nil     -- { address, workspace }
local hidden = false

local function run(args)
    local r = mp.command_native({ name = "subprocess", args = args, capture_stdout = true, playback_only = false })
    return r and r.status == 0 and r.stdout or nil
end

local function ppid(pid)
    local f = io.open("/proc/" .. pid .. "/stat", "r")
    if not f then return nil end
    local s = f:read("*l"); f:close()
    -- el nombre va entre paréntesis y puede tener espacios: el ppid es el 2º campo después de ")"
    return tonumber(s:match("%)%s+%S+%s+(%d+)"))
end

local function comm(pid)
    local f = io.open("/proc/" .. pid .. "/comm", "r")
    if not f then return "" end
    local s = f:read("*l") or ""; f:close()
    return s
end

local function find_dolphin()
    local out = run({ "hyprctl", "clients", "-j" })
    local clients = out and utils.parse_json(out)
    if not clients then return nil end
    local byPid = {}
    for _, c in ipairs(clients) do
        if (c.class or ""):match("dolphin") then byPid[c.pid] = c end
    end
    -- ¿Dolphin es padre (o abuelo…) de mpv?
    local pid = utils.getpid()
    for _ = 1, 8 do
        pid = ppid(pid)
        if not pid or pid <= 1 then break end
        if byPid[pid] then return byPid[pid] end
        if comm(pid) == "dolphin" then
            for _, c in pairs(byPid) do if c.pid == pid then return c end end
        end
    end
    -- Si no, ¿Dolphin era la ventana activa cuando se abrió el video?
    local act = run({ "hyprctl", "activewindow", "-j" })
    local a = act and utils.parse_json(act)
    if a and (a.class or ""):match("dolphin") then return a end
    return nil
end

local function move(ws)
    if not dolphin then return end
    run({ "hyprctl", "dispatch", string.format(
        'hl.dsp.window.move({ workspace = %s, window = "address:%s", follow = false })', ws, dolphin.address) })
end

local function hide()
    if dolphin and not hidden then move('"special:minimizado"'); hidden = true end
end

local function show(focus)
    if dolphin and hidden then
        move(tostring(dolphin.workspace))
        hidden = false
        if focus then
            run({ "hyprctl", "dispatch", string.format('hl.dsp.focus({ window = "address:%s" })', dolphin.address) })
        end
    end
end

mp.register_event("file-loaded", function()
    if dolphin == nil then
        local c = find_dolphin()
        if not c then dolphin = false; return end
        dolphin = { address = c.address, workspace = c.workspace and c.workspace.id or 1 }
        mp.msg.info("Dolphin " .. dolphin.address .. " (escritorio " .. dolphin.workspace .. ") se esconde mientras se reproduce")
    end
    if not mp.get_property_native("pause") then hide() end
end)

mp.observe_property("pause", "bool", function(_, paused)
    if not dolphin then return end
    if paused then show(false) else hide() end
end)

-- Terminó el video (o se cerró mpv): Dolphin vuelve y queda enfocado
mp.register_event("shutdown", function() show(true) end)
mp.register_event("end-file", function(e)
    if e.reason == "eof" and mp.get_property_native("idle-active") then show(true) end
end)
