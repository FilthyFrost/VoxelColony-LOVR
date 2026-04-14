-- Library 2 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Library_2
-- 11x7 footprint, 10 layers, compact library with peaked roof
return {
    name = "Library 2",
    w = 11, d = 7, h = 10,
    doorPos = {x=4, y=1, z=4},
    tags = {"village", "medium", "library"},
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
        D = Dirt
        O = Oak Log (vertical, +top)
        b = Oak Log (east-west, rot90)
        c = Oak Log (north-south)
        C = Cobblestone
        A = Oak Planks
        G = Grass Block
        B = Bookshelf
        L = Lectern
        W = Wall Torch (west, rot90 but wiki says rot-90)
        K = Oak Stairs (north-facing)
        S = Oak Stairs (south-facing, rot180)
        P = Glass Pane (north-south)
        F = Oak Fence
        R = Dirt Path
        a = Oak Door (bottom)
        k = Oak Door (top)
        N = Glass Pane (east-west, rot90)
        T = Wall Torch (south, rot180)
        H = Wall Torch (default, north-facing)
        l = Wall Torch (east, rot270... wiki says rot-270)

        Grid: 11 columns (x=0-10), 7 rows (z=0-6)
        ]]

        -- Layer 0 (y=0): Foundation
        -- ..DDDDDDD..  z=0 (x=2-8)
        -- ..DCCDDCD..  z=1
        -- ..DCCCCCD..  z=2
        -- ..DCCCCCD..  z=3
        -- ..DDCDCDD..  z=4
        -- ....R.R....  z=5 (x=4, x=6)
        -- ...GRDRG...  z=6 (x=3-7)
        for x=2,8 do add(x,0,0,"dirt") end
        -- z=1: DCCDDCD
        add(2,0,1,"dirt"); add(3,0,1,"cobblestone"); add(4,0,1,"cobblestone")
        add(5,0,1,"dirt"); add(6,0,1,"dirt"); add(7,0,1,"cobblestone")
        add(8,0,1,"dirt")
        -- z=2: DCCCCCD
        add(2,0,2,"dirt")
        for x=3,7 do add(x,0,2,"cobblestone") end
        add(8,0,2,"dirt")
        -- z=3: DCCCCCD
        add(2,0,3,"dirt")
        for x=3,7 do add(x,0,3,"cobblestone") end
        add(8,0,3,"dirt")
        -- z=4: DDCDCDD
        add(2,0,4,"dirt"); add(3,0,4,"dirt"); add(4,0,4,"cobblestone")
        add(5,0,4,"dirt"); add(6,0,4,"cobblestone"); add(7,0,4,"dirt")
        add(8,0,4,"dirt")
        -- z=5: R.R at x=4,6
        add(4,0,5,"dirt_path"); add(6,0,5,"dirt_path")
        -- z=6: GRDRG at x=3-7
        add(3,0,6,"grass_block"); add(4,0,6,"dirt_path"); add(5,0,6,"dirt")
        add(6,0,6,"dirt_path"); add(7,0,6,"grass_block")

        -- Layer 1 (y=1): Main room
        -- ..OCCCCCO..  z=0 (x=2-8)
        -- ..CBBAK.C..  z=1
        -- ..C.....C..  z=2
        -- ..CL....C..  z=3
        -- ..OCaCaCO..  z=4 (a=door bottom)
        -- ...........  z=5
        -- ...F.F.F...  z=6 (x=3,5,7)
        add(2,1,0,"oak_log"); add(3,1,0,"cobblestone"); add(4,1,0,"cobblestone")
        add(5,1,0,"cobblestone"); add(6,1,0,"cobblestone"); add(7,1,0,"cobblestone")
        add(8,1,0,"oak_log")
        -- z=1: CBBAK.C
        add(2,1,1,"cobblestone"); add(3,1,1,"bookshelf"); add(4,1,1,"bookshelf")
        add(5,1,1,"oak_log"); add(6,1,1,"oak_stairs","north")
        add(8,1,1,"cobblestone")
        -- z=2
        add(2,1,2,"cobblestone"); add(8,1,2,"cobblestone")
        -- z=3: CL....C
        add(2,1,3,"cobblestone"); add(3,1,3,"lectern"); add(8,1,3,"cobblestone")
        -- z=4: OCaCaCO (doors at x=4 and x=6)
        add(2,1,4,"oak_log"); add(3,1,4,"cobblestone")
        add(4,1,4,"oak_door","south"); add(5,1,4,"cobblestone")
        add(6,1,4,"oak_door","south"); add(7,1,4,"cobblestone")
        add(8,1,4,"oak_log")
        -- z=6: fences
        add(3,1,6,"oak_fence"); add(5,1,6,"oak_fence"); add(7,1,6,"oak_fence")

        -- Layer 2 (y=2): Upper walls with windows
        -- .....H.....  z=0 (H=wall torch at x=5, north-facing)
        -- ..OCNCNCO..  z=1 (N=glass pane east-west)
        -- ..CB.K..C..  z=2
        -- ..P.....P..  z=3 (P=glass pane north-south)
        -- ..C..H..C..  z=4 (H=wall torch north at x=5)
        -- ..OCkCkCO..  z=5 (k=door top)
        -- ...F.F.F...  z=6
        add(5,2,0,"wall_torch","north") -- H
        -- z=1
        add(2,2,1,"oak_log"); add(3,2,1,"cobblestone")
        add(4,2,1,"glass_pane","east"); add(5,2,1,"cobblestone")
        add(6,2,1,"glass_pane","east"); add(7,2,1,"cobblestone")
        add(8,2,1,"oak_log")
        -- z=2: CB.K..C
        add(2,2,2,"cobblestone"); add(3,2,2,"bookshelf")
        add(5,2,2,"oak_stairs","north"); add(8,2,2,"cobblestone")
        -- z=3
        add(2,2,3,"glass_pane"); add(8,2,3,"glass_pane")
        -- z=4
        add(2,2,4,"cobblestone"); add(5,2,4,"wall_torch","north")
        add(8,2,4,"cobblestone")
        -- z=5
        add(2,2,5,"oak_log"); add(3,2,5,"cobblestone")
        add(4,2,5,"oak_door","south"); add(5,2,5,"cobblestone")
        add(6,2,5,"oak_door","south"); add(7,2,5,"cobblestone")
        add(8,2,5,"oak_log")
        -- z=6
        add(3,2,6,"oak_fence"); add(5,2,6,"oak_fence"); add(7,2,6,"oak_fence")

        -- Layer 3 (y=3): Wall tops
        -- ..OCCCCCO..  z=0
        -- ..CBK...C..  z=1
        -- ..C.....C..  z=2
        -- ..C.....C..  z=3
        -- ..OCCCCCO..  z=4
        -- ....T.T....  z=5 (T=wall torch south at x=4,6)
        -- ...FFFFF...  z=6 (x=3-7)
        add(2,3,0,"oak_log"); add(3,3,0,"cobblestone"); add(4,3,0,"cobblestone")
        add(5,3,0,"cobblestone"); add(6,3,0,"cobblestone"); add(7,3,0,"cobblestone")
        add(8,3,0,"oak_log")
        -- z=1
        add(2,3,1,"cobblestone"); add(3,3,1,"bookshelf")
        add(4,3,1,"oak_stairs","north"); add(8,3,1,"cobblestone")
        -- z=2
        add(2,3,2,"cobblestone"); add(8,3,2,"cobblestone")
        -- z=3
        add(2,3,3,"cobblestone"); add(8,3,3,"cobblestone")
        -- z=4
        add(2,3,4,"oak_log"); add(3,3,4,"cobblestone"); add(4,3,4,"cobblestone")
        add(5,3,4,"cobblestone"); add(6,3,4,"cobblestone"); add(7,3,4,"cobblestone")
        add(8,3,4,"oak_log")
        -- z=5
        add(4,3,5,"wall_torch","south"); add(6,3,5,"wall_torch","south")
        -- z=6
        for x=3,7 do add(x,3,6,"oak_fence") end

        -- Layer 4 (y=4): Upper floor / log frame
        -- ..bbbbbbb..  z=0 (b=oak log east-west, x=2-8)
        -- ..cK...Ac..  z=1 (c=oak log north-south)
        -- .WcAAAAAcl.  z=2 (W=wall torch, l=wall torch)
        -- ..cAAAAAc..  z=3
        -- ..bbbbbbb..  z=4
        -- ..cAAAAAc..  z=5
        -- ...bbbbb...  z=6 (x=3-7)
        for x=2,8 do add(x,4,0,"oak_log") end -- b=east-west log
        -- z=1: cK...Ac
        add(2,4,1,"oak_log"); add(3,4,1,"oak_stairs","north")
        add(7,4,1,"oak_planks"); add(8,4,1,"oak_log")
        -- z=2: WcAAAAAcl (x=1-9, W=wall torch at x=1, l at x=9)
        add(1,4,2,"wall_torch","west")
        add(2,4,2,"oak_log"); for x=3,7 do add(x,4,2,"oak_planks") end
        add(8,4,2,"oak_log"); add(9,4,2,"wall_torch","east")
        -- z=3
        add(2,4,3,"oak_log"); for x=3,7 do add(x,4,3,"oak_planks") end
        add(8,4,3,"oak_log")
        -- z=4
        for x=2,8 do add(x,4,4,"oak_log") end
        -- z=5
        add(2,4,5,"oak_log"); for x=3,7 do add(x,4,5,"oak_planks") end
        add(8,4,5,"oak_log")
        -- z=6
        for x=3,7 do add(x,4,6,"oak_log") end

        -- Layer 5 (y=5): Upper room
        -- ..OAAAAAO..  z=0
        -- ..A.....A..  z=1
        -- ..A.....A..  z=2
        -- ..A.....A..  z=3
        -- ..OAaAaAO..  z=4 (a=door bottom)
        -- ..F.....F..  z=5
        -- ...FFFFF...  z=6
        add(2,5,0,"oak_log"); for x=3,7 do add(x,5,0,"oak_planks") end; add(8,5,0,"oak_log")
        for z=1,3 do add(2,5,z,"oak_planks"); add(8,5,z,"oak_planks") end
        -- z=4
        add(2,5,4,"oak_log"); add(3,5,4,"oak_planks")
        add(4,5,4,"oak_door","south"); add(5,5,4,"oak_planks")
        add(6,5,4,"oak_door","south"); add(7,5,4,"oak_planks")
        add(8,5,4,"oak_log")
        -- z=5
        add(2,5,5,"oak_fence"); add(8,5,5,"oak_fence")
        -- z=6
        for x=3,7 do add(x,5,6,"oak_fence") end

        -- Layer 6 (y=6): Roof layer 1
        -- .KS..H..SK.  z=0 (x=1-9)
        -- .KOANANAOK.  z=1
        -- .SA..T..AS.  z=2
        -- ..P.....P..  z=3
        -- .SA.....AS.  z=4
        -- .KOAkAkAOK.  z=5
        -- .KS.....SK.  z=6
        add(1,6,0,"oak_stairs","north"); add(2,6,0,"oak_stairs","south")
        add(5,6,0,"wall_torch","north") -- H
        add(8,6,0,"oak_stairs","south"); add(9,6,0,"oak_stairs","north")
        -- z=1
        add(1,6,1,"oak_stairs","north"); add(2,6,1,"oak_log")
        add(3,6,1,"oak_planks"); add(4,6,1,"glass_pane","east")
        add(5,6,1,"oak_planks"); add(6,6,1,"glass_pane","east")
        add(7,6,1,"oak_planks"); add(8,6,1,"oak_log"); add(9,6,1,"oak_stairs","north")
        -- z=2
        add(1,6,2,"oak_stairs","south"); add(2,6,2,"oak_planks")
        add(5,6,2,"wall_torch","south") -- T
        add(8,6,2,"oak_planks"); add(9,6,2,"oak_stairs","south")
        -- z=3
        add(2,6,3,"glass_pane"); add(8,6,3,"glass_pane")
        -- z=4
        add(1,6,4,"oak_stairs","south"); add(2,6,4,"oak_planks")
        add(8,6,4,"oak_planks"); add(9,6,4,"oak_stairs","south")
        -- z=5
        add(1,6,5,"oak_stairs","north"); add(2,6,5,"oak_log")
        add(3,6,5,"oak_planks"); add(4,6,5,"oak_door","south") -- k=door top
        add(5,6,5,"oak_planks"); add(6,6,5,"oak_door","south")
        add(7,6,5,"oak_planks"); add(8,6,5,"oak_log"); add(9,6,5,"oak_stairs","north")
        -- z=6
        add(1,6,6,"oak_stairs","north"); add(2,6,6,"oak_stairs","south")
        add(8,6,6,"oak_stairs","south"); add(9,6,6,"oak_stairs","north")

        -- Layer 7 (y=7): Roof layer 2
        -- ..KS...SK..  z=0
        -- ..KAAAAAK..  z=1
        -- .KA.....AK.  z=2
        -- .KA.....AK.  z=3
        -- .KA.....AK.  z=4
        -- ..KAAAAAK..  z=5
        -- ..KST.TSK..  z=6
        add(2,7,0,"oak_stairs","north"); add(3,7,0,"oak_stairs","south")
        add(7,7,0,"oak_stairs","south"); add(8,7,0,"oak_stairs","north")
        -- z=1
        add(2,7,1,"oak_stairs","north"); add(3,7,1,"oak_planks")
        add(4,7,1,"oak_planks"); add(5,7,1,"oak_planks"); add(6,7,1,"oak_planks")
        add(7,7,1,"oak_planks"); add(8,7,1,"oak_stairs","north")
        -- z=2
        add(1,7,2,"oak_stairs","north"); add(2,7,2,"oak_planks")
        add(8,7,2,"oak_planks"); add(9,7,2,"oak_stairs","north")
        -- z=3
        add(1,7,3,"oak_stairs","north"); add(2,7,3,"oak_planks")
        add(8,7,3,"oak_planks"); add(9,7,3,"oak_stairs","north")
        -- z=4
        add(1,7,4,"oak_stairs","north"); add(2,7,4,"oak_planks")
        add(8,7,4,"oak_planks"); add(9,7,4,"oak_stairs","north")
        -- z=5
        add(2,7,5,"oak_stairs","north"); add(3,7,5,"oak_planks")
        add(4,7,5,"oak_planks"); add(5,7,5,"oak_planks"); add(6,7,5,"oak_planks")
        add(7,7,5,"oak_planks"); add(8,7,5,"oak_stairs","north")
        -- z=6
        add(2,7,6,"oak_stairs","north"); add(3,7,6,"oak_stairs","south")
        add(4,7,6,"wall_torch","south"); add(6,7,6,"wall_torch","south")
        add(7,7,6,"oak_stairs","south"); add(8,7,6,"oak_stairs","north")

        -- Layer 8 (y=8): Roof layer 3
        -- ...KS.SK...  z=0
        -- ...KbbbK...  z=1 (b=oak log east-west)
        -- ...K...K...  z=2
        -- ...K...K...  z=3
        -- ...K...K...  z=4
        -- ...KbbbK...  z=5
        -- ...KS.SK...  z=6
        add(3,8,0,"oak_stairs","north"); add(4,8,0,"oak_stairs","south")
        add(6,8,0,"oak_stairs","south"); add(7,8,0,"oak_stairs","north")
        -- z=1
        add(3,8,1,"oak_stairs","north"); for x=4,6 do add(x,8,1,"oak_log") end
        add(7,8,1,"oak_stairs","north")
        -- z=2-4
        for z=2,4 do
            add(3,8,z,"oak_stairs","north"); add(7,8,z,"oak_stairs","north")
        end
        -- z=5
        add(3,8,5,"oak_stairs","north"); for x=4,6 do add(x,8,5,"oak_log") end
        add(7,8,5,"oak_stairs","north")
        -- z=6
        add(3,8,6,"oak_stairs","north"); add(4,8,6,"oak_stairs","south")
        add(6,8,6,"oak_stairs","south"); add(7,8,6,"oak_stairs","north")

        -- Layer 9 (y=9): Ridge
        -- ....KcK....  (z=0-6, each row is 3 blocks at x=4-6)
        -- c = oak log north-south
        for z=0,6 do
            add(4,9,z,"oak_stairs","north")
            add(5,9,z,"oak_log") -- c = north-south oak log
            add(6,9,z,"oak_stairs","north")
        end

        return b
    end)()
}
