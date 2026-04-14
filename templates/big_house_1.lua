-- Big House 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Big_House_1
-- 11x9 footprint (with overhangs up to 13 wide), 11 layers
-- Two-story house with cobblestone lower walls, oak upper, peaked roof
return {
    name = "Big House",
    w = 13, d = 9, h = 11,
    doorPos = {x=5, y=1, z=6},
    tags = {"village", "large", "house"},
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
        L = Oak Log (east-west horizontal, rot90)
        l = Oak Log (north-south horizontal)
        P = Oak Planks
        d = Oak Door (bottom half)
        D = Oak Door (top half)
        C = Cobblestone
        c = Cobblestone Stairs
        t = Torch (facing east, rot90)
        ^ = Torch (facing south, rot180)
        T = Torch (facing west, rot270)
        G = Glass Pane (rot90, east-west)
        g = Glass Pane (default, north-south)
        w = White Bed (foot, north-facing)
        W = White Bed (head, north-facing)
        m = White Bed (foot, south-facing, rot180)
        M = White Bed (head, south-facing, rot180)
        b = White Bed (foot, west-facing, rot270)
        B = White Bed (head, west-facing, rot270)
        U = Chest (facing east, rot90)
        p = Dirt

        Grid orientation: rows = z (top=z0), columns = x (left=x0)
        Each grid row is 13 chars wide (indices 0-12)
        ]]

        -- Layer 0 (y=0): Foundation
        -- Grid (7 rows, but offset):
        --              (row 0-1 empty)
        --   ppppppppp  (row 2, cols 2-10)
        --   pCCCCCCCp  (row 3)
        --   pCCCCCCCp  (row 4)
        --   pCCCCCCCp  (row 5)
        --   ppppCpppp  (row 6)
        -- Rows 2: z=2, Cols 2-10
        for x=2,10 do add(x,0,2,"dirt") end
        -- Row 3: z=3
        add(2,0,3,"dirt")
        for x=3,9 do add(x,0,3,"cobblestone") end
        add(10,0,3,"dirt")
        -- Row 4: z=4
        add(2,0,4,"dirt")
        for x=3,9 do add(x,0,4,"cobblestone") end
        add(10,0,4,"dirt")
        -- Row 5: z=5
        add(2,0,5,"dirt")
        for x=3,9 do add(x,0,5,"cobblestone") end
        add(10,0,5,"dirt")
        -- Row 6: z=6
        for x=2,5 do add(x,0,6,"dirt") end
        add(6,0,6,"cobblestone")
        for x=7,10 do add(x,0,6,"dirt") end

        -- Layer 1 (y=1):
        --   OCCCOCCCO  (row 2, cols 2-10)
        --   CB CCc  C  (row 3)
        --   Cb      C  (row 4)
        --   C     wWC  (row 5)
        --   OCCCdCCCO  (row 6)
        -- Row 2
        add(2,1,2,"oak_log"); add(3,1,2,"cobblestone"); add(4,1,2,"cobblestone"); add(5,1,2,"cobblestone")
        add(6,1,2,"oak_log"); add(7,1,2,"cobblestone"); add(8,1,2,"cobblestone"); add(9,1,2,"cobblestone")
        add(10,1,2,"oak_log")
        -- Row 3
        add(2,1,3,"cobblestone"); add(3,1,3,"white_bed","west","bottom") -- B=head west
        add(5,1,3,"cobblestone"); add(6,1,3,"cobblestone")
        add(7,1,3,"cobblestone_stairs","north") -- c
        add(10,1,3,"cobblestone")
        -- Row 4
        add(2,1,4,"cobblestone"); add(3,1,4,"white_bed","west","bottom") -- b=foot west
        add(10,1,4,"cobblestone")
        -- Row 5
        add(2,1,5,"cobblestone")
        add(8,1,5,"white_bed","north") -- w=foot north
        add(9,1,5,"white_bed","north") -- W=head north
        add(10,1,5,"cobblestone")
        -- Row 6 (door row)
        add(2,1,6,"oak_log"); add(3,1,6,"cobblestone"); add(4,1,6,"cobblestone")
        add(5,1,6,"cobblestone") -- d=door bottom
        add(6,1,6,"oak_door","south")
        add(7,1,6,"cobblestone"); add(8,1,6,"cobblestone"); add(9,1,6,"cobblestone")
        add(10,1,6,"oak_log")

        -- Layer 2 (y=2):
        --   OCGCOCGCO  (row 2)
        --   C  Cc   C  (row 3)
        --   g       g  (row 4)
        --   C       C  (row 5)
        --   OCGCDCGCO  (row 6)
        add(2,2,2,"oak_log"); add(3,2,2,"cobblestone"); add(4,2,2,"glass_pane","east")
        add(5,2,2,"cobblestone"); add(6,2,2,"oak_log"); add(7,2,2,"cobblestone")
        add(8,2,2,"glass_pane","east"); add(9,2,2,"cobblestone"); add(10,2,2,"oak_log")
        add(2,2,3,"cobblestone"); add(5,2,3,"cobblestone")
        add(6,2,3,"cobblestone_stairs","north")
        add(10,2,3,"cobblestone")
        add(2,2,4,"glass_pane") -- g = north-south
        add(10,2,4,"glass_pane")
        add(2,2,5,"cobblestone"); add(10,2,5,"cobblestone")
        add(2,2,6,"oak_log"); add(3,2,6,"cobblestone"); add(4,2,6,"glass_pane","east")
        add(5,2,6,"cobblestone"); add(6,2,6,"oak_door","south") -- D=door top (skip, same block)
        add(7,2,6,"cobblestone"); add(8,2,6,"glass_pane","east"); add(9,2,6,"cobblestone")
        add(10,2,6,"oak_log")

        -- Layer 3 (y=3):
        --   OCCCOCCCO  (row 2)
        --   CCCc    C  (row 3)
        --   Ct     TC  (row 4)
        --   C       C  (row 5)
        --   OCCCCCCCO  (row 6)
        add(2,3,2,"oak_log"); add(3,3,2,"cobblestone"); add(4,3,2,"cobblestone")
        add(5,3,2,"cobblestone"); add(6,3,2,"oak_log"); add(7,3,2,"cobblestone")
        add(8,3,2,"cobblestone"); add(9,3,2,"cobblestone"); add(10,3,2,"oak_log")
        add(2,3,3,"cobblestone"); add(3,3,3,"cobblestone"); add(4,3,3,"cobblestone")
        add(5,3,3,"cobblestone_stairs","north")
        add(10,3,3,"cobblestone")
        add(2,3,4,"cobblestone"); add(3,3,4,"torch","east")
        add(9,3,4,"torch","west"); add(10,3,4,"cobblestone")
        add(2,3,5,"cobblestone"); add(10,3,5,"cobblestone")
        add(2,3,6,"oak_log"); add(3,3,6,"cobblestone"); add(4,3,6,"cobblestone")
        add(5,3,6,"cobblestone"); add(6,3,6,"cobblestone"); add(7,3,6,"cobblestone")
        add(8,3,6,"cobblestone"); add(9,3,6,"cobblestone"); add(10,3,6,"oak_log")

        -- Layer 4 (y=4): Transition to upper floor
        --   OOOOOOOOO  (row 2)
        --   OPc   PPl  (row 3) -- l = oak_log N-S
        --   OPPPPPPPl  (row 4)
        --   OPPPPPPPl  (row 5)
        --   OLLLLLLLO  (row 6) -- L = oak_log E-W
        for x=2,10 do add(x,4,2,"oak_log") end
        add(2,4,3,"oak_log"); add(3,4,3,"oak_planks")
        add(4,4,3,"cobblestone_stairs","north")
        add(8,4,3,"oak_planks"); add(9,4,3,"oak_planks"); add(10,4,3,"oak_log")
        add(2,4,4,"oak_log"); for x=3,9 do add(x,4,4,"oak_planks") end; add(10,4,4,"oak_log")
        add(2,4,5,"oak_log"); for x=3,9 do add(x,4,5,"oak_planks") end; add(10,4,5,"oak_log")
        add(2,4,6,"oak_log"); for x=3,9 do add(x,4,6,"oak_log") end; add(10,4,6,"oak_log")

        -- Layer 5 (y=5): Upper room
        --   OPPPOPPPO  (row 2)
        --   P      UP  (row 3)
        --   P       P  (row 4)
        --   PMm   wWP  (row 5)
        --   OPPPOPPPO  (row 6)
        add(2,5,2,"oak_log"); add(3,5,2,"oak_planks"); add(4,5,2,"oak_planks")
        add(5,5,2,"oak_planks"); add(6,5,2,"oak_log"); add(7,5,2,"oak_planks")
        add(8,5,2,"oak_planks"); add(9,5,2,"oak_planks"); add(10,5,2,"oak_log")
        add(2,5,3,"oak_planks"); add(9,5,3,"chest","east"); add(10,5,3,"oak_planks")
        add(2,5,4,"oak_planks"); add(10,5,4,"oak_planks")
        add(2,5,5,"oak_planks")
        add(3,5,5,"white_bed","south") -- M=head south
        add(4,5,5,"white_bed","south") -- m=foot south
        add(8,5,5,"white_bed","north") -- w=foot north
        add(9,5,5,"white_bed","north") -- W=head north
        add(10,5,5,"oak_planks")
        add(2,5,6,"oak_log"); add(3,5,6,"oak_planks"); add(4,5,6,"oak_planks")
        add(5,5,6,"oak_planks"); add(6,5,6,"oak_log"); add(7,5,6,"oak_planks")
        add(8,5,6,"oak_planks"); add(9,5,6,"oak_planks"); add(10,5,6,"oak_log")

        -- Layer 6 (y=6): Upper walls with windows
        --   OPGPOPGPO  (row 2)
        --   P   ^   P  (row 3) -- ^ = torch south
        --   g       g  (row 4)
        --   P       P  (row 5)
        --   OPGPOPGPO  (row 6)
        add(2,6,2,"oak_log"); add(3,6,2,"oak_planks"); add(4,6,2,"glass_pane","east")
        add(5,6,2,"oak_planks"); add(6,6,2,"oak_log"); add(7,6,2,"oak_planks")
        add(8,6,2,"glass_pane","east"); add(9,6,2,"oak_planks"); add(10,6,2,"oak_log")
        add(2,6,3,"oak_planks"); add(6,6,3,"torch","south"); add(10,6,3,"oak_planks")
        add(2,6,4,"glass_pane"); add(10,6,4,"glass_pane")
        add(2,6,5,"oak_planks"); add(10,6,5,"oak_planks")
        add(2,6,6,"oak_log"); add(3,6,6,"oak_planks"); add(4,6,6,"glass_pane","east")
        add(5,6,6,"oak_planks"); add(6,6,6,"oak_log"); add(7,6,6,"oak_planks")
        add(8,6,6,"glass_pane","east"); add(9,6,6,"oak_planks"); add(10,6,6,"oak_log")

        -- Layer 7 (y=7): Roof starts
        -- PPPPPPPPPPP (row 1, cols 1-11)
        --   OPPPOPPPO  (row 2)
        --   P       P  (row 3)
        --   Pt     TP  (row 4) -- t=torch east, T=torch west
        --   P       P  (row 5)
        --   OPPPOPPPO  (row 6)
        -- PPPPPPPPPPP (row 7, cols 1-11)
        for x=1,11 do add(x,7,1,"oak_planks") end
        add(2,7,2,"oak_log"); add(3,7,2,"oak_planks"); add(4,7,2,"oak_planks")
        add(5,7,2,"oak_planks"); add(6,7,2,"oak_log"); add(7,7,2,"oak_planks")
        add(8,7,2,"oak_planks"); add(9,7,2,"oak_planks"); add(10,7,2,"oak_log")
        add(2,7,3,"oak_planks"); add(10,7,3,"oak_planks")
        add(2,7,4,"oak_planks"); add(3,7,4,"torch","east")
        add(9,7,4,"torch","west"); add(10,7,4,"oak_planks")
        add(2,7,5,"oak_planks"); add(10,7,5,"oak_planks")
        add(2,7,6,"oak_log"); add(3,7,6,"oak_planks"); add(4,7,6,"oak_planks")
        add(5,7,6,"oak_planks"); add(6,7,6,"oak_log"); add(7,7,6,"oak_planks")
        add(8,7,6,"oak_planks"); add(9,7,6,"oak_planks"); add(10,7,6,"oak_log")
        for x=1,11 do add(x,7,7,"oak_planks") end

        -- Layer 8 (y=8):
        -- PPPPPPPPPPP (row 2, cols 1-11)
        --   P       P  (row 3)
        --   P       P  (row 4)
        --   P       P  (row 5)
        -- PPPPPPPPPPP (row 6, cols 1-11)
        for x=1,11 do add(x,8,2,"oak_planks") end
        add(2,8,3,"oak_planks"); add(10,8,3,"oak_planks")
        add(2,8,4,"oak_planks"); add(10,8,4,"oak_planks")
        add(2,8,5,"oak_planks"); add(10,8,5,"oak_planks")
        for x=1,11 do add(x,8,6,"oak_planks") end

        -- Layer 9 (y=9):
        -- PPPPPPPPPPP (row 3, cols 1-11)
        --   P       P  (row 4)
        -- PPPPPPPPPPP (row 5, cols 1-11)
        for x=1,11 do add(x,9,3,"oak_planks") end
        add(2,9,4,"oak_planks"); add(10,9,4,"oak_planks")
        for x=1,11 do add(x,9,5,"oak_planks") end

        -- Layer 10 (y=10): Ridge
        -- PPPPPPPPPPP (row 4, cols 1-11)
        for x=1,11 do add(x,10,4,"oak_planks") end

        return b
    end)()
}
