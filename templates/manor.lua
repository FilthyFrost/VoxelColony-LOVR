-- Manor: 9x7x6, large ambitious house with multiple rooms
-- Inspired by Minecraft village large house / manor builds
return {
    name = "Manor",
    w = 9, d = 7, h = 6,
    doorPos = {x=4, y=0, z=0},
    tags = {"ambitious", "large", "spacious"},
    blocks = (function()
        local b = {}
        local function add(x,y,z,s) b[#b+1] = {x=x,y=y,z=z,slot=s} end

        -- y=0,1,2: full height walls
        for y=0,2 do
            for x=0,8 do for z=0,6 do
                local perim = x==0 or x==8 or z==0 or z==6
                local isDoor = x==4 and z==0 and y<2
                -- Internal dividing wall at x=4 (creates 2 rooms)
                local isInternal = x==4 and z>=1 and z<=5 and y<2
                if (perim or isInternal) and not isDoor then
                    if y==1 then
                        -- Windows
                        local isWindow = false
                        if z==0 and (x==2 or x==6) then isWindow = true end
                        if z==6 and (x==2 or x==4 or x==6) then isWindow = true end
                        if (x==0 or x==8) and (z==2 or z==4) then isWindow = true end
                        add(x,y,z, isWindow and "secondary" or "primary")
                    else
                        add(x,y,z,"primary")
                    end
                end
            end end
        end

        -- y=3: roof base (full coverage)
        for x=0,8 do for z=0,6 do
            add(x,3,z,"primary")
        end end

        -- y=4: peaked roof layer 1
        for x=1,7 do for z=1,5 do
            add(x,4,z,"primary")
        end end

        -- y=5: peaked roof top ridge
        for x=2,6 do
            add(x,5,3,"primary") -- center ridge line
        end

        return b
    end)()
}
