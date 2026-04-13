-- Timber Frame House: 7x5x5, medieval style with wood frame + stone fill
-- Inspired by Minecraft medieval builds: wood corners/edges, stone infill
return {
    name = "Timber Frame",
    w = 7, d = 5, h = 5,
    doorPos = {x=3, y=0, z=0},
    tags = {"medieval", "medium", "classic"},
    blocks = (function()
        local b = {}
        local function add(x,y,z,s) b[#b+1] = {x=x,y=y,z=z,slot=s} end

        -- Helper: is this a corner/edge position?
        local function isFrame(x, z, w, d)
            return x==0 or x==w-1 or z==0 or z==d-1
        end
        local function isCorner(x, z, w, d)
            return (x==0 or x==w-1) and (z==0 or z==d-1)
        end

        -- y=0,1,2: walls
        for y=0,2 do
            for x=0,6 do for z=0,4 do
                local perim = x==0 or x==6 or z==0 or z==4
                local isDoor = x==3 and z==0 and y<2
                if perim and not isDoor then
                    if isCorner(x,z,7,5) then
                        add(x,y,z,"secondary") -- wood frame at corners
                    elseif y==0 or y==2 then
                        add(x,y,z,"secondary") -- wood frame top/bottom bands
                    else
                        -- y=1 mid-wall: glass windows on long sides, stone on short sides
                        if (z==0 or z==4) and x>=2 and x<=4 then
                            add(x,y,z,"secondary") -- windows on front/back
                        else
                            add(x,y,z,"primary") -- stone infill
                        end
                    end
                end
            end end
        end

        -- y=3: second floor overhang (1 block wider on front and back)
        for x=-1,7 do for z=-1,5 do
            if x>=-1 and x<=7 and z>=-1 and z<=5 then
                local isOverhang = x==-1 or x==7 or z==-1 or z==5
                if not isOverhang then
                    -- normal roof
                    if x==0 or x==6 or z==0 or z==4 then
                        add(x,3,z,"secondary") -- wood frame roof edge
                    end
                end
            end
        end end

        -- y=3: full roof
        for x=0,6 do for z=0,4 do
            add(x,3,z,"primary")
        end end

        -- y=4: peaked roof (narrower)
        for x=1,5 do for z=1,3 do
            add(x,4,z,"primary")
        end end

        return b
    end)()
}
