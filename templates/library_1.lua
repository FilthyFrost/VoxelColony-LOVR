-- Library 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Library_1
-- Large L-shaped library with peaked roof, 10 layers
return {
    name = "Library",
    w = 17, d = 13, h = 10,
    doorPos = {x=8, y=2, z=8},
    tags = {"village", "large", "library"},
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
        O = Oak Planks
        A = Oak Log (vertical)
        C = Cobblestone
        B = Bookshelf
        L = Lectern
        K = Oak Stairs (north-facing)
        S = Oak Stairs (south-facing, rot180)
        W = Wall Torch (south-facing, rot180)
        G = Glass Pane (north-south)
        T = Wall Torch (west-facing, rot270)
        E = Cobblestone Stairs
        P = Glass Pane (east-west, rot90)
        R = Wall Torch (default, north-facing)
        F = Oak Fence
        D = Oak Door (bottom)
        a = Oak Door (top)
        H = Wall Torch (east-facing, rot90)

        Grid: ~17 columns wide, ~13 rows deep
        Wiki uses 2-char offset from left edge for main building

        Row mapping: z from top
        Column mapping: x from left (0-indexed after offset adjustment)
        Main building body: x=1-15 (15 wide), z=0-9
        Entrance extension: x=7-9, z=6-9
        ]]

        -- Layer 1 (y=0): Foundation floor
        -- Wiki grid (adjusted, main body 15 wide):
        -- ACCCCCCCCCCCCCA   (z=0, x=1-15)
        -- CCCCCCCCCCCCCCC   (z=1, x=1-15)
        -- CCCCCCCCCCCCCCC   (z=2)
        -- CCCCCCCCCCCCCCC   (z=3)
        -- CCCCCCCCCCCCCCC   (z=4)
        -- CCCCCCCCCCCCCCC   (z=5)
        -- ACCCACCCCCACCCA   (z=6)
        --       CCCCC       (z=7, x=7-11)
        --        CCC        (z=8, x=8-10)
        --         E         (z=9, x=9) -- cobblestone stairs

        -- z=0
        add(1,0,0,"oak_log")
        for x=2,14 do add(x,0,0,"cobblestone") end
        add(15,0,0,"oak_log")
        -- z=1-5
        for z=1,5 do for x=1,15 do add(x,0,z,"cobblestone") end end
        -- z=6
        add(1,0,6,"oak_log"); add(2,0,6,"cobblestone"); add(3,0,6,"cobblestone")
        add(4,0,6,"cobblestone"); add(5,0,6,"oak_log")
        for x=6,10 do add(x,0,6,"cobblestone") end
        add(11,0,6,"oak_log"); add(12,0,6,"cobblestone"); add(13,0,6,"cobblestone")
        add(14,0,6,"cobblestone"); add(15,0,6,"oak_log")
        -- z=7
        for x=7,11 do add(x,0,7,"cobblestone") end
        -- z=8
        for x=8,10 do add(x,0,8,"cobblestone") end
        -- z=9
        add(9,0,9,"cobblestone_stairs","north")

        -- Layer 2 (y=1): Main room with furniture
        -- AOOOOOOOOOOOOOA  (z=0)
        -- OKKKBBB BBBKKKO  (z=1)
        -- OK           KO  (z=2)
        -- O             O  (z=3)
        -- O ECCL   LCCE O  (z=4)
        -- O             O  (z=5)
        -- AOOOA     AOOOA  (z=6)
        --       C   C      (z=7)
        --        CDC       (z=8)
        add(1,1,0,"oak_log"); for x=2,14 do add(x,1,0,"oak_planks") end; add(15,1,0,"oak_log")
        -- z=1: OKKKBBB.BBBKKKO
        add(1,1,1,"oak_planks"); add(2,1,1,"oak_stairs","north")
        add(3,1,1,"oak_stairs","north"); add(4,1,1,"oak_stairs","north")
        add(5,1,1,"bookshelf"); add(6,1,1,"bookshelf"); add(7,1,1,"bookshelf")
        add(9,1,1,"bookshelf"); add(10,1,1,"bookshelf"); add(11,1,1,"bookshelf")
        add(12,1,1,"oak_stairs","north"); add(13,1,1,"oak_stairs","north")
        add(14,1,1,"oak_stairs","north"); add(15,1,1,"oak_planks")
        -- z=2
        add(1,1,2,"oak_planks"); add(2,1,2,"oak_stairs","north")
        add(14,1,2,"oak_stairs","north"); add(15,1,2,"oak_planks")
        -- z=3
        add(1,1,3,"oak_planks"); add(15,1,3,"oak_planks")
        -- z=4: O ECCL   LCCE O
        add(1,1,4,"oak_planks"); add(3,1,4,"cobblestone_stairs","north")
        add(4,1,4,"cobblestone"); add(5,1,4,"cobblestone"); add(6,1,4,"lectern")
        add(10,1,4,"lectern"); add(11,1,4,"cobblestone")
        add(12,1,4,"cobblestone"); add(13,1,4,"cobblestone_stairs","north")
        add(15,1,4,"oak_planks")
        -- z=5
        add(1,1,5,"oak_planks"); add(15,1,5,"oak_planks")
        -- z=6: AOOOA     AOOOA
        add(1,1,6,"oak_log"); add(2,1,6,"oak_planks"); add(3,1,6,"oak_planks")
        add(4,1,6,"oak_planks"); add(5,1,6,"oak_log")
        add(11,1,6,"oak_log"); add(12,1,6,"oak_planks"); add(13,1,6,"oak_planks")
        add(14,1,6,"oak_planks"); add(15,1,6,"oak_log")
        -- z=7: C   C
        add(7,1,7,"cobblestone"); add(11,1,7,"cobblestone")
        -- z=8: CDC
        add(8,1,8,"cobblestone"); add(9,1,8,"oak_door","south")
        add(10,1,8,"cobblestone")

        -- Layer 3 (y=2): Upper walls with windows
        --       R   R         (z=0 area, wall torches above)
        -- AOAPAOAPAOAPAOA  (z=1)
        -- O    B   B    O  (z=2)
        -- A             A  (z=3)
        -- G             G  (z=4)
        -- A  EC     CE  A  (z=5)
        -- O             O  (z=6)
        -- AOPOA     AOPOA  (z=7)
        -- W    C   C    W  (z=8)
        --        CaC       (z=9)
        --        W W        (z=10)

        -- z=0 torches
        add(7,2,0,"wall_torch","north"); add(11,2,0,"wall_torch","north")
        -- z=1
        add(1,2,1,"oak_log"); add(2,2,1,"oak_planks"); add(3,2,1,"oak_log")
        add(4,2,1,"glass_pane","east"); add(5,2,1,"oak_log")
        add(6,2,1,"oak_planks"); add(7,2,1,"oak_log"); add(8,2,1,"glass_pane","east")
        add(9,2,1,"oak_log"); add(10,2,1,"oak_planks"); add(11,2,1,"oak_log")
        add(12,2,1,"glass_pane","east"); add(13,2,1,"oak_log"); add(14,2,1,"oak_planks")
        add(15,2,1,"oak_log")
        -- z=2
        add(1,2,2,"oak_planks"); add(6,2,2,"bookshelf")
        add(10,2,2,"bookshelf"); add(15,2,2,"oak_planks")
        -- z=3
        add(1,2,3,"oak_log"); add(15,2,3,"oak_log")
        -- z=4
        add(1,2,4,"glass_pane"); add(15,2,4,"glass_pane")
        -- z=5
        add(1,2,5,"oak_log"); add(4,2,5,"cobblestone_stairs","north")
        add(5,2,5,"cobblestone"); add(13,2,5,"cobblestone")
        add(14,2,5,"cobblestone_stairs","north"); add(15,2,5,"oak_log") -- CE -> cobblestone, cobblestone_stairs
        -- z=6
        add(1,2,6,"oak_planks"); add(15,2,6,"oak_planks")
        -- z=7
        add(1,2,7,"oak_log"); add(2,2,7,"oak_planks"); add(3,2,7,"glass_pane","east")
        add(4,2,7,"oak_planks"); add(5,2,7,"oak_log")
        add(11,2,7,"oak_log"); add(12,2,7,"oak_planks"); add(13,2,7,"glass_pane","east")
        add(14,2,7,"oak_planks"); add(15,2,7,"oak_log")
        -- z=8
        add(1,2,8,"wall_torch","south"); add(6,2,8,"cobblestone")
        add(10,2,8,"cobblestone"); add(15,2,8,"wall_torch","south")
        -- z=9
        add(8,2,9,"cobblestone"); add(9,2,9,"oak_door","south") -- a=door top
        add(10,2,9,"cobblestone")
        -- z=10
        add(8,2,10,"wall_torch","south"); add(10,2,10,"wall_torch","south")

        -- Layer 4 (y=3): Wall tops
        -- AOOOOOOOOOOOOOA  (z=0) -- but wiki shows wider with offset
        -- O             O  (z=1)
        -- O             O  (z=2)
        -- O    R   R    O  (z=3) R=wall torch north
        -- O   EOOOOOE   O  (z=4)
        -- O    OOOOO    O  (z=5)
        -- AOOOAOOOOOAOOOA  (z=6)
        --       COOOC      (z=7)
        --        CCC       (z=8)
        add(1,3,0,"oak_log"); for x=2,14 do add(x,3,0,"oak_planks") end; add(15,3,0,"oak_log")
        add(1,3,1,"oak_planks"); add(15,3,1,"oak_planks")
        add(1,3,2,"oak_planks"); add(15,3,2,"oak_planks")
        add(1,3,3,"oak_planks"); add(6,3,3,"wall_torch","north")
        add(10,3,3,"wall_torch","north"); add(15,3,3,"oak_planks")
        -- z=4
        add(1,3,4,"oak_planks"); add(5,3,4,"cobblestone_stairs","north")
        for x=6,10 do add(x,3,4,"oak_planks") end
        add(11,3,4,"cobblestone_stairs","north"); add(15,3,4,"oak_planks")
        -- z=5
        add(1,3,5,"oak_planks"); add(6,3,5,"oak_planks"); add(7,3,5,"oak_planks")
        add(8,3,5,"oak_planks"); add(9,3,5,"oak_planks"); add(10,3,5,"oak_planks")
        add(15,3,5,"oak_planks")
        -- z=6
        add(1,3,6,"oak_log"); add(2,3,6,"oak_planks"); add(3,3,6,"oak_planks")
        add(4,3,6,"oak_planks"); add(5,3,6,"oak_log")
        for x=6,10 do add(x,3,6,"oak_planks") end
        add(11,3,6,"oak_log"); add(12,3,6,"oak_planks"); add(13,3,6,"oak_planks")
        add(14,3,6,"oak_planks"); add(15,3,6,"oak_log")
        -- z=7
        add(7,3,7,"cobblestone"); for x=8,10 do add(x,3,7,"oak_planks") end
        add(11,3,7,"cobblestone")
        -- z=8
        for x=8,10 do add(x,3,8,"cobblestone") end

        -- Layer 5 (y=4): Roof eave + logs
        -- AAAAAAAAAAAAAAA  (z=0)
        -- A             A  (z=1)
        -- A             A  (z=2)
        -- A             A  (z=3)
        -- A             A  (z=4)
        -- A      K      A  (z=5) K=stairs north at center
        -- AAAAAODODOAAAAA  (z=6) D=door bottom (decorative)
        --       F   F      (z=7)
        --        FFF       (z=8)
        for x=1,15 do add(x,4,0,"oak_log") end
        for z=1,4 do add(1,4,z,"oak_log"); add(15,4,z,"oak_log") end
        add(1,4,5,"oak_log"); add(8,4,5,"oak_stairs","north"); add(15,4,5,"oak_log")
        -- z=6
        for x=1,5 do add(x,4,6,"oak_log") end
        add(6,4,6,"oak_planks"); add(7,4,6,"oak_door","south")
        add(8,4,6,"oak_planks"); add(9,4,6,"oak_door","south")
        add(10,4,6,"oak_planks")
        for x=11,15 do add(x,4,6,"oak_log") end
        -- z=7
        add(7,4,7,"oak_fence"); add(11,4,7,"oak_fence")
        -- z=8
        for x=8,10 do add(x,4,8,"oak_fence") end

        -- Layer 6 (y=5): Roof layer 1
        -- KKKKKKKKKKKKKKKKK  (z=-1, overhang, cols 0-16)
        -- SAOOOOOOOOOOOOOAS  (z=0)
        -- O             O   (z=1) -- actually .O...O.
        -- O             O   (z=2)
        -- O             O   (z=3)
        -- O             O   (z=4)
        -- O             O   (z=5)
        -- SAOOOAOaOaOAOOOAS (z=6) -- a=door top
        -- KKKKK       KKKKK (z=7)

        -- The roof extends 1 block wider on each side
        -- z=-1 (we skip or add as z=0 adjustment)
        -- Since our grid starts at z=0, the overhang goes outside. Let's handle differently:
        -- The overhang at the top is row -1 in wiki = not in our normal grid
        -- We'll add the main roof body

        -- Actually let me just place the blocks at the grid positions shown:
        -- Row 0 of layer 6 in wiki = KKKKKKKKKKKKKKKKK (17 blocks, x=0-16)
        -- This is the north overhang
        -- Let's map wiki row index to our z, starting from the first data row

        -- Wiki layer 6 rows:
        -- Row 0: KKKKKKKKKKKKKKKKK (this is z_offset = north overhang)
        -- Row 1: SAOOOOOOOOOOOOOAS (z=0 of building)
        -- etc.

        -- For simplicity, let's place the roof with z starting from the wiki row perspective:
        -- and adjust so building walls stay at z=0..6

        -- North overhang row (z=-1 = skip or add at z=0 and shift everything)
        -- I'll place the overhang at the building's boundary

        -- z=0 line in wiki: 17 K's -> oak stairs north
        for x=0,16 do add(x,5,0,"oak_stairs","north") end -- north overhang - actually this would be the eave
        -- z=1: SAOOOOOOOOOOOOOAS
        add(0,5,1,"oak_stairs","south"); add(1,5,1,"oak_log")
        for x=2,14 do add(x,5,1,"oak_planks") end
        add(15,5,1,"oak_log"); add(16,5,1,"oak_stairs","south")
        -- z=2-6: O...O at edges
        for z=2,6 do
            add(1,5,z,"oak_planks"); add(15,5,z,"oak_planks")
        end
        -- z=7: SAOOOAOaOaOAOOOAS
        add(0,5,7,"oak_stairs","south"); add(1,5,7,"oak_log")
        add(2,5,7,"oak_planks"); add(3,5,7,"oak_planks"); add(4,5,7,"oak_planks")
        add(5,5,7,"oak_log"); add(6,5,7,"oak_planks")
        add(7,5,7,"oak_door","south"); add(8,5,7,"oak_planks")
        add(9,5,7,"oak_door","south"); add(10,5,7,"oak_planks")
        add(11,5,7,"oak_log"); add(12,5,7,"oak_planks"); add(13,5,7,"oak_planks")
        add(14,5,7,"oak_planks"); add(15,5,7,"oak_log"); add(16,5,7,"oak_stairs","south")
        -- z=8: KKKKK       KKKKK
        for x=0,4 do add(x,5,8,"oak_stairs","north") end
        for x=12,16 do add(x,5,8,"oak_stairs","north") end

        -- Layer 7 (y=6): Roof layer 2
        -- KKKKKKKKKKKKKKKKK  (z=0)
        -- SOOOOOOOOOOOOOOOS  (z=1)
        -- O             O   (z=2) but OT...HO
        -- OT           HO   (z=3)
        -- O             O   (z=4)
        -- SOOOOO     OOOOOS (z=5)
        -- KKKKKAOOOOOAKKKKK (z=6)
        for x=0,16 do add(x,6,0,"oak_stairs","north") end
        -- z=1
        add(0,6,1,"oak_stairs","south")
        for x=1,15 do add(x,6,1,"oak_planks") end
        add(16,6,1,"oak_stairs","south")
        -- z=2
        add(1,6,2,"oak_planks"); add(15,6,2,"oak_planks")
        -- z=3
        add(1,6,3,"oak_planks"); add(2,6,3,"wall_torch","west")
        add(14,6,3,"wall_torch","east"); add(15,6,3,"oak_planks")
        -- z=4
        add(1,6,4,"oak_planks"); add(15,6,4,"oak_planks")
        -- z=5
        add(0,6,5,"oak_stairs","south"); add(1,6,5,"oak_planks")
        add(2,6,5,"oak_planks"); add(3,6,5,"oak_planks"); add(4,6,5,"oak_planks")
        add(5,6,5,"oak_planks")
        add(11,6,5,"oak_planks"); add(12,6,5,"oak_planks"); add(13,6,5,"oak_planks")
        add(14,6,5,"oak_planks"); add(15,6,5,"oak_planks"); add(16,6,5,"oak_stairs","south")
        -- z=6
        for x=0,4 do add(x,6,6,"oak_stairs","north") end
        add(5,6,6,"oak_log")
        for x=6,10 do add(x,6,6,"oak_planks") end
        add(11,6,6,"oak_log")
        for x=12,16 do add(x,6,6,"oak_stairs","north") end

        -- Layer 8 (y=7): Roof layer 3
        -- KKKKKKKKKKKKKKKKK  (z=0)
        -- SAOOOOOOOOOOOOOAS  (z=1)
        -- A             A   (z=2)
        -- SAOOOOO   OOOOOAS (z=3)
        -- KKKKKKO   OKKKKKK (z=4)
        --       KAAAAAK     (z=5)
        --       KS   SK     (z=6)
        for x=0,16 do add(x,7,0,"oak_stairs","north") end
        add(0,7,1,"oak_stairs","south"); add(1,7,1,"oak_log")
        for x=2,14 do add(x,7,1,"oak_planks") end
        add(15,7,1,"oak_log"); add(16,7,1,"oak_stairs","south")
        add(1,7,2,"oak_log"); add(15,7,2,"oak_log")
        -- z=3
        add(0,7,3,"oak_stairs","south"); add(1,7,3,"oak_log")
        for x=2,6 do add(x,7,3,"oak_planks") end
        for x=10,14 do add(x,7,3,"oak_planks") end
        add(15,7,3,"oak_log"); add(16,7,3,"oak_stairs","south")
        -- z=4
        for x=0,5 do add(x,7,4,"oak_stairs","north") end
        add(6,7,4,"oak_planks")
        add(10,7,4,"oak_planks")
        for x=11,16 do add(x,7,4,"oak_stairs","north") end
        -- z=5
        add(6,7,5,"oak_stairs","north")
        for x=7,11 do add(x,7,5,"oak_log") end
        add(12,7,5,"oak_stairs","north") -- adjusted
        -- z=6
        add(7,7,6,"oak_stairs","north"); add(8,7,6,"oak_stairs","south")
        add(10,7,6,"oak_stairs","south"); add(11,7,6,"oak_stairs","north")

        -- Layer 9 (y=8): Roof peak
        -- KKKKKKKKKKKKKKKKK  (z=0)
        -- OOOOOOOOOOOOOOOOO  (z=1)
        -- KKKKKKKO OKKKKKKK  (z=2)
        --        KO OK       (z=3)
        --        KOOOK       (z=4)
        --        KS SK       (z=5)
        for x=0,16 do add(x,8,0,"oak_stairs","north") end
        for x=0,16 do add(x,8,1,"oak_planks") end
        for x=0,6 do add(x,8,2,"oak_stairs","north") end
        add(7,8,2,"oak_planks"); add(9,8,2,"oak_planks")
        for x=10,16 do add(x,8,2,"oak_stairs","north") end
        add(8,8,3,"oak_stairs","north"); add(9,8,3,"oak_planks")
        add(10,8,3,"oak_planks"); add(11,8,3,"oak_stairs","north") -- adjusted
        -- z=4
        add(8,8,4,"oak_stairs","north"); add(9,8,4,"oak_planks")
        add(10,8,4,"oak_planks"); add(11,8,4,"oak_stairs","north")
        -- z=5
        add(8,8,5,"oak_stairs","north"); add(9,8,5,"oak_stairs","south")
        add(11,8,5,"oak_stairs","south"); add(12,8,5,"oak_stairs","north") -- adjusted

        -- Layer 10 (y=9): Ridge / tower top
        --         KKK        (z=1)
        --         KOK        (z=2)
        --         KOK        (z=3)
        --         KOK        (z=4)
        --         KOK        (z=5) -- adjusted from wiki
        add(8,9,1,"oak_stairs","north"); add(9,9,1,"oak_stairs","north")
        add(10,9,1,"oak_stairs","north")
        add(8,9,2,"oak_stairs","north"); add(9,9,2,"oak_planks")
        add(10,9,2,"oak_stairs","north")
        add(8,9,3,"oak_stairs","north"); add(9,9,3,"oak_planks")
        add(10,9,3,"oak_stairs","north")
        add(8,9,4,"oak_stairs","north"); add(9,9,4,"oak_planks")
        add(10,9,4,"oak_stairs","north")
        add(8,9,5,"oak_stairs","north"); add(9,9,5,"oak_planks")
        add(10,9,5,"oak_stairs","north")

        return b
    end)()
}
