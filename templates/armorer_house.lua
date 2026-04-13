-- Armorer House 1 (Plains Village)
-- Reconstructed from Minecraft Wiki layer-by-layer blueprints
-- Reference: https://minecraft.wiki/w/Village/Structure/Blueprints/Plains/Armorer_House_1
-- 7x6 footprint, 8 layers, cobblestone walls, oak stair roof
return {
    name = "Armorer House",
    w = 7, d = 6, h = 8,
    doorPos = {x=3, y=0, z=0},
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

        -- Layer 0 (y=0): Cobblestone foundation + oak log corners
        for x=0,6 do for z=0,5 do
            if (x==0 or x==6) and (z==0 or z==5) then
                add(x,0,z,"oak_log")  -- corner pillars
            else
                add(x,0,z,"cobblestone")  -- floor
            end
        end end

        -- Layer 1 (y=1): Walls with door, windows, interior
        -- South wall (z=0): door at x=3
        add(0,1,0,"oak_log")    -- corner
        add(1,1,0,"cobblestone")
        add(2,1,0,"cobblestone")
        -- x=3 is door gap
        add(4,1,0,"cobblestone")
        add(5,1,0,"cobblestone")
        add(6,1,0,"oak_log")    -- corner
        -- North wall (z=5)
        add(0,1,5,"oak_log")
        add(1,1,5,"cobblestone")
        add(2,1,5,"cobblestone")
        add(3,1,5,"cobblestone")
        add(4,1,5,"cobblestone")
        add(5,1,5,"cobblestone")
        add(6,1,5,"oak_log")
        -- West wall (x=0)
        add(0,1,1,"cobblestone")
        add(0,1,2,"glass_pane")  -- window
        add(0,1,3,"cobblestone")
        add(0,1,4,"cobblestone")
        -- East wall (x=6)
        add(6,1,1,"cobblestone")
        add(6,1,2,"cobblestone")
        add(6,1,3,"glass_pane")  -- window
        add(6,1,4,"cobblestone")

        -- Layer 2 (y=2): Upper walls with windows
        add(0,2,0,"oak_log")
        add(1,2,0,"cobblestone")
        add(2,2,0,"cobblestone")
        -- x=3 door upper (still open for 2-high door)
        add(4,2,0,"cobblestone")
        add(5,2,0,"cobblestone")
        add(6,2,0,"oak_log")
        add(0,2,5,"oak_log")
        add(1,2,5,"cobblestone")
        add(2,2,5,"glass_pane")  -- window
        add(3,2,5,"cobblestone")
        add(4,2,5,"glass_pane")  -- window
        add(5,2,5,"cobblestone")
        add(6,2,5,"oak_log")
        add(0,2,1,"cobblestone")
        add(0,2,2,"glass_pane")
        add(0,2,3,"cobblestone")
        add(0,2,4,"cobblestone")
        add(6,2,1,"cobblestone")
        add(6,2,2,"cobblestone")
        add(6,2,3,"glass_pane")
        add(6,2,4,"cobblestone")

        -- Layer 3 (y=3): Wall top + roof starts
        -- Full perimeter top
        for x=0,6 do
            if not (x==3 and true) then  -- include all on top row
                add(x,3,0,"cobblestone")
                add(x,3,5,"cobblestone")
            end
        end
        add(3,3,0,"cobblestone")  -- above door
        for z=1,4 do
            add(0,3,z,"cobblestone")
            add(6,3,z,"cobblestone")
        end
        -- Roof edge: stairs facing outward on south and north
        for x=0,6 do
            add(x,3,0,"oak_stairs","north","bottom")  -- overhang south, facing out
        end
        for x=0,6 do
            add(x,3,5,"oak_stairs","south","bottom")  -- overhang north
        end

        -- Layer 4 (y=4): Roof layer 1 - stairs
        for x=0,6 do
            add(x,4,1,"oak_stairs","north","bottom")
            add(x,4,4,"oak_stairs","south","bottom")
        end
        -- Fill center with oak slabs
        for x=0,6 do
            for z=2,3 do
                add(x,4,z,"oak_slab",nil,"bottom")
            end
        end

        -- Layer 5 (y=5): Roof narrowing
        for x=0,6 do
            add(x,5,2,"oak_stairs","north","bottom")
            add(x,5,3,"oak_stairs","south","bottom")
        end

        -- Layer 6 (y=6): Roof peak ridge
        for x=0,6 do
            add(x,6,2,"oak_slab",nil,"bottom")
            add(x,6,3,"oak_slab",nil,"bottom")
        end

        -- Layer 7 (y=7): Cobblestone wall cap on gable ends
        add(0,4,0,"cobblestone")  -- gable end west-south
        add(6,4,0,"cobblestone")  -- gable end east-south
        add(0,4,5,"cobblestone")  -- gable end west-north
        add(6,4,5,"cobblestone")  -- gable end east-north
        add(0,5,0,"cobblestone_wall")
        add(6,5,0,"cobblestone_wall")
        add(0,5,5,"cobblestone_wall")
        add(6,5,5,"cobblestone_wall")

        return b
    end)()
}
