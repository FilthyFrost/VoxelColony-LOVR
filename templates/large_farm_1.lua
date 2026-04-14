-- Large Farm 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Large_Farm_1
-- 13x9 footprint, 2 layers, oak log bordered farm with water channels
return {
    name = "Large Farm",
    w = 13, d = 9, h = 2,
    doorPos = nil, -- no door, open farm
    tags = {"village", "farm", "large"},
    blocks = (function()
        local b = {}
        local function add(x,y,z,t,f,h,s)
            local entry = {x=x, y=y, z=z, t=t}
            if f then entry.f = f end
            if h then entry.h = h end
            if s then entry.s = s end
            b[#b+1] = entry
        end

        --[[
        Wiki grid legend:
        O = Oak Log (vertical)
        W = Water
        F = Farmland (moist)
        w = Wheat
        C = Composter
        d = Dirt

        Grid: 13 columns (x=0-12), 9 rows (z=0-8)
        Leading space in wiki grid = offset by 1, so actual grid 15 wide
        but content occupies 13 positions
        ]]

        -- Layer 1 (y=0): Farm structure
        -- OOOOOOOOOOOOO  (z=0)
        -- OdFWFFOFFWFdO  (z=1)
        -- OFFWFFOFFWFFO  (z=2)
        -- OFFWFFOFFWFFO  (z=3)
        -- OFFWFFOFFWFFO  (z=4)
        -- OFFWFFOFFWFFO  (z=5)
        -- OFFWFFOFFWFFO  (z=6)
        -- OFFWFFOFFWFFO  (z=7)
        -- OOOOOOOOOOOOO  (z=8)

        -- z=0: all oak logs
        for x=0,12 do add(x,0,0,"oak_log") end

        -- z=1: OdFWFFOFFWFdO
        add(0,0,1,"oak_log"); add(1,0,1,"dirt"); add(2,0,1,"farmland")
        add(3,0,1,"water"); add(4,0,1,"farmland"); add(5,0,1,"farmland")
        add(6,0,1,"oak_log"); add(7,0,1,"farmland"); add(8,0,1,"farmland")
        add(9,0,1,"water"); add(10,0,1,"farmland"); add(11,0,1,"dirt")
        add(12,0,1,"oak_log")

        -- z=2-7: OFFWFFOFFWFFO
        for z=2,7 do
            add(0,0,z,"oak_log"); add(1,0,z,"farmland"); add(2,0,z,"farmland")
            add(3,0,z,"water"); add(4,0,z,"farmland"); add(5,0,z,"farmland")
            add(6,0,z,"oak_log"); add(7,0,z,"farmland"); add(8,0,z,"farmland")
            add(9,0,z,"water"); add(10,0,z,"farmland"); add(11,0,z,"farmland")
            add(12,0,z,"oak_log")
        end

        -- z=8: all oak logs
        for x=0,12 do add(x,0,8,"oak_log") end

        -- Layer 2 (y=1): Crops + composters
        -- (empty border)
        -- Cw ww ww wC   (z=1) C=composter, w=wheat
        -- ww ww ww ww   (z=2-7)
        -- (empty z=8)

        -- z=1: Cw.ww.ww.wC  (composter at x=1 and x=11, wheat elsewhere)
        add(1,1,1,"composter"); add(2,1,1,"wheat")
        add(4,1,1,"wheat"); add(5,1,1,"wheat")
        add(7,1,1,"wheat"); add(8,1,1,"wheat")
        add(10,1,1,"wheat"); add(11,1,1,"composter")

        -- z=2-7: wheat on all farmland positions
        for z=2,7 do
            add(1,1,z,"wheat"); add(2,1,z,"wheat")
            add(4,1,z,"wheat"); add(5,1,z,"wheat")
            add(7,1,z,"wheat"); add(8,1,z,"wheat")
            add(10,1,z,"wheat"); add(11,1,z,"wheat")
        end

        return b
    end)()
}
