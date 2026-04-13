-- debuglog.lua — Modular debug logging
-- Each module: /tmp/lovr_MODULE.log

local DL = {}
local gameTime = 0

function DL.init()
    local mods = {"main", "npc", "build", "combat", "social", "world", "render", "perf"}
    for _, mod in ipairs(mods) do
        local f = io.open("/tmp/lovr_" .. mod .. ".log", "w")
        if f then f:write("=== " .. mod .. " ===\n"); f:close() end
    end
end

function DL.setTime(t) gameTime = t end

function DL.write(mod, fmt, ...)
    local f = io.open("/tmp/lovr_" .. mod .. ".log", "a")
    if f then
        local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
        f:write(string.format("[%.1fs] %s\n", gameTime, msg))
        f:close()
    end
end

function DL.summary(npcs, blockCount, fallingItems, markerCount)
    local alive = 0
    if npcs then for _, n in ipairs(npcs) do if not n.dead then alive = alive + 1 end end end
    DL.write("main", "TICK alive:%d npcs:%d blocks:%d falling:%d markers:%d",
        alive, npcs and #npcs or 0, blockCount or 0,
        fallingItems and #fallingItems or 0, markerCount or 0)
end

local pf = {frames = 0, dt = 0, last = 0}
function DL.perfFrame(dt)
    pf.frames = pf.frames + 1
    pf.dt = pf.dt + dt
    if gameTime - pf.last >= 5 then
        if pf.frames > 0 then
            DL.write("perf", "fps:%.1f avg:%.1fms", pf.frames / pf.dt, pf.dt / pf.frames * 1000)
        end
        pf.frames = 0; pf.dt = 0; pf.last = gameTime
    end
end

return DL
