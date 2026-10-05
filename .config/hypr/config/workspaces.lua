-- Workspace rules wiki https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Add your workspace rules here. Increment the workspace number as you go. Do not have duplicate workspaces.
hl.workspace_rule({ workspace = "name:gaming", monitor = PRIMARY_MONITOR, default = true })
-- Escritorios 1..NUM_WPM (variables.lua) siempre presentes, aunque estén vacíos,
-- así la barra muestra todos (一 二 三 四 五 六).
for i = 1, NUM_WPM do
    hl.workspace_rule({ workspace = tostring(i), monitor = MONITOR1, default = (i == 1), persistent = true })
end
-- hl.workspace_rule({ workspace = "4", monitor = MONITOR2, default = true, persistent = true })
-- hl.workspace_rule({ workspace = "5", monitor = MONITOR2, default = true, persistent = true })
-- hl.workspace_rule({ workspace = "6", monitor = MONITOR2, default = true, persistent = true })

-- For other layouts such as scrolling, see example below
-- hl.workspace_rule({ workspace = "1", monitor = MONITOR1, default = true, persistent = true, layout = "scrolling" })
