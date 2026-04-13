-- Stone House: 6x5x4, sturdy with thick walls and chimney
-- Inspired by Minecraft taiga village medium house
return {
    name = "Stone House",
    w = 6, d = 5, h = 5,
    doorPos = {x=2, y=0, z=0},
    tags = {"sturdy", "medium", "defensive"},
    blocks = (function()
        local b = {}
        local function add(x,y,z,s) b[#b+1] = {x=x,y=y,z=z,slot=s} end
        -- y=0,1,2: perimeter walls
        for y=0,2 do
            for x=0,5 do for z=0,4 do
                local isPerimeter = x==0 or x==5 or z==0 or z==4
                local isDoor = x==2 and z==0 and y<2
                if isPerimeter and not isDoor then
                    -- Windows at y=1 on sides
                    local isWindow = y==1 and ((z==2 and (x==0 or x==5)) or (x==3 and z==4))
                    add(x,y,z, isWindow and "secondary" or "primary")
                end
            end end
        end
        -- y=3: roof (full coverage)
        for x=0,5 do for z=0,4 do
            add(x,3,z,"primary")
        end end
        -- y=4: chimney at corner (2x1 column)
        add(5,4,4,"primary")
        add(5,3,4,"primary") -- already placed but ok, skipIfDone handles
        return b
    end)()
}
