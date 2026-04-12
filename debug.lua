-- debug helper: print NPC state every few seconds
local debugTimer = 0
function debugNPCs(npcs, dt)
    debugTimer = debugTimer + dt
    if debugTimer > 3 then
        debugTimer = 0
        for i, npc in ipairs(npcs) do
            local state = npc:getState()
            local bp = npc.blueprint
            local bpStatus = "none"
            if bp then
                bpStatus = bp.completed and "done" or ("step " .. bp.currentStep .. "/" .. #bp.steps)
            end
            print(string.format("NPC%d pos(%d,%d) task=%s bp=%s carry=%s temp=%.0f hunger=%.0f",
                i, npc.gx, npc.gz, state, bpStatus, 
                npc.carriedBlock and npc.carriedBlock.itemType or "nil",
                npc.temperature, npc.hunger))
        end
        print(string.format("World blocks: %d  Falling: %d", #(npc and npc.world or {blocks={}}).blocks, 0))
    end
end
