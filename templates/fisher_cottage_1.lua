-- Fisher Cottage 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints (Java Edition)
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Fisher_Cottage_1
-- Small cottage over water with dock, 8 layers
return {
    name = "Fisher Cottage",
    w = 11, d = 11, h = 8,
    doorPos = {x=5, y=2, z=5},
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
        Wiki grid legend (Java Edition):
        O = Oak Planks (uppercase O)
        l = Oak Log (north-south)
        L = Oak Log (vertical, +top)
        k = Oak Log (east-west, -rot90)
        s = Oak Stairs (south-facing, rot180)
        b = Oak Stairs (east-facing, rot90)
        B = Oak Stairs (west-facing, rot270)
        f = Oak Fence
        S = Oak Slab
        g = Glass Pane
        r = Barrel
        h = Chest
        w = Water
        d = Oak Door (bottom)
        D = Oak Door (top)
        t = Oak Trapdoor
        T = Torch
        u = Torch (south-facing, rot180)
        C = Cobblestone
        c = Cobblestone Stairs (default, north-facing)
        a = Cobblestone Stairs (east-facing, rot90)
        A = Cobblestone Stairs (west-facing, rot270)
        G = Grass Block
        i = Dirt

        Grid: rows=z (top=0), cols=x (left=0)
        Grid is 11 wide, 11 deep
        ]]

        -- Layer 0 (y=0): Ground/water level
        -- GGGGGGGGGG  (z=0)
        -- GGGGGwwGGG  (z=1)
        -- GGGGwwwwGG  (z=2)
        -- GGwwwfwwwG  (z=3)  f=fence (waterlogged)
        -- GwwwwfwwwG  (z=4)
        -- GwwiiiiiwG  (z=5)  i=dirt
        -- GwwiCiiiwG  (z=6)  C=cobblestone
        -- GGwiCiiiGG  (z=7)
        -- GGiiCiiiGG  (z=8)
        -- GGGiiiiiGG  (z=9)  (adjusted from wiki)
        -- GGGGiiiGGG  (z=10)
        -- z=0
        for x=0,9 do add(x,0,0,"grass_block") end
        -- z=1
        for x=0,3 do add(x,0,1,"grass_block") end
        add(4,0,1,"grass_block"); add(5,0,1,"water"); add(6,0,1,"water")
        for x=7,9 do add(x,0,1,"grass_block") end
        -- z=2
        for x=0,3 do add(x,0,2,"grass_block") end
        for x=4,7 do add(x,0,2,"water") end
        add(8,0,2,"grass_block"); add(9,0,2,"grass_block")
        -- z=3
        add(0,0,3,"grass_block"); add(1,0,3,"grass_block")
        for x=2,4 do add(x,0,3,"water") end
        add(5,0,3,"oak_fence") -- waterlogged fence
        for x=6,8 do add(x,0,3,"water") end
        add(9,0,3,"grass_block")
        -- z=4
        add(0,0,4,"grass_block")
        for x=1,4 do add(x,0,4,"water") end
        add(5,0,4,"oak_fence") -- waterlogged fence
        for x=6,8 do add(x,0,4,"water") end
        add(9,0,4,"grass_block")
        -- z=5
        add(0,0,5,"grass_block"); add(1,0,5,"water"); add(2,0,5,"water")
        for x=3,7 do add(x,0,5,"dirt") end
        add(8,0,5,"water"); add(9,0,5,"grass_block")
        -- z=6
        add(0,0,6,"grass_block"); add(1,0,6,"water"); add(2,0,6,"water")
        add(3,0,6,"dirt"); add(4,0,6,"cobblestone"); add(5,0,6,"dirt")
        add(6,0,6,"dirt"); add(7,0,6,"dirt"); add(8,0,6,"water")
        add(9,0,6,"grass_block")
        -- z=7
        add(0,0,7,"grass_block"); add(1,0,7,"grass_block"); add(2,0,7,"water")
        add(3,0,7,"dirt"); add(4,0,7,"cobblestone"); add(5,0,7,"dirt")
        add(6,0,7,"dirt"); add(7,0,7,"dirt"); add(8,0,7,"grass_block")
        add(9,0,7,"grass_block")
        -- z=8
        add(0,0,8,"grass_block"); add(1,0,8,"grass_block"); add(2,0,8,"dirt")
        add(3,0,8,"dirt"); add(4,0,8,"cobblestone"); add(5,0,8,"dirt")
        add(6,0,8,"dirt"); add(7,0,8,"dirt"); add(8,0,8,"grass_block")
        add(9,0,8,"grass_block")
        -- z=9
        add(0,0,9,"grass_block"); add(1,0,9,"grass_block"); add(2,0,9,"grass_block")
        for x=3,7 do add(x,0,9,"dirt") end
        add(8,0,9,"grass_block"); add(9,0,9,"grass_block")
        -- z=10
        for x=0,3 do add(x,0,10,"grass_block") end
        for x=4,6 do add(x,0,10,"dirt") end
        for x=7,9 do add(x,0,10,"grass_block") end

        -- Layer 1 (y=1): Dock/foundation
        --       S     (z=2)  S=slab
        --       s     (z=3)  s=stairs south
        --     LCCCL   (z=4)  L=oak log vert, C=cobblestone
        --     CwOOC   (z=5)  w=water
        --     CwOOC   (z=6)
        --    rCwOOC   (z=7)  r=barrel
        --     LCCCL   (z=8)
        --      acA    (z=9)  a=cobblestone stairs east, c=cobblestone stairs north, A=west
        add(6,1,2,"oak_slab",nil,"bottom") -- S
        add(6,1,3,"oak_stairs","south") -- s (cobblestone stairs south in context... actually s=oak stairs south)
        -- z=4: LCCCL at x=4-8
        add(4,1,4,"oak_log"); add(5,1,4,"cobblestone"); add(6,1,4,"cobblestone")
        add(7,1,4,"cobblestone"); add(8,1,4,"oak_log")
        -- z=5: CwOOC at x=4-8
        add(4,1,5,"cobblestone"); add(5,1,5,"water")
        add(6,1,5,"oak_planks"); add(7,1,5,"oak_planks"); add(8,1,5,"cobblestone")
        -- z=6
        add(4,1,6,"cobblestone"); add(5,1,6,"water")
        add(6,1,6,"oak_planks"); add(7,1,6,"oak_planks"); add(8,1,6,"cobblestone")
        -- z=7: rCwOOC
        add(3,1,7,"barrel"); add(4,1,7,"cobblestone"); add(5,1,7,"water")
        add(6,1,7,"oak_planks"); add(7,1,7,"oak_planks"); add(8,1,7,"cobblestone")
        -- z=8: LCCCL
        add(4,1,8,"oak_log"); add(5,1,8,"cobblestone"); add(6,1,8,"cobblestone")
        add(7,1,8,"cobblestone"); add(8,1,8,"oak_log")
        -- z=9: acA (cobblestone stairs)
        add(5,1,9,"cobblestone_stairs","east") -- a
        add(6,1,9,"cobblestone_stairs","north") -- c
        add(7,1,9,"cobblestone_stairs","west") -- A

        -- Layer 2 (y=2): Walls with door
        --     LCdCL   (z=4)  d=door bottom
        --     C thC   (z=5)  t=trapdoor, h=chest
        --     C t C   (z=6)
        --     C t C   (z=7)
        --     LCdCL   (z=8)
        add(4,2,4,"oak_log"); add(5,2,4,"cobblestone")
        add(6,2,4,"oak_door","south"); add(7,2,4,"cobblestone"); add(8,2,4,"oak_log")
        add(4,2,5,"cobblestone"); add(6,2,5,"oak_trapdoor")
        add(7,2,5,"chest"); add(8,2,5,"cobblestone")
        add(4,2,6,"cobblestone"); add(6,2,6,"oak_trapdoor")
        add(8,2,6,"cobblestone")
        add(4,2,7,"cobblestone"); add(6,2,7,"oak_trapdoor")
        add(8,2,7,"cobblestone")
        add(4,2,8,"oak_log"); add(5,2,8,"cobblestone")
        add(6,2,8,"oak_door","south"); add(7,2,8,"cobblestone"); add(8,2,8,"oak_log")

        -- Layer 3 (y=3): Upper walls with windows
        --     LCDCL   (z=4)  D=door top
        --     C   C   (z=5)
        --     g   g   (z=6)  g=glass pane
        --     C   C   (z=7)
        --     LCDCL   (z=8)
        add(4,3,4,"oak_log"); add(5,3,4,"cobblestone")
        add(6,3,4,"oak_door","south"); add(7,3,4,"cobblestone"); add(8,3,4,"oak_log")
        add(4,3,5,"cobblestone"); add(8,3,5,"cobblestone")
        add(4,3,6,"glass_pane"); add(8,3,6,"glass_pane")
        add(4,3,7,"cobblestone"); add(8,3,7,"cobblestone")
        add(4,3,8,"oak_log"); add(5,3,8,"cobblestone")
        add(6,3,8,"oak_door","south"); add(7,3,8,"cobblestone"); add(8,3,8,"oak_log")

        -- Layer 4 (y=4): Wall tops + torch
        --       T     (z=3)  T=torch (above door)
        --     LCCCL   (z=4)
        --     C   C   (z=5)
        --     C   C   (z=6)
        --     C   C   (z=7)
        --     LCCCL   (z=8)
        --       u     (z=9)  u=torch south
        add(6,4,3,"torch")
        add(4,4,4,"oak_log"); add(5,4,4,"cobblestone"); add(6,4,4,"cobblestone")
        add(7,4,4,"cobblestone"); add(8,4,4,"oak_log")
        for z=5,7 do add(4,4,z,"cobblestone"); add(8,4,z,"cobblestone") end
        add(4,4,8,"oak_log"); add(5,4,8,"cobblestone"); add(6,4,8,"cobblestone")
        add(7,4,8,"cobblestone"); add(8,4,8,"oak_log")
        add(6,4,9,"torch","south")

        -- Layer 5 (y=5): Roof layer 1
        --    bB   bB  (z=3)
        --    bLkkkLB  (z=4)  k=oak log east-west
        --    bl   lB  (z=5)  l=oak log north-south
        --    bl   lB  (z=6)
        --    bl   lB  (z=7)
        --    bLkkkLB  (z=8)
        --    bB   bB  (z=9)

        -- b=oak stairs east(rot90), B=oak stairs west(rot270)
        add(3,5,3,"oak_stairs","east"); add(4,5,3,"oak_stairs","west")
        add(8,5,3,"oak_stairs","east"); add(9,5,3,"oak_stairs","west")
        -- z=4
        add(3,5,4,"oak_stairs","east"); add(4,5,4,"oak_log")
        add(5,5,4,"oak_log"); add(6,5,4,"oak_log"); add(7,5,4,"oak_log")
        add(8,5,4,"oak_log"); add(9,5,4,"oak_stairs","west")
        -- z=5-7
        for z=5,7 do
            add(3,5,z,"oak_stairs","east"); add(4,5,z,"oak_log")
            add(8,5,z,"oak_log"); add(9,5,z,"oak_stairs","west")
        end
        -- z=8
        add(3,5,8,"oak_stairs","east"); add(4,5,8,"oak_log")
        add(5,5,8,"oak_log"); add(6,5,8,"oak_log"); add(7,5,8,"oak_log")
        add(8,5,8,"oak_log"); add(9,5,8,"oak_stairs","west")
        -- z=9
        add(3,5,9,"oak_stairs","east"); add(4,5,9,"oak_stairs","west")
        add(8,5,9,"oak_stairs","east"); add(9,5,9,"oak_stairs","west")

        -- Layer 6 (y=6): Roof layer 2
        --     bB bB   (z=4)
        --     bCCCB   (z=5)
        --     b   B   (z=6)
        --     b   B   (z=7)
        --     b   B   (z=8) -- actually bCCCB
        --     bB bB   (z=9) -- actually bCCCB at z=8 based on wiki
        add(4,6,4,"oak_stairs","east"); add(5,6,4,"oak_stairs","west")
        add(7,6,4,"oak_stairs","east"); add(8,6,4,"oak_stairs","west")
        add(4,6,5,"oak_stairs","east"); add(5,6,5,"cobblestone")
        add(6,6,5,"cobblestone"); add(7,6,5,"cobblestone")
        add(8,6,5,"oak_stairs","west")
        add(4,6,6,"oak_stairs","east"); add(8,6,6,"oak_stairs","west")
        add(4,6,7,"oak_stairs","east"); add(8,6,7,"oak_stairs","west")
        add(4,6,8,"oak_stairs","east"); add(5,6,8,"cobblestone")
        add(6,6,8,"cobblestone"); add(7,6,8,"cobblestone")
        add(8,6,8,"oak_stairs","west")
        add(4,6,9,"oak_stairs","east"); add(5,6,9,"oak_stairs","west")
        add(7,6,9,"oak_stairs","east"); add(8,6,9,"oak_stairs","west")

        -- Layer 7 (y=7): Ridge
        --      bOB    (z=4-8)  each row is 3 blocks
        for z=4,8 do
            add(5,7,z,"oak_stairs","east")
            add(6,7,z,"oak_planks")
            add(7,7,z,"oak_stairs","west")
        end

        return b
    end)()
}
