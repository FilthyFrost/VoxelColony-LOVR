-- Cottage: 5x5x4, cozy house with windows and peaked roof
-- Inspired by Minecraft plains village small house
return {
    name = "Cottage",
    w = 5, d = 5, h = 4,
    doorPos = {x=2, y=0, z=0},
    tags = {"cozy", "small", "comfortable"},
    blocks = (function()
        local b = {}
        local function add(x,y,z,s) b[#b+1] = {x=x,y=y,z=z,slot=s} end
        -- y=0: full perimeter walls (skip door at x=2,z=0)
        for x=0,4 do for z=0,4 do
            local isPerimeter = x==0 or x==4 or z==0 or z==4
            local isDoor = x==2 and z==0
            if isPerimeter and not isDoor then add(x,0,z,"primary") end
        end end
        -- y=1: walls with windows on sides
        for x=0,4 do for z=0,4 do
            local isPerimeter = x==0 or x==4 or z==0 or z==4
            local isDoor = x==2 and z==0
            local isWindow = (x==2 and (z==0)) or (z==2 and (x==0 or x==4)) or (x==2 and z==4)
            if isPerimeter and not isDoor then
                if isWindow then add(x,1,z,"secondary") -- glass windows
                else add(x,1,z,"primary") end
            end
        end end
        -- y=2: full walls (no windows on upper level)
        for x=0,4 do for z=0,4 do
            local isPerimeter = x==0 or x==4 or z==0 or z==4
            if isPerimeter then add(x,2,z,"primary") end
        end end
        -- y=3: flat roof
        for x=0,4 do for z=0,4 do
            add(x,3,z,"primary")
        end end
        return b
    end)()
}
