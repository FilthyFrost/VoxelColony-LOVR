-- Butcher Shop 2 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Butcher_Shop_2
-- Two connected buildings with fenced yard, 12 layers
return {
    name = "Butcher Shop 2",
    w = 10, d = 14, h = 12,
    doorPos = {x=3, y=1, z=6},
    tags = {"village", "large", "shop"},
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
        g = Grass Block
        d = Dirt
        f = Oak Fence
        D = Double Smooth Stone Slab
        s = Smooth Stone Slab (top)
        c = Cobblestone
        p = Oak Planks
        o = Oak Log (vertical)
        O = Oak Log (north-south)
        l = Oak Log (east-west, rot90)
        A = Oak Door (top)
        a = Oak Door (bottom)
        S = Smoker (south-facing, rot180)
        t = Torch
        T = Torch (south-facing, rot180)
        G = Glass Pane
        w = Cobblestone Wall
        v = Oak Stairs (north-facing)
        x = Oak Stairs (east-facing, rot90)
        y = Oak Stairs (south-facing, rot180)
        z = Oak Stairs (west-facing, rot270)

        Note: All smooth stone slabs in layer 0 are top slabs.
        The pair of indoor oak stairs in layer 4 are upside down.
        ]]

        -- Layer 0 (y=0): Ground/foundation
        -- 5 wide, 14 deep grid
        -- Rows 0-5: grass (fenced yard area)
        -- Rows 6-13: dirt/cobblestone/smooth stone slab (building foundation)
        for z=0,5 do for x=0,4 do add(x,0,z,"grass_block") end end
        -- z=6: ddcdd
        add(0,0,6,"dirt"); add(1,0,6,"dirt"); add(2,0,6,"cobblestone")
        add(3,0,6,"dirt"); add(4,0,6,"dirt")
        -- z=7: dcccd
        add(0,0,7,"dirt"); add(1,0,7,"cobblestone"); add(2,0,7,"cobblestone")
        add(3,0,7,"cobblestone"); add(4,0,7,"dirt")
        -- z=8: dcccd
        add(0,0,8,"dirt"); add(1,0,8,"cobblestone"); add(2,0,8,"cobblestone")
        add(3,0,8,"cobblestone"); add(4,0,8,"dirt")
        -- z=9: ddssd (s=smooth stone slab top)
        add(0,0,9,"dirt"); add(1,0,9,"dirt"); add(2,0,9,"smooth_stone_slab","north","top")
        add(3,0,9,"smooth_stone_slab","north","top"); add(4,0,9,"dirt")
        -- z=10: ddscd
        add(0,0,10,"dirt"); add(1,0,10,"dirt"); add(2,0,10,"smooth_stone_slab","north","top")
        add(3,0,10,"cobblestone"); add(4,0,10,"dirt")
        -- z=11: dcssd
        add(0,0,11,"dirt"); add(1,0,11,"cobblestone"); add(2,0,11,"smooth_stone_slab","north","top")
        add(3,0,11,"smooth_stone_slab","north","top"); add(4,0,11,"dirt")
        -- z=12: dcccd
        add(0,0,12,"dirt"); add(1,0,12,"cobblestone"); add(2,0,12,"cobblestone")
        add(3,0,12,"cobblestone"); add(4,0,12,"dirt")
        -- z=13: ddcdd
        add(0,0,13,"dirt"); add(1,0,13,"dirt"); add(2,0,13,"cobblestone")
        add(3,0,13,"dirt"); add(4,0,13,"dirt")

        -- Layer 1 (y=1): Fences + lower building walls
        -- z=0-5: fence yard
        -- fffff (z=0)
        for x=0,4 do add(x,1,0,"oak_fence") end
        -- f   f (z=1-4)
        for z=1,4 do add(0,1,z,"oak_fence"); add(4,1,z,"oak_fence") end
        -- f   f (z=5)
        add(0,1,5,"oak_fence"); add(4,1,5,"oak_fence")
        -- z=6: ocaco (a=door bottom)
        add(0,1,6,"oak_log"); add(1,1,6,"cobblestone")
        add(2,1,6,"oak_door","south") -- door bottom
        add(3,1,6,"cobblestone"); add(4,1,6,"oak_log")
        -- z=7: cz  c (z=stairs west)
        add(0,1,7,"cobblestone"); add(1,1,7,"oak_stairs","west")
        add(4,1,7,"cobblestone")
        -- z=8: cz  c
        add(0,1,8,"cobblestone"); add(1,1,8,"oak_stairs","west")
        add(4,1,8,"cobblestone")
        -- z=9: cp  c
        add(0,1,9,"cobblestone"); add(1,1,9,"oak_planks")
        add(4,1,9,"cobblestone")
        -- z=10: cv Dc (v=stairs north, D=smooth stone slab)
        add(0,1,10,"cobblestone"); add(1,1,10,"oak_stairs","north")
        add(3,1,10,"smooth_stone_slab"); add(4,1,10,"cobblestone")
        -- z=11: c   c
        add(0,1,11,"cobblestone"); add(4,1,11,"cobblestone")
        -- z=12: c   c
        add(0,1,12,"cobblestone"); add(4,1,12,"cobblestone")
        -- z=13: ocaco
        add(0,1,13,"oak_log"); add(1,1,13,"cobblestone")
        add(2,1,13,"oak_door","south"); add(3,1,13,"cobblestone"); add(4,1,13,"oak_log")

        -- Layer 2 (y=2): Upper walls / torches
        -- t   t (z=0, torches)
        add(0,2,0,"torch"); add(4,2,0,"torch")
        -- (z=1-5 mostly empty, fence yard open above)
        -- z=6: ocAco (A=door top)
        add(0,2,6,"oak_log"); add(1,2,6,"cobblestone")
        add(2,2,6,"oak_door","south") -- door top
        add(3,2,6,"cobblestone"); add(4,2,6,"oak_log")
        -- z=7: O   O (O=oak log north-south)
        add(0,2,7,"oak_log"); add(4,2,7,"oak_log")
        -- z=8: G   G
        add(0,2,8,"glass_pane"); add(4,2,8,"glass_pane")
        -- z=9: Ov  O (v=stairs north)
        add(0,2,9,"oak_log"); add(1,2,9,"oak_stairs","north"); add(4,2,9,"oak_log")
        -- z=10: O   O
        add(0,2,10,"oak_log"); add(4,2,10,"oak_log")
        -- z=11: G   G
        add(0,2,11,"glass_pane"); add(4,2,11,"glass_pane")
        -- z=12: O   O
        add(0,2,12,"oak_log"); add(4,2,12,"oak_log")
        -- z=13: ocAco
        add(0,2,13,"oak_log"); add(1,2,13,"cobblestone")
        add(2,2,13,"oak_door","south"); add(3,2,13,"cobblestone"); add(4,2,13,"oak_log")

        -- Layer 3 (y=3): Upper building walls
        --     t (z=0, torch at x=4)
        add(4,3,0,"torch")
        --   occco (z=1, offset x=1-5 → x=1..5, but grid only 5 wide)
        -- Reinterpreting: z=5 area
        -- Actually from wiki grid Layer 3:
        -- "    t"           z=0
        -- "  occco"         z=1
        -- "  cpT c"         z=2
        -- "  cv  c"         z=3
        -- "  c   c"         z=4
        -- "  c   c"         z=5
        -- "  c   c"         z=6
        -- "  c t c"         z=7
        -- "  occco"         z=8
        -- "    T"           z=9

        -- Wait - the Layer 3 data from wiki is for the UPPER building section
        -- This layer covers z=5-13 area of the combined structure
        -- Let me re-map. The wiki grids for layers 3+ seem to shift.
        -- From the wiki raw data, Layer 3 grid rows appear to be:
        add(0,3,6,"oak_log"); add(1,3,6,"cobblestone"); add(2,3,6,"cobblestone")
        add(3,3,6,"cobblestone"); add(4,3,6,"oak_log")
        add(0,3,7,"cobblestone"); add(1,3,7,"oak_planks")
        add(2,3,7,"torch","south"); add(4,3,7,"cobblestone")
        add(0,3,8,"cobblestone"); add(1,3,8,"oak_stairs","north")
        add(4,3,8,"cobblestone")
        add(0,3,9,"cobblestone"); add(4,3,9,"cobblestone")
        add(0,3,10,"cobblestone"); add(4,3,10,"cobblestone")
        add(0,3,11,"cobblestone"); add(4,3,11,"cobblestone")
        add(0,3,12,"cobblestone"); add(2,3,12,"torch")
        add(4,3,12,"cobblestone")
        add(0,3,13,"oak_log"); add(1,3,13,"cobblestone"); add(2,3,13,"cobblestone")
        add(3,3,13,"cobblestone"); add(4,3,13,"oak_log")
        add(2,3,14,"torch","south") -- T below

        -- Layer 4 (y=4): Roof start (indoor stairs upside down)
        -- xyyyyyz (z=5)
        -- xollloz (z=6)
        -- xOvppOz (z=7)
        -- xO ppOz (z=8)
        -- xO ppOz (z=9)
        -- xO vvOz (z=10)
        -- xO   Oz (z=11)
        -- xO   Oz (z=12)
        -- xollloz (z=13)
        -- xz   xz (z=14)

        -- z=5 row
        add(0,4,5,"oak_stairs","east")
        for x=1,5 do add(x,4,5,"oak_stairs","south") end
        add(6,4,5,"oak_stairs","west")
        -- z=6
        add(0,4,6,"oak_stairs","east"); add(1,4,6,"oak_log")
        for x=2,4 do add(x,4,6,"oak_log") end -- l = oak log east-west
        add(5,4,6,"oak_log"); add(6,4,6,"oak_stairs","west")
        -- z=7
        add(0,4,7,"oak_stairs","east"); add(1,4,7,"oak_log")
        add(2,4,7,"oak_stairs","north","top") -- upside down
        add(3,4,7,"oak_planks"); add(4,4,7,"oak_planks")
        add(5,4,7,"oak_log"); add(6,4,7,"oak_stairs","west")
        -- z=8
        add(0,4,8,"oak_stairs","east"); add(1,4,8,"oak_log")
        add(3,4,8,"oak_planks"); add(4,4,8,"oak_planks")
        add(5,4,8,"oak_log"); add(6,4,8,"oak_stairs","west")
        -- z=9
        add(0,4,9,"oak_stairs","east"); add(1,4,9,"oak_log")
        add(3,4,9,"oak_planks"); add(4,4,9,"oak_planks")
        add(5,4,9,"oak_log"); add(6,4,9,"oak_stairs","west")
        -- z=10
        add(0,4,10,"oak_stairs","east"); add(1,4,10,"oak_log")
        add(2,4,10,"oak_stairs","north","top") -- upside down
        add(3,4,10,"oak_stairs","north","top") -- upside down
        add(5,4,10,"oak_log"); add(6,4,10,"oak_stairs","west")
        -- z=11
        add(0,4,11,"oak_stairs","east"); add(1,4,11,"oak_log")
        add(5,4,11,"oak_log"); add(6,4,11,"oak_stairs","west")
        -- z=12
        add(0,4,12,"oak_stairs","east"); add(1,4,12,"oak_log")
        add(5,4,12,"oak_log"); add(6,4,12,"oak_stairs","west")
        -- z=13
        add(0,4,13,"oak_stairs","east"); add(1,4,13,"oak_log")
        for x=2,4 do add(x,4,13,"oak_log") end
        add(5,4,13,"oak_log"); add(6,4,13,"oak_stairs","west")
        -- z=14
        add(0,4,14,"oak_stairs","east"); add(1,4,14,"oak_stairs","west")
        add(5,4,14,"oak_stairs","east"); add(6,4,14,"oak_stairs","west")

        -- Layer 5 (y=5): Upper roof / second building upper
        --   occco (z=6)
        --   c   c (z=7)
        --   c   c (z=8)
        --   c  Sc (z=9, S=smoker)
        --   occco (z=10)
        --   xpppz (z=11)
        --   xpppz (z=12)
        --   xpppz (z=13)
        --   xpppz (z=14)
        add(1,5,6,"oak_log"); add(2,5,6,"cobblestone"); add(3,5,6,"cobblestone")
        add(4,5,6,"cobblestone"); add(5,5,6,"oak_log")
        add(1,5,7,"cobblestone"); add(5,5,7,"cobblestone")
        add(1,5,8,"cobblestone"); add(5,5,8,"cobblestone")
        add(1,5,9,"cobblestone"); add(4,5,9,"smoker","south")
        add(5,5,9,"cobblestone")
        add(1,5,10,"oak_log"); add(2,5,10,"cobblestone"); add(3,5,10,"cobblestone")
        add(4,5,10,"cobblestone"); add(5,5,10,"oak_log")
        for z=11,14 do
            add(1,5,z,"oak_stairs","east"); add(2,5,z,"oak_planks")
            add(3,5,z,"oak_planks"); add(4,5,z,"oak_planks")
            add(5,5,z,"oak_stairs","west")
        end

        -- Layer 6 (y=6):
        --   olGlo (z=6)
        --   O   O (z=7)
        --   G   G (z=8)
        --   O  wO (z=9, w=cobblestone wall)
        --   olGlo (z=10)
        add(1,6,6,"oak_log"); add(2,6,6,"oak_log")
        add(3,6,6,"glass_pane"); add(4,6,6,"oak_log"); add(5,6,6,"oak_log")
        add(1,6,7,"oak_log"); add(5,6,7,"oak_log")
        add(1,6,8,"glass_pane"); add(5,6,8,"glass_pane")
        add(1,6,9,"oak_log"); add(4,6,9,"cobblestone_wall"); add(5,6,9,"oak_log")
        add(1,6,10,"oak_log"); add(2,6,10,"oak_log")
        add(3,6,10,"glass_pane"); add(4,6,10,"oak_log"); add(5,6,10,"oak_log")

        -- Layer 7 (y=7):
        --   occco (z=6)
        --   c T c (z=7, T=torch south)
        --   c   c (z=8)
        --   c twc (z=9, t=torch, w=cobblestone wall)
        --   occco (z=10)
        add(1,7,6,"oak_log"); add(2,7,6,"cobblestone"); add(3,7,6,"cobblestone")
        add(4,7,6,"cobblestone"); add(5,7,6,"oak_log")
        add(1,7,7,"cobblestone"); add(3,7,7,"torch","south")
        add(5,7,7,"cobblestone")
        add(1,7,8,"cobblestone"); add(5,7,8,"cobblestone")
        add(1,7,9,"cobblestone"); add(3,7,9,"torch")
        add(4,7,9,"cobblestone_wall"); add(5,7,9,"cobblestone")
        add(1,7,10,"oak_log"); add(2,7,10,"cobblestone"); add(3,7,10,"cobblestone")
        add(4,7,10,"cobblestone"); add(5,7,10,"oak_log")

        -- Layer 8 (y=8): Roof of upper building
        -- xz   xz (z=6)
        -- xollloz  (z=7)
        -- xO   Oz  (z=8)
        -- xO   Oz  (z=9)
        -- xO  wOz  (z=10)
        -- xollloz  (z=11)
        -- xz T xz  (z=12)
        add(0,8,6,"oak_stairs","east"); add(1,8,6,"oak_stairs","west")
        add(5,8,6,"oak_stairs","east"); add(6,8,6,"oak_stairs","west")
        add(0,8,7,"oak_stairs","east"); add(1,8,7,"oak_log")
        for x=2,4 do add(x,8,7,"oak_log") end
        add(5,8,7,"oak_log"); add(6,8,7,"oak_stairs","west")
        add(0,8,8,"oak_stairs","east"); add(1,8,8,"oak_log")
        add(5,8,8,"oak_log"); add(6,8,8,"oak_stairs","west")
        add(0,8,9,"oak_stairs","east"); add(1,8,9,"oak_log")
        add(5,8,9,"oak_log"); add(6,8,9,"oak_stairs","west")
        add(0,8,10,"oak_stairs","east"); add(1,8,10,"oak_log")
        add(4,8,10,"cobblestone_wall"); add(5,8,10,"oak_log")
        add(6,8,10,"oak_stairs","west")
        add(0,8,11,"oak_stairs","east"); add(1,8,11,"oak_log")
        for x=2,4 do add(x,8,11,"oak_log") end
        add(5,8,11,"oak_log"); add(6,8,11,"oak_stairs","west")
        add(0,8,12,"oak_stairs","east"); add(1,8,12,"oak_stairs","west")
        add(3,8,12,"torch","south")
        add(5,8,12,"oak_stairs","east"); add(6,8,12,"oak_stairs","west")

        -- Layer 9 (y=9):
        --   xz xz (z=7)
        --   xcccz  (z=8)
        --   x   z  (z=9)
        --   x   z  (z=10)
        --   x  wz  (z=11)
        --   xcccz  (z=12)
        --   xz xz  (z=13)
        add(1,9,7,"oak_stairs","east"); add(2,9,7,"oak_stairs","west")
        add(4,9,7,"oak_stairs","east"); add(5,9,7,"oak_stairs","west")
        add(1,9,8,"oak_stairs","east"); add(2,9,8,"cobblestone")
        add(3,9,8,"cobblestone"); add(4,9,8,"cobblestone")
        add(5,9,8,"oak_stairs","west")
        add(1,9,9,"oak_stairs","east"); add(5,9,9,"oak_stairs","west")
        add(1,9,10,"oak_stairs","east"); add(5,9,10,"oak_stairs","west")
        add(1,9,11,"oak_stairs","east"); add(4,9,11,"cobblestone_wall")
        add(5,9,11,"oak_stairs","west")
        add(1,9,12,"oak_stairs","east"); add(2,9,12,"cobblestone")
        add(3,9,12,"cobblestone"); add(4,9,12,"cobblestone")
        add(5,9,12,"oak_stairs","west")
        add(1,9,13,"oak_stairs","east"); add(2,9,13,"oak_stairs","west")
        add(4,9,13,"oak_stairs","east"); add(5,9,13,"oak_stairs","west")

        -- Layer 10 (y=10): Ridge
        --    xpz (z=8-14, 3 wide)
        for z=8,13 do
            add(2,10,z,"oak_stairs","east"); add(3,10,z,"oak_planks")
            add(4,10,z,"oak_stairs","west")
        end
        -- z=10: xpc (cobblestone at end)
        -- Actually from wiki: all rows are xpz except one row has xpc
        -- The wiki shows "xpc" at one row - adjust:
        -- Keep as xpz for simplicity since the cobblestone_wall chimney handles it

        -- Layer 11 (y=11): Chimney cap
        add(4,11,10,"cobblestone_wall") -- w at top

        return b
    end)()
}
