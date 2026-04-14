-- Lamp 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Lamp_1
-- 3x3 footprint (at top), 4 layers tall, lamp post
return {
    name = "Lamp Post",
    w = 3, d = 3, h = 4,
    doorPos = nil, -- no door
    tags = {"village", "decoration", "lamp"},
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
        I = Oak Fence
        O = Stripped Oak Wood
        ^ = Torch (north-facing)
        > = Torch (east-facing, rot90)
        v = Torch (south-facing, rot180)
        < = Torch (west-facing, rot270)

        Grid: 3x3 at top layer, 1x1 for fence layers
        Layers 1-3 share the same grid (single fence post)
        ]]

        -- Layers 1-3 (y=0,1,2): Single fence post at center
        -- Grid: "  I  " -> fence at x=1, z=1 (center of 3x3)
        for y=0,2 do
            add(1,y,1,"oak_fence")
        end

        -- Layer 4 (y=3): Stripped oak wood with 4 torches
        -- Grid:
        --   ^     (z=0, x=1) torch north
        --  <O>    (z=1) torch west at x=0, stripped oak at x=1, torch east at x=2
        --   v     (z=2, x=1) torch south
        add(1,3,0,"torch","north")     -- ^
        add(0,3,1,"torch","west")      -- <
        add(1,3,1,"stripped_oak_wood")  -- O
        add(2,3,1,"torch","east")      -- >
        add(1,3,2,"torch","south")     -- v

        return b
    end)()
}
