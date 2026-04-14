-- Fletcher House 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Fletcher_House_1
-- L-shaped house with yard, 7 layers
-- Note: All oak slabs in layer 4 are bottom slabs
return {
    name = "Fletcher House",
    w = 13, d = 10, h = 7,
    doorPos = {x=5, y=1, z=6},
    tags = {"village", "medium", "workshop"},
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
        c = Cobblestone
        e = Potted Dandelion
        d = Dirt
        D = Dirt Path
        F = Fletching Table (rot270)
        P = Glass Pane
        a = Glass Pane (rot90, east-west)
        g = Grass Block
        k = Oak Door (bottom)
        K = Oak Door (top)
        f = Oak Fence
        l = Oak Log (north-south)
        O = Oak Log (east-west, rot90)
        o = Oak Log (vertical, +top)
        p = Oak Planks
        s = Oak Slab (bottom)
        v = Oak Stairs (north-facing)
        x = Oak Stairs (south-facing, rot180)
        y = Oak Stairs (west-facing, rot270)
        z = Oak Stairs (east-facing, rot90)
        t = Torch
        T = Torch (south-facing, rot180)
        W = White Wool
        r = Yellow Carpet
        Y = Yellow Wool
        b = Short Grass
        B/A = Tall Grass

        Grid: rows=z (top=0), cols=x (left=0), 13 wide
        ]]

        -- Layer 0 (y=0): Ground
        -- " ggggggggggg " (z=0, cols 1-11)
        -- " gdddddddddg " (z=1)
        -- " gdpppppppdg " (z=2)
        -- " gdpppppppdg " (z=3)
        -- " gddpppppddg " (z=4)
        -- " gggdpppdggg " (z=5)
        -- " ggggdpdgggg " (z=6)
        -- " gggggDggggg " (z=7)
        -- " gggggDggggg " (z=8)
        for x=1,11 do add(x,0,0,"grass_block") end
        add(1,0,1,"grass_block"); for x=2,10 do add(x,0,1,"dirt") end; add(11,0,1,"grass_block")
        add(1,0,2,"grass_block"); add(2,0,2,"dirt")
        for x=3,9 do add(x,0,2,"oak_planks") end
        add(10,0,2,"dirt"); add(11,0,2,"grass_block")
        add(1,0,3,"grass_block"); add(2,0,3,"dirt")
        for x=3,9 do add(x,0,3,"oak_planks") end
        add(10,0,3,"dirt"); add(11,0,3,"grass_block")
        add(1,0,4,"grass_block"); add(2,0,4,"dirt"); add(3,0,4,"dirt")
        for x=4,8 do add(x,0,4,"oak_planks") end
        add(9,0,4,"dirt"); add(10,0,4,"dirt"); add(11,0,4,"grass_block")
        add(1,0,5,"grass_block"); add(2,0,5,"grass_block"); add(3,0,5,"grass_block")
        add(4,0,5,"dirt"); for x=5,7 do add(x,0,5,"oak_planks") end
        add(8,0,5,"dirt"); add(9,0,5,"grass_block"); add(10,0,5,"grass_block"); add(11,0,5,"grass_block")
        add(1,0,6,"grass_block"); add(2,0,6,"grass_block"); add(3,0,6,"grass_block")
        add(4,0,6,"grass_block"); add(5,0,6,"dirt"); add(6,0,6,"oak_planks")
        add(7,0,6,"dirt"); add(8,0,6,"grass_block"); add(9,0,6,"grass_block")
        add(10,0,6,"grass_block"); add(11,0,6,"grass_block")
        for z=7,8 do
            for x=1,4 do add(x,0,z,"grass_block") end
            add(5,0,z,"grass_block"); add(6,0,z,"dirt_path"); add(7,0,z,"grass_block")
            for x=8,11 do add(x,0,z,"grass_block") end
        end

        -- Layer 1 (y=1): Walls + interior
        --   occccccco  (z=1, x=2-10)
        --   cF     pc  (z=2)
        --   c  rrr pc  (z=3) r=yellow carpet
        --   oc     co  (z=4)
        --     p   p    (z=5)
        --      pkp     (z=6) k=door bottom
        --          b b (z=7) b=short grass
        --      f f bAA (z=8) f=fence, A=tall grass upper
        add(2,1,1,"oak_log"); add(3,1,1,"cobblestone"); add(4,1,1,"cobblestone")
        add(5,1,1,"cobblestone"); add(6,1,1,"cobblestone"); add(7,1,1,"cobblestone")
        add(8,1,1,"cobblestone"); add(9,1,1,"cobblestone"); add(10,1,1,"oak_log")
        add(2,1,2,"cobblestone"); add(3,1,2,"fletching_table")
        add(9,1,2,"oak_planks"); add(10,1,2,"cobblestone")
        add(2,1,3,"cobblestone"); add(5,1,3,"yellow_carpet")
        add(6,1,3,"yellow_carpet"); add(7,1,3,"yellow_carpet")
        add(9,1,3,"oak_planks"); add(10,1,3,"cobblestone")
        add(2,1,4,"oak_log"); add(3,1,4,"cobblestone")
        add(9,1,4,"cobblestone"); add(10,1,4,"oak_log")
        add(4,1,5,"oak_planks"); add(8,1,5,"oak_planks")
        add(5,1,6,"oak_planks"); add(6,1,6,"oak_door","south")
        add(7,1,6,"oak_planks")
        add(9,1,7,"short_grass"); add(11,1,7,"short_grass")
        add(5,1,8,"oak_fence"); add(7,1,8,"oak_fence")
        add(9,1,8,"short_grass")
        add(10,1,8,"tall_grass"); add(11,1,8,"tall_grass")

        -- Layer 2 (y=2): Upper walls with windows
        --      t t     (z=0 area, torches)
        --   ocacacaco  (z=1) a=glass pane east-west
        --   P      eP  (z=2) P=glass pane, e=potted dandelion
        --   P       P  (z=3)
        --   oc     co  (z=4)
        --     p   p    (z=5)
        --      pKp     (z=6) K=door top
        --      f f  BB (z=8) BB=tall grass
        add(5,2,0,"torch"); add(7,2,0,"torch") -- above wall torches
        add(2,2,1,"oak_log"); add(3,2,1,"cobblestone")
        add(4,2,1,"glass_pane","east"); add(5,2,1,"cobblestone")
        add(6,2,1,"glass_pane","east"); add(7,2,1,"cobblestone")
        add(8,2,1,"glass_pane","east"); add(9,2,1,"cobblestone"); add(10,2,1,"oak_log")
        add(2,2,2,"glass_pane"); add(9,2,2,"potted_dandelion")
        add(10,2,2,"glass_pane")
        add(2,2,3,"glass_pane"); add(10,2,3,"glass_pane")
        add(2,2,4,"oak_log"); add(3,2,4,"cobblestone")
        add(9,2,4,"cobblestone"); add(10,2,4,"oak_log")
        add(4,2,5,"oak_planks"); add(8,2,5,"oak_planks")
        add(5,2,6,"oak_planks"); add(6,2,6,"oak_door","south") -- K=door top
        add(7,2,6,"oak_planks")
        add(5,2,8,"oak_fence"); add(7,2,8,"oak_fence")
        add(10,2,8,"tall_grass"); add(11,2,8,"tall_grass")

        -- Layer 3 (y=3): Wall caps
        --   occccccco  (z=1)
        --   c       c  (z=2)
        --   c       c  (z=3)
        --   oc     co  (z=4)
        --     p t p    (z=5) t=torch
        --      ppp     (z=6)
        --       T      (z=7) T=torch south
        --      f f     (z=8)
        add(2,3,1,"oak_log"); add(3,3,1,"cobblestone"); add(4,3,1,"cobblestone")
        add(5,3,1,"cobblestone"); add(6,3,1,"cobblestone"); add(7,3,1,"cobblestone")
        add(8,3,1,"cobblestone"); add(9,3,1,"cobblestone"); add(10,3,1,"oak_log")
        add(2,3,2,"cobblestone"); add(10,3,2,"cobblestone")
        add(2,3,3,"cobblestone"); add(10,3,3,"cobblestone")
        add(2,3,4,"oak_log"); add(3,3,4,"cobblestone")
        add(9,3,4,"cobblestone"); add(10,3,4,"oak_log")
        add(4,3,5,"oak_planks"); add(6,3,5,"torch"); add(8,3,5,"oak_planks")
        add(5,3,6,"oak_planks"); add(6,3,6,"oak_planks"); add(7,3,6,"oak_planks")
        add(6,3,7,"torch","south")
        add(5,3,8,"oak_fence"); add(7,3,8,"oak_fence")

        -- Layer 4 (y=4): Roof layer 1
        -- All oak slabs in this layer are bottom slabs
        --  yyyz   xyyy (z=0)
        --  voOOOOOOOov (z=1) O=oak log east-west
        --   l  T T  l  (z=2) T=torch south
        --   l       l  (z=3)
        --  yoc     coy (z=4)
        --  vvxp   pzvv (z=5)
        --     xpppz    (z=6)
        --      sWs     (z=7) s=slab, W=white wool
        --      sYs     (z=8) Y=yellow wool

        -- z=0
        add(1,4,0,"oak_stairs","west"); add(2,4,0,"oak_stairs","west")
        add(3,4,0,"oak_stairs","west"); add(4,4,0,"oak_stairs","east")
        add(8,4,0,"oak_stairs","east"); add(9,4,0,"oak_stairs","west")
        add(10,4,0,"oak_stairs","west"); add(11,4,0,"oak_stairs","west")
        -- z=1
        add(1,4,1,"oak_stairs","north"); add(2,4,1,"oak_log")
        for x=3,9 do add(x,4,1,"oak_log") end -- O=oak log east-west (rot90)
        add(10,4,1,"oak_log"); add(11,4,1,"oak_stairs","north")
        -- z=2
        add(2,4,2,"oak_log"); add(5,4,2,"torch","south")
        add(7,4,2,"torch","south"); add(10,4,2,"oak_log")
        -- z=3
        add(2,4,3,"oak_log"); add(10,4,3,"oak_log")
        -- z=4
        add(1,4,4,"oak_stairs","west"); add(2,4,4,"oak_log")
        add(3,4,4,"cobblestone"); add(9,4,4,"cobblestone")
        add(10,4,4,"oak_log"); add(11,4,4,"oak_stairs","west")
        -- z=5
        add(1,4,5,"oak_stairs","north"); add(2,4,5,"oak_stairs","north")
        add(3,4,5,"oak_stairs","east"); add(4,4,5,"oak_planks")
        add(8,4,5,"oak_planks"); add(9,4,5,"oak_stairs","east")
        add(10,4,5,"oak_stairs","north"); add(11,4,5,"oak_stairs","north")
        -- z=6
        add(4,4,6,"oak_stairs","east"); add(5,4,6,"oak_planks")
        add(6,4,6,"oak_planks"); add(7,4,6,"oak_planks")
        add(8,4,6,"oak_stairs","east")
        -- z=7
        add(5,4,7,"oak_slab",nil,"bottom"); add(6,4,7,"white_wool")
        add(7,4,7,"oak_slab",nil,"bottom")
        -- z=8
        add(5,4,8,"oak_slab",nil,"bottom"); add(6,4,8,"yellow_wool")
        add(7,4,8,"oak_slab",nil,"bottom")

        -- Layer 5 (y=5): Roof layer 2
        --     xz xz    (z=0)
        --  yyyycccyyyy (z=1) c=cobblestone
        --  vc x   z cv (z=2) v=stairs north
        --  yc x   z cy (z=3) y=stairs west adjusted
        --  vvvv   vvvv (z=4)
        --     xp pz    (z=5)
        --      xpz     (z=6)
        add(4,5,0,"oak_stairs","east"); add(5,5,0,"oak_stairs","east")
        add(7,5,0,"oak_stairs","east"); add(8,5,0,"oak_stairs","east")
        -- z=1
        add(1,5,1,"oak_stairs","west"); add(2,5,1,"oak_stairs","west")
        add(3,5,1,"oak_stairs","west"); add(4,5,1,"oak_stairs","west")
        add(5,5,1,"cobblestone"); add(6,5,1,"cobblestone"); add(7,5,1,"cobblestone")
        add(8,5,1,"oak_stairs","west"); add(9,5,1,"oak_stairs","west")
        add(10,5,1,"oak_stairs","west"); add(11,5,1,"oak_stairs","west")
        -- z=2
        add(1,5,2,"oak_stairs","north"); add(2,5,2,"cobblestone")
        add(4,5,2,"oak_stairs","east"); add(8,5,2,"oak_stairs","east")
        add(10,5,2,"cobblestone"); add(11,5,2,"oak_stairs","north")
        -- z=3
        add(1,5,3,"oak_stairs","west"); add(2,5,3,"cobblestone")
        add(4,5,3,"oak_stairs","east"); add(8,5,3,"oak_stairs","east")
        add(10,5,3,"cobblestone"); add(11,5,3,"oak_stairs","west")
        -- z=4
        add(1,5,4,"oak_stairs","north"); add(2,5,4,"oak_stairs","north")
        add(3,5,4,"oak_stairs","north"); add(4,5,4,"oak_stairs","north")
        add(8,5,4,"oak_stairs","north"); add(9,5,4,"oak_stairs","north")
        add(10,5,4,"oak_stairs","north"); add(11,5,4,"oak_stairs","north")
        -- z=5
        add(4,5,5,"oak_stairs","east"); add(5,5,5,"oak_planks")
        add(7,5,5,"oak_planks"); add(8,5,5,"oak_stairs","east")
        -- z=6
        add(5,5,6,"oak_stairs","east"); add(6,5,6,"oak_planks")
        add(7,5,6,"oak_stairs","east")

        -- Layer 6 (y=6): Roof peak
        --      xpz     (z=0 area, single row)
        --      xpz     (z=1)
        --  yyyyxpzyyyy (z=2)  -- actually shifted
        --  vvvvvpvvvvv (z=3)
        --      xpz     (z=4)
        --      xpz     (z=5)
        add(5,6,1,"oak_stairs","east"); add(6,6,1,"oak_planks")
        add(7,6,1,"oak_stairs","east")
        add(5,6,2,"oak_stairs","east"); add(6,6,2,"oak_planks")
        add(7,6,2,"oak_stairs","east")
        -- z=3: wide row
        add(1,6,2,"oak_stairs","west"); add(2,6,2,"oak_stairs","west")
        add(3,6,2,"oak_stairs","west"); add(4,6,2,"oak_stairs","west")
        add(8,6,2,"oak_stairs","east"); add(9,6,2,"oak_stairs","west")
        add(10,6,2,"oak_stairs","west"); add(11,6,2,"oak_stairs","west")
        -- z=3 center ridge
        add(1,6,3,"oak_stairs","north"); add(2,6,3,"oak_stairs","north")
        add(3,6,3,"oak_stairs","north"); add(4,6,3,"oak_stairs","north")
        add(5,6,3,"oak_stairs","north"); add(6,6,3,"oak_planks")
        add(7,6,3,"oak_stairs","north"); add(8,6,3,"oak_stairs","north")
        add(9,6,3,"oak_stairs","north"); add(10,6,3,"oak_stairs","north")
        add(11,6,3,"oak_stairs","north")
        add(5,6,4,"oak_stairs","east"); add(6,6,4,"oak_planks")
        add(7,6,4,"oak_stairs","east")
        add(5,6,5,"oak_stairs","east"); add(6,6,5,"oak_planks")
        add(7,6,5,"oak_stairs","east")

        return b
    end)()
}
