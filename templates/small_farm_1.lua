-- SMALL FARM 1 (Plains Village)
-- Auto-generated from Minecraft Wiki blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints
return {
    name = "SMALL FARM 1",
    w = 8, d = 8, h = 2,
    doorPos = {x=4, y=0, z=0},
    tags = {"small", "farm", "village"},
    blocks = (function()
        local b = {}
        local function add(x,y,z,t,f,h,s)
            local entry = {x=x, y=y, z=z, t=t}
            if f then entry.f = f end
            if h then entry.h = h end
            if s then entry.s = s end
            b[#b+1] = entry
        end

        add(0,0,0,"oak_log")
        add(1,0,0,"oak_log")
        add(2,0,0,"oak_log")
        add(3,0,0,"oak_log")
        add(4,0,0,"oak_log")
        add(5,0,0,"oak_log")
        add(6,0,0,"oak_log")
        add(7,0,0,"oak_log")
        add(0,0,1,"oak_log")
        add(1,0,1,"cobblestone")
        add(2,0,1,"cobblestone")
        add(4,0,1,"cobblestone")
        add(5,0,1,"cobblestone")
        add(6,0,1,"oak_log")
        add(7,0,1,"cobblestone")
        add(0,0,2,"oak_log")
        add(1,0,2,"cobblestone")
        add(2,0,2,"cobblestone")
        add(4,0,2,"cobblestone")
        add(5,0,2,"cobblestone")
        add(6,0,2,"oak_log")
        add(0,0,3,"oak_log")
        add(1,0,3,"cobblestone")
        add(2,0,3,"cobblestone")
        add(4,0,3,"cobblestone")
        add(5,0,3,"cobblestone")
        add(6,0,3,"oak_log")
        add(0,0,4,"oak_log")
        add(1,0,4,"cobblestone")
        add(2,0,4,"cobblestone")
        add(4,0,4,"cobblestone")
        add(5,0,4,"cobblestone")
        add(6,0,4,"oak_log")
        add(0,0,5,"oak_log")
        add(1,0,5,"cobblestone")
        add(2,0,5,"cobblestone")
        add(4,0,5,"cobblestone")
        add(5,0,5,"cobblestone")
        add(6,0,5,"oak_log")
        add(0,0,6,"oak_log")
        add(1,0,6,"cobblestone")
        add(2,0,6,"cobblestone")
        add(4,0,6,"cobblestone")
        add(5,0,6,"cobblestone")
        add(6,0,6,"oak_log")
        add(0,0,7,"oak_log")
        add(1,0,7,"oak_log")
        add(2,0,7,"oak_log")
        add(3,0,7,"oak_log")
        add(4,0,7,"oak_log")
        add(5,0,7,"oak_log")
        add(6,0,7,"oak_log")
        add(7,0,7,"oak_log")
        add(0,1,0,"composter")

        return b
    end)()
}
