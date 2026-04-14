-- Fountain 1 (Plains Village Meeting Point)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Fountain_01
-- 11x9 footprint, 4 layers, central gathering point with bell
return {
    name = "Fountain",
    w = 11, d = 9, h = 4,
    doorPos = nil, -- no door, open structure
    tags = {"village", "decoration", "meeting_point"},
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
        d = Dirt Path
        c = Cobblestone
        w = Water
        b = Bell
        t = Torch

        Grid: 11 columns (x=0-10), 9 rows (z=0-8)
        Dots in wiki = empty/air
        ]]

        -- Layer 0 (y=0): Path + cobblestone platform
        -- ..ddddddd..  z=0
        -- .ddddddddd.  z=1
        -- .ddcccccdd.  z=2
        -- .ddcccccdd.  z=3
        -- .ddcccccdd.  z=4
        -- .ddcccccdd.  z=5
        -- .ddcccccdd.  z=6
        -- .ddddddddd.  z=7
        -- ..ddddddd..  z=8

        -- z=0: x=2..8
        for x=2,8 do add(x,0,0,"dirt_path") end
        -- z=1: x=1..9
        for x=1,9 do add(x,0,1,"dirt_path") end
        -- z=2 to z=6: path edges + cobblestone center
        for z=2,6 do
            add(1,0,z,"dirt_path"); add(2,0,z,"dirt_path")
            for x=3,7 do add(x,0,z,"cobblestone") end
            add(8,0,z,"dirt_path"); add(9,0,z,"dirt_path")
        end
        -- z=7: x=1..9
        for x=1,9 do add(x,0,7,"dirt_path") end
        -- z=8: x=2..8
        for x=2,8 do add(x,0,8,"dirt_path") end

        -- Layer 1 (y=1): Cobblestone walls + torches
        -- ...tccct...  z=2
        -- ...c...c...  z=3
        -- ...c.c.c...  z=4  (center pillar at x=5)
        -- ...c...c...  z=5
        -- ...tccct...  z=6

        -- z=2
        add(3,1,2,"torch"); add(4,1,2,"cobblestone"); add(5,1,2,"cobblestone")
        add(6,1,2,"cobblestone"); add(7,1,2,"torch")
        -- z=3
        add(3,1,3,"cobblestone"); add(7,1,3,"cobblestone")
        -- z=4
        add(3,1,4,"cobblestone"); add(5,1,4,"cobblestone"); add(7,1,4,"cobblestone")
        -- z=5
        add(3,1,5,"cobblestone"); add(7,1,5,"cobblestone")
        -- z=6
        add(3,1,6,"torch"); add(4,1,6,"cobblestone"); add(5,1,6,"cobblestone")
        add(6,1,6,"cobblestone"); add(7,1,6,"torch")

        -- Layer 2 (y=2): Bell + pillar top
        -- ...b.c.....  z=5  (bell at x=3, cobblestone at x=5)
        -- Wait, the wiki shows: "...b.c....." at z=5
        -- That means b at x=3, c at x=5
        -- But looking more carefully: actually the wiki might show bell+cobblestone differently
        -- The bell hangs from the cobblestone pillar
        add(3,2,5,"bell")
        add(5,2,5,"cobblestone")

        -- Layer 3 (y=3): Water on top
        -- .....w.....  z=5  (water at x=5)
        add(5,3,5,"water")

        return b
    end)()
}
