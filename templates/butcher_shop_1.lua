-- Butcher Shop 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Butcher_Shop_1
-- Main building ~9x6, attached fenced yard ~7x5, 8 layers
return {
    name = "Butcher Shop",
    w = 11, d = 14, h = 8,
    doorPos = {x=2, y=2, z=5},
    tags = {"village", "medium", "shop"},
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
        A = Cobblestone
        B = Cobblestone Wall
        C = Potted Dandelion
        D = Dirt
        E = Double Smooth Stone Slab
        F = Glass Pane
        G = Glass Pane (rot90, east-west)
        H = Grass Block
        I = Hay Bale
        J = Oak Door (bottom)
        K = Oak Door (top)
        L = Oak Fence
        M = Oak Log (vertical)
        N = Oak Log (east-west, rot90)
        O = Oak Planks
        P = Oak Pressure Plate
        Q = Oak Stairs (north-facing)
        R = Oak Stairs (south-facing, rot180)
        S = Oak Stairs (west-facing, rot270)
        T = Oak Stairs (east-facing, rot90)
        U = Smoker (west-facing, rot270)
        V = Torch
        W = Torch (south-facing, rot180)
        X = Torch (west-facing, rot270)

        Grid: rows=z (top=0), cols=x (left=0)
        Grid is ~11 wide, up to 14 deep depending on layer
        ]]

        -- Layer 1 (y=0): Foundation floor
        -- MAAAMAAAM  (z=0, x=0-8)
        -- AOOOOEEEA  (z=1)
        -- AOOOOEEEA  (z=2) -- T prefix means stair but here col 0 is T=Oak Stairs east
        -- AOOOOEEEA  (z=3)
        -- AOOOOOOOA  (z=4)
        -- MAAAAAAAM  (z=5)
        -- HHDDAHH    (z=6)
        -- HHHHHHH    (z=7)
        -- HHHHHHH    (z=8)
        -- HHHHHHH    (z=9)
        -- HHHHHHH    (z=10)

        -- z=0
        add(0,0,0,"oak_log"); add(1,0,0,"cobblestone"); add(2,0,0,"cobblestone")
        add(3,0,0,"cobblestone"); add(4,0,0,"oak_log"); add(5,0,0,"cobblestone")
        add(6,0,0,"cobblestone"); add(7,0,0,"cobblestone"); add(8,0,0,"oak_log")
        -- z=1
        add(0,0,1,"cobblestone")
        for x=1,4 do add(x,0,1,"oak_planks") end
        for x=5,7 do add(x,0,1,"smooth_stone_slab") end -- E = double smooth stone slab
        add(8,0,1,"cobblestone")
        -- z=2 (wiki shows T prefix for oak stairs east at col -1, skip those outside bounds)
        add(0,0,2,"cobblestone")
        for x=1,4 do add(x,0,2,"oak_planks") end
        for x=5,7 do add(x,0,2,"smooth_stone_slab") end
        add(8,0,2,"cobblestone")
        -- z=3
        add(0,0,3,"cobblestone")
        for x=1,4 do add(x,0,3,"oak_planks") end
        for x=5,7 do add(x,0,3,"smooth_stone_slab") end
        add(8,0,3,"cobblestone")
        -- z=4
        add(0,0,4,"cobblestone")
        for x=1,7 do add(x,0,4,"oak_planks") end
        add(8,0,4,"cobblestone")
        -- z=5
        add(0,0,5,"oak_log"); add(1,0,5,"cobblestone"); add(2,0,5,"cobblestone")
        add(3,0,5,"cobblestone"); add(4,0,5,"cobblestone"); add(5,0,5,"cobblestone")
        add(6,0,5,"cobblestone"); add(7,0,5,"cobblestone"); add(8,0,5,"oak_log")
        -- z=6: yard area
        add(2,0,6,"grass_block"); add(3,0,6,"grass_block")
        add(4,0,6,"dirt"); add(5,0,6,"dirt")
        add(6,0,6,"cobblestone")
        add(7,0,6,"grass_block"); add(8,0,6,"grass_block")
        -- z=7 to z=10: grass
        for z=7,10 do for x=2,8 do add(x,0,z,"grass_block") end end

        -- Layer 2 (y=1): Main structure walls + yard fences
        -- MAAAMAAAM  (z=0)
        -- ASLT  E A  (z=1) -- S=stairs west, L=fence, T=stairs east
        -- J     E A  (z=2) -- J=door bottom
        -- J       A  (z=3)
        -- AO     UA  (z=4) -- U=smoker
        -- MAAAAAJAM  (z=5) -- J=door bottom at x=6
        -- L II  L    (z=6)
        -- L     L    (z=7)
        -- L     L    (z=8)
        -- L     L    (z=9)
        -- LLLLLLL    (z=10)

        -- z=0
        add(0,1,0,"oak_log"); add(1,1,0,"cobblestone"); add(2,1,0,"cobblestone")
        add(3,1,0,"cobblestone"); add(4,1,0,"oak_log"); add(5,1,0,"cobblestone")
        add(6,1,0,"cobblestone"); add(7,1,0,"cobblestone"); add(8,1,0,"oak_log")
        -- z=1
        add(0,1,1,"cobblestone")
        add(1,1,1,"oak_stairs","west")
        add(2,1,1,"oak_fence")
        add(3,1,1,"oak_stairs","east")
        add(6,1,1,"smooth_stone_slab")
        add(8,1,1,"cobblestone")
        -- z=2
        add(0,1,2,"oak_door","south") -- J=door bottom
        add(6,1,2,"smooth_stone_slab")
        add(8,1,2,"cobblestone")
        -- z=3
        add(0,1,3,"oak_door","south")
        add(8,1,3,"cobblestone")
        -- z=4
        add(0,1,4,"cobblestone"); add(1,1,4,"oak_planks")
        add(7,1,4,"smoker","west"); add(8,1,4,"cobblestone")
        -- z=5
        add(0,1,5,"oak_log"); add(1,1,5,"cobblestone"); add(2,1,5,"cobblestone")
        add(3,1,5,"cobblestone"); add(4,1,5,"cobblestone"); add(5,1,5,"cobblestone")
        add(6,1,5,"oak_door","south"); add(7,1,5,"cobblestone"); add(8,1,5,"oak_log")
        -- z=6
        add(2,1,6,"oak_fence"); add(4,1,6,"hay_bale"); add(5,1,6,"hay_bale")
        add(8,1,6,"oak_fence")
        -- z=7 to z=9
        for z=7,9 do add(2,1,z,"oak_fence"); add(8,1,z,"oak_fence") end
        -- z=10
        for x=2,8 do add(x,1,10,"oak_fence") end

        -- Layer 3 (y=2): Upper walls with windows
        --   V         (z=0 area, torch above)
        -- MMGMMMGMM   (z=1) -- corrected row
        -- XM P     M  (z=2) -- X=torch west
        -- K       F   (z=3) -- K=door top, F=glass pane
        -- K       F   (z=4)
        -- XMC     BM  (z=5) -- C=potted dandelion, B=cobblestone wall
        -- MNGGNNKAM   (z=6) -- N=oak log east-west, K=door top
        -- V     V     (z=9 area, torches)

        -- z=0 area: torch
        add(4,2,0,"torch")
        -- z=1
        add(0,2,1,"oak_log"); add(1,2,1,"oak_log")
        add(2,2,1,"glass_pane","east"); add(3,2,1,"oak_log")
        add(4,2,1,"oak_log"); add(5,2,1,"oak_log")
        add(6,2,1,"glass_pane","east"); add(7,2,1,"oak_log"); add(8,2,1,"oak_log")
        -- z=2
        add(0,2,2,"torch","west") -- X
        add(1,2,2,"oak_log")
        add(3,2,2,"oak_pressure_plate")
        add(8,2,2,"oak_log")
        -- z=3
        add(0,2,3,"oak_door","south") -- K = door top (upper half, decorative)
        add(8,2,3,"glass_pane")
        -- z=4
        add(0,2,4,"oak_door","south") -- K
        add(8,2,4,"glass_pane")
        -- z=5
        add(0,2,5,"torch","west") -- X
        add(1,2,5,"oak_log")
        add(2,2,5,"potted_dandelion")
        add(7,2,5,"cobblestone_wall")
        add(8,2,5,"oak_log")
        -- z=6
        add(0,2,6,"oak_log"); add(1,2,6,"oak_log")
        add(2,2,6,"glass_pane","east"); add(3,2,6,"glass_pane","east")
        add(4,2,6,"oak_log"); add(5,2,6,"oak_log")
        add(6,2,6,"oak_door","south") -- K = door top
        add(7,2,6,"cobblestone"); add(8,2,6,"oak_log")
        -- Torches at z=9
        add(2,2,9,"torch"); add(8,2,9,"torch")

        -- Layer 4 (y=3): Roof start
        -- RRRRRRRRRRR  (z=0, cols -1 to 9 = 0 to 10)
        -- QMOOOOOOOMQ  (z=1)
        -- A W     A    (z=2) -- W=torch south
        -- A       A    (z=3)
        -- A       A    (z=4)
        -- A     VBA    (z=5) -- V=torch, B=cobblestone wall
        -- RMOOOOOOOMR  (z=6)
        -- QQQQQQQQQQQ  (z=7)
        for x=0,10 do add(x,3,0,"oak_stairs","south") end -- R
        add(0,3,1,"oak_stairs","north"); add(1,3,1,"oak_log") -- Q, M
        for x=2,7 do add(x,3,1,"oak_planks") end
        add(8,3,1,"oak_log"); add(9,3,1,"oak_stairs","north")
        add(0,3,2,"cobblestone"); add(2,3,2,"torch","south") -- W
        add(8,3,2,"cobblestone")
        add(0,3,3,"cobblestone"); add(8,3,3,"cobblestone")
        add(0,3,4,"cobblestone"); add(8,3,4,"cobblestone")
        add(0,3,5,"cobblestone"); add(6,3,5,"torch"); add(7,3,5,"cobblestone_wall")
        add(8,3,5,"cobblestone")
        add(0,3,6,"oak_stairs","south"); add(1,3,6,"oak_log") -- R, M
        for x=2,7 do add(x,3,6,"oak_planks") end
        add(8,3,6,"oak_log"); add(9,3,6,"oak_stairs","south") -- R
        for x=0,10 do add(x,3,7,"oak_stairs","north") end -- Q

        -- Layer 5 (y=4): Roof middle
        -- RRRRRRRRRRR  (z=1)
        -- QAOOOOOOOAQ  (z=2)
        -- A       A    (z=3)
        -- A       A    (z=4)
        -- RAOOOOOOBAR  (z=5)
        -- QQQQQQQQQQQ  (z=6)
        for x=0,10 do add(x,4,1,"oak_stairs","south") end
        add(0,4,2,"oak_stairs","north"); add(1,4,2,"cobblestone")
        for x=2,7 do add(x,4,2,"oak_planks") end
        add(8,4,2,"cobblestone"); add(9,4,2,"oak_stairs","north")
        add(0,4,3,"cobblestone"); add(8,4,3,"cobblestone")
        add(0,4,4,"cobblestone"); add(8,4,4,"cobblestone")
        add(0,4,5,"oak_stairs","south"); add(1,4,5,"cobblestone")
        for x=2,6 do add(x,4,5,"oak_planks") end
        add(7,4,5,"cobblestone_wall"); add(8,4,5,"cobblestone")
        add(9,4,5,"oak_stairs","south")
        for x=0,10 do add(x,4,6,"oak_stairs","north") end

        -- Layer 6 (y=5): Roof upper
        -- RRRRRRRRRRR  (z=2)
        -- QAOOOOOOOAQ  (z=3)
        -- RAOOOOOOOAR  (z=4)
        -- QQQQQQQQAQQ  (z=5) -- has A (cobblestone) at x=8
        for x=0,10 do add(x,5,2,"oak_stairs","south") end
        add(0,5,3,"oak_stairs","north"); add(1,5,3,"cobblestone")
        for x=2,7 do add(x,5,3,"oak_planks") end
        add(8,5,3,"cobblestone"); add(9,5,3,"oak_stairs","north")
        add(0,5,4,"oak_stairs","south"); add(1,5,4,"cobblestone")
        for x=2,7 do add(x,5,4,"oak_planks") end
        add(8,5,4,"cobblestone"); add(9,5,4,"oak_stairs","south")
        for x=0,7 do add(x,5,5,"oak_stairs","north") end
        add(8,5,5,"cobblestone")
        add(9,5,5,"oak_stairs","north"); add(10,5,5,"oak_stairs","north")

        -- Layer 7 (y=6): Roof peak
        -- RRRRRRRRRRR  (z=3)
        -- QQQQQQQQQQQ  (z=4)
        -- B            (z=5, x=8) -- cobblestone wall
        for x=0,10 do add(x,6,3,"oak_stairs","south") end
        for x=0,10 do add(x,6,4,"oak_stairs","north") end
        add(8,6,5,"cobblestone_wall")

        -- Layer 8 (y=7): Chimney top
        -- B (z=5, x=8)
        add(8,7,5,"cobblestone_wall")

        return b
    end)()
}
