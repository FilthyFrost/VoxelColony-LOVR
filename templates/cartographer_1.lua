-- Cartographer 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Cartographer_1
-- 9x9 footprint (including porch), 8 layers
return {
    name = "Cartographer",
    w = 9, d = 9, h = 8,
    doorPos = {x=3, y=1, z=6},
    tags = {"village", "small", "workshop"},
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
        d = Dirt
        D = Dirt Path
        G = Grass Block
        C = Cobblestone
        O = Oak Log (vertical)
        P = Oak Planks
        L = Oak Stairs (north-facing)
        F = Oak Stairs (east-facing, rot90)
        Z = Oak Stairs (south-facing, rot180)
        > = Oak Stairs (west-facing, rot270)
        N = Oak Slab
        E = Oak Trapdoor
        H = Oak Fence
        U = Oak Pressure Plate
        z = Oak Door (top)
        B = Oak Door (bottom)
        I = Glass Pane
        t = Glass Pane (rot90, east-west)
        R = White Carpet
        r = Yellow Carpet
        i = Torch
        o = Torch (south-facing, rot180)
        p = Poppy
        b = Dandelion
        c = Chest (east-facing, rot90)
        T = Cartography Table

        Grid: rows=z (top=0), cols=x (left=0)
        ]]

        -- Layer 0 (y=0): Foundation
        -- ddddd  (z=0)
        -- dPPPd  (z=1)
        -- dPPPd  (z=2)
        -- dPPPd  (z=3)
        -- dPPPd  (z=4)
        -- dPPPd  (z=5)
        -- ddCdd  (z=6)
        -- ddDdd  (z=7)
        --   D    (z=8)
        for x=0,4 do add(x,0,0,"dirt") end
        add(0,0,1,"dirt"); add(1,0,1,"oak_planks"); add(2,0,1,"oak_planks")
        add(3,0,1,"oak_planks"); add(4,0,1,"dirt")
        add(0,0,2,"dirt"); add(1,0,2,"oak_planks"); add(2,0,2,"oak_planks")
        add(3,0,2,"oak_planks"); add(4,0,2,"dirt")
        add(0,0,3,"dirt"); add(1,0,3,"oak_planks"); add(2,0,3,"oak_planks")
        add(3,0,3,"oak_planks"); add(4,0,3,"dirt")
        add(0,0,4,"dirt"); add(1,0,4,"oak_planks"); add(2,0,4,"oak_planks")
        add(3,0,4,"oak_planks"); add(4,0,4,"dirt")
        add(0,0,5,"dirt"); add(1,0,5,"oak_planks"); add(2,0,5,"oak_planks")
        add(3,0,5,"oak_planks"); add(4,0,5,"dirt")
        add(0,0,6,"dirt"); add(1,0,6,"dirt"); add(2,0,6,"cobblestone")
        add(3,0,6,"dirt"); add(4,0,6,"dirt")
        add(0,0,7,"dirt"); add(1,0,7,"dirt"); add(2,0,7,"dirt_path")
        add(3,0,7,"dirt"); add(4,0,7,"dirt")
        add(2,0,8,"dirt_path")

        -- Layer 1 (y=1): Main room
        -- OCCCO  (z=0)
        -- CrRrC  (z=1)
        -- CRTRC  (z=2)  T=cartography table
        -- CrRrC  (z=3)
        -- C   C  (z=4)
        -- CH cC  (z=5)  H=fence, c=chest
        -- OCBCO  (z=6)  B=door bottom
        -- EGG GGE(z=7)  E=trapdoor, G=grass
        -- EE EE  (z=8)
        add(0,1,0,"oak_log"); add(1,1,0,"cobblestone"); add(2,1,0,"cobblestone")
        add(3,1,0,"cobblestone"); add(4,1,0,"oak_log")
        add(0,1,1,"cobblestone"); add(1,1,1,"yellow_carpet")
        add(2,1,1,"white_carpet"); add(3,1,1,"yellow_carpet"); add(4,1,1,"cobblestone")
        add(0,1,2,"cobblestone"); add(1,1,2,"white_carpet")
        add(2,1,2,"cartography_table"); add(3,1,2,"white_carpet"); add(4,1,2,"cobblestone")
        add(0,1,3,"cobblestone"); add(1,1,3,"yellow_carpet")
        add(2,1,3,"white_carpet"); add(3,1,3,"yellow_carpet"); add(4,1,3,"cobblestone")
        add(0,1,4,"cobblestone"); add(4,1,4,"cobblestone")
        add(0,1,5,"cobblestone"); add(1,1,5,"oak_fence")
        add(3,1,5,"chest","east"); add(4,1,5,"cobblestone")
        add(0,1,6,"oak_log"); add(1,1,6,"cobblestone")
        add(2,1,6,"oak_door","south"); add(3,1,6,"cobblestone"); add(4,1,6,"oak_log")
        -- z=7: porch with trapdoors
        add(0,1,7,"oak_trapdoor"); add(1,1,7,"grass_block")
        add(2,1,7,"grass_block"); add(4,1,7,"grass_block")
        add(5,1,7,"grass_block"); add(6,1,7,"oak_trapdoor")
        -- z=8: trapdoors
        add(0,1,8,"oak_trapdoor"); add(1,1,8,"oak_trapdoor")
        add(3,1,8,"oak_trapdoor"); add(4,1,8,"oak_trapdoor")

        -- Layer 2 (y=2): Upper walls with windows
        -- OCtCO  (z=0)  t=glass pane east-west
        -- C   C  (z=1)
        -- I   I  (z=2)  I=glass pane
        -- C   C  (z=3)
        -- I   I  (z=4)
        -- CU  C  (z=5)  U=pressure plate
        -- OCzCO  (z=6)  z=door top
        -- bp bp  (z=7)  b=dandelion, p=poppy
        add(0,2,0,"oak_log"); add(1,2,0,"cobblestone")
        add(2,2,0,"glass_pane","east"); add(3,2,0,"cobblestone"); add(4,2,0,"oak_log")
        add(0,2,1,"cobblestone"); add(4,2,1,"cobblestone")
        add(0,2,2,"glass_pane"); add(4,2,2,"glass_pane")
        add(0,2,3,"cobblestone"); add(4,2,3,"cobblestone")
        add(0,2,4,"glass_pane"); add(4,2,4,"glass_pane")
        add(0,2,5,"cobblestone"); add(1,2,5,"oak_pressure_plate")
        add(4,2,5,"cobblestone")
        add(0,2,6,"oak_log"); add(1,2,6,"cobblestone")
        add(2,2,6,"oak_door","south"); add(3,2,6,"cobblestone"); add(4,2,6,"oak_log")
        -- z=7: flowers
        add(0,2,7,"dandelion"); add(1,2,7,"poppy")
        add(3,2,7,"dandelion"); add(4,2,7,"poppy")

        -- Layer 3 (y=3): Wall tops
        -- OCCCO  (z=0)
        -- C   C  (z=1)
        -- C   C  (z=2)
        -- C   C  (z=3)
        -- C   C  (z=4)
        -- C   C  (z=5)
        -- OCCCO  (z=6)
        add(0,3,0,"oak_log"); add(1,3,0,"cobblestone"); add(2,3,0,"cobblestone")
        add(3,3,0,"cobblestone"); add(4,3,0,"oak_log")
        for z=1,5 do add(0,3,z,"cobblestone"); add(4,3,z,"cobblestone") end
        add(0,3,6,"oak_log"); add(1,3,6,"cobblestone"); add(2,3,6,"cobblestone")
        add(3,3,6,"cobblestone"); add(4,3,6,"oak_log")

        -- Layer 4 (y=4): Roof layer 1
        -- ZL   ZL  (z=-1, extending beyond building)
        -- ZOOOOOL  (z=0)
        -- ZO o OL  (z=1)  o=torch south
        -- ZO   OL  (z=2)
        -- ZO   OL  (z=3)
        -- ZO   OL  (z=4)
        -- ZO i OL  (z=5)  i=torch
        -- ZOOOOOL  (z=6)
        -- ZL o ZL  (z=7)

        -- Using offset: wiki grid rows map z=-1 to z=7
        -- z=-1 equivalent (outside, skip or use z offset)
        -- We'll keep the roof within bounds by not adding z=-1
        -- Overhang south at z=-1 (not adding)

        -- z=0: ZOOOOOL (cols 0-6, Z=stairs south, L=stairs north)
        add(0,4,0,"oak_stairs","south"); add(1,4,0,"oak_log"); add(2,4,0,"oak_log")
        add(3,4,0,"oak_log"); add(4,4,0,"oak_log"); add(5,4,0,"oak_log")
        add(6,4,0,"oak_stairs","north")
        -- z=1
        add(0,4,1,"oak_stairs","south"); add(1,4,1,"oak_log")
        add(3,4,1,"torch","south") -- o
        add(5,4,1,"oak_log"); add(6,4,1,"oak_stairs","north")
        -- z=2
        add(0,4,2,"oak_stairs","south"); add(1,4,2,"oak_log")
        add(5,4,2,"oak_log"); add(6,4,2,"oak_stairs","north")
        -- z=3
        add(0,4,3,"oak_stairs","south"); add(1,4,3,"oak_log")
        add(5,4,3,"oak_log"); add(6,4,3,"oak_stairs","north")
        -- z=4
        add(0,4,4,"oak_stairs","south"); add(1,4,4,"oak_log")
        add(5,4,4,"oak_log"); add(6,4,4,"oak_stairs","north")
        -- z=5
        add(0,4,5,"oak_stairs","south"); add(1,4,5,"oak_log")
        add(3,4,5,"torch") -- i=torch
        add(5,4,5,"oak_log"); add(6,4,5,"oak_stairs","north")
        -- z=6
        add(0,4,6,"oak_stairs","south"); add(1,4,6,"oak_log"); add(2,4,6,"oak_log")
        add(3,4,6,"oak_log"); add(4,4,6,"oak_log"); add(5,4,6,"oak_log")
        add(6,4,6,"oak_stairs","north")
        -- z=7 overhang
        add(0,4,7,"oak_stairs","south"); add(1,4,7,"oak_stairs","north")
        add(3,4,7,"torch","south")
        add(4,4,7,"oak_stairs","south"); add(5,4,7,"oak_stairs","north")

        -- Layer 5 (y=5): Roof layer 2
        -- ZL ZL  (z=0)
        -- ZCCCL  (z=1)
        -- Z   L  (z=2)
        -- Z   L  (z=3)
        -- Z   L  (z=4)
        -- Z   L  (z=5)
        -- Z   L  (z=6) -- original wiki might differ
        -- ZCCCL  (z=7) -- original wiki might differ
        -- ZL ZL  (z=8) -- original wiki might differ

        -- Adjusting based on wiki data:
        add(0,5,0,"oak_stairs","south"); add(1,5,0,"oak_stairs","north")
        add(4,5,0,"oak_stairs","south"); add(5,5,0,"oak_stairs","north")
        add(0,5,1,"oak_stairs","south"); add(1,5,1,"cobblestone")
        add(2,5,1,"cobblestone"); add(3,5,1,"cobblestone")
        add(4,5,1,"oak_stairs","north")
        for z=2,5 do
            add(0,5,z,"oak_stairs","south"); add(4,5,z,"oak_stairs","north")
        end
        add(0,5,6,"oak_stairs","south"); add(1,5,6,"cobblestone")
        add(2,5,6,"cobblestone"); add(3,5,6,"cobblestone")
        add(4,5,6,"oak_stairs","north")
        add(0,5,7,"oak_stairs","south"); add(1,5,7,"oak_stairs","north")
        add(4,5,7,"oak_stairs","south"); add(5,5,7,"oak_stairs","north")

        -- Layer 6 (y=6): Roof layer 3
        -- ZPL (each row z=0 to z=6, 3 wide at cols 1-3)
        for z=0,6 do
            add(0,6,z,"oak_stairs","south")
            add(1,6,z,"oak_planks")
            add(2,6,z,"oak_stairs","north")
        end

        -- Layer 7 (y=7): Ridge slabs
        -- N (each row z=0 to z=6, single column)
        for z=0,6 do
            add(1,7,z,"oak_slab",nil,"bottom")
        end

        return b
    end)()
}
