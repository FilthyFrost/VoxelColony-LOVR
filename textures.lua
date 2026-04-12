-- textures.lua — Procedural pixel-art textures for voxel blocks
-- Generates Minecraft-style 16x16 textures from code (no external files needed)

local T = {}

-- Create an Image with pixel data, then wrap as Texture
local function makeTexture(w, h, pixelFunc)
    local img = lovr.data.newImage(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = pixelFunc(x, y, w, h)
            img:setPixel(x, y, r, g, b, a or 1)
        end
    end
    return lovr.graphics.newTexture(img, {mipmaps = false})
end

-- Simple hash for pseudo-random per-pixel noise (Lua 5.1 / LuaJIT compatible)
local function noise(x, y, seed)
    local n = x * 374761 + y * 668265 + (seed or 0) * 127413
    n = (n * 1103515245 + 12345) % 2147483647
    n = (n * 134775813 + 1) % 2147483647
    return (n % 1000) / 1000  -- 0..1
end

----------------------------------------------------------------------------
-- GRASS — green top with subtle variation
----------------------------------------------------------------------------
function T.grass()
    return makeTexture(16, 16, function(x, y, w, h)
        local n = noise(x, y, 1)
        local g = 0.45 + n * 0.2
        local r = 0.25 + n * 0.1
        local b = 0.12 + n * 0.08
        -- Darker patches
        if noise(x, y, 42) > 0.75 then
            g = g - 0.08
            r = r - 0.03
        end
        return r, g, b
    end)
end

----------------------------------------------------------------------------
-- DIRT — brown with speckles
----------------------------------------------------------------------------
function T.dirt()
    return makeTexture(16, 16, function(x, y)
        local n = noise(x, y, 2)
        local r = 0.45 + n * 0.15
        local g = 0.30 + n * 0.10
        local b = 0.15 + n * 0.08
        if noise(x, y, 77) > 0.85 then
            r = r + 0.1; g = g + 0.05
        end
        return r, g, b
    end)
end

----------------------------------------------------------------------------
-- WOOD PLANKS — horizontal grain lines
----------------------------------------------------------------------------
function T.wood()
    return makeTexture(16, 16, function(x, y)
        local base_r, base_g, base_b = 0.55, 0.38, 0.20
        -- Horizontal plank lines every 4 pixels
        local plankY = y % 8
        if plankY == 0 then
            return base_r * 0.6, base_g * 0.6, base_b * 0.6  -- dark gap
        end
        -- Wood grain: subtle horizontal variation
        local n = noise(x, y, 3)
        local grain = noise(x + y * 0.3, 0, 5) * 0.1
        return base_r + grain + n * 0.06,
               base_g + grain * 0.7 + n * 0.04,
               base_b + grain * 0.3 + n * 0.03
    end)
end

----------------------------------------------------------------------------
-- STONE — gray with cracks
----------------------------------------------------------------------------
function T.stone()
    return makeTexture(16, 16, function(x, y)
        local n = noise(x, y, 4)
        local v = 0.50 + n * 0.15
        -- Crack lines
        if (x + y * 3) % 7 == 0 and noise(x, y, 88) > 0.5 then
            v = v - 0.15
        end
        -- Mortar lines every 4-8 pixels
        if y % 8 == 0 or (y % 8 == 4 and x % 8 < 1) then
            v = v - 0.1
        end
        return v, v * 0.97, v * 0.95
    end)
end

----------------------------------------------------------------------------
-- ROOF TILE — dark reddish brown with tile pattern
----------------------------------------------------------------------------
function T.roofTile()
    return makeTexture(16, 16, function(x, y)
        local base_r, base_g, base_b = 0.42, 0.22, 0.12
        local n = noise(x, y, 6)
        -- Tile rows
        local row = math.floor(y / 4)
        local offset = (row % 2 == 0) and 0 or 4
        local tileX = (x + offset) % 8
        if tileX == 0 or y % 4 == 0 then
            return base_r * 0.7, base_g * 0.7, base_b * 0.7  -- tile gap
        end
        return base_r + n * 0.08, base_g + n * 0.05, base_b + n * 0.04
    end)
end

----------------------------------------------------------------------------
-- APPLE — red circle on transparent
----------------------------------------------------------------------------
function T.apple()
    return makeTexture(16, 16, function(x, y)
        local cx, cy = 7.5, 8.5
        local dx, dy = x - cx, y - cy
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < 6 then
            local n = noise(x, y, 7) * 0.1
            -- Highlight on top-left
            local highlight = (dx < -1 and dy < -1) and 0.1 or 0
            return 0.85 + highlight + n, 0.12 + n, 0.08 + n
        end
        -- Stem
        if x >= 7 and x <= 8 and y >= 1 and y <= 3 then
            return 0.35, 0.25, 0.10
        end
        -- Leaf
        if x >= 9 and x <= 11 and y >= 1 and y <= 2 then
            return 0.2, 0.55, 0.15
        end
        return 0, 0, 0, 0  -- transparent
    end)
end

----------------------------------------------------------------------------
-- GLASS — light blue with cross pattern
----------------------------------------------------------------------------
function T.glass()
    return makeTexture(16, 16, function(x, y)
        local n = noise(x, y, 10) * 0.05
        -- Cross frame pattern
        if x == 0 or x == 15 or y == 0 or y == 15 then
            return 0.5, 0.55, 0.6  -- frame edge
        end
        if x == 7 or x == 8 or y == 7 or y == 8 then
            return 0.55, 0.6, 0.65  -- cross bar
        end
        return 0.7 + n, 0.85 + n, 0.95 + n, 0.4  -- semi-transparent blue
    end)
end

----------------------------------------------------------------------------
-- DOOR — wooden door with handle
----------------------------------------------------------------------------
function T.door()
    return makeTexture(16, 16, function(x, y)
        local n = noise(x, y, 11) * 0.06
        -- Door frame
        if x <= 1 or x >= 14 or y <= 0 or y >= 15 then
            return 0.35, 0.22, 0.10
        end
        -- Panel grooves
        if x == 7 or x == 8 then
            return 0.38 + n, 0.25 + n, 0.12 + n
        end
        -- Handle
        if x >= 11 and x <= 12 and y >= 7 and y <= 8 then
            return 0.7, 0.65, 0.3  -- gold handle
        end
        -- Wood fill
        return 0.50 + n, 0.33 + n, 0.16 + n
    end)
end

----------------------------------------------------------------------------
-- BED — red blanket + white pillow
----------------------------------------------------------------------------
function T.bed()
    return makeTexture(16, 16, function(x, y)
        local n = noise(x, y, 12) * 0.05
        -- Pillow (top 4 rows)
        if y <= 3 then
            return 0.9 + n, 0.9 + n, 0.88 + n
        end
        -- Blanket
        if y <= 4 then return 0.6, 0.15, 0.12 end  -- blanket edge
        return 0.75 + n, 0.18 + n, 0.14 + n
    end)
end

----------------------------------------------------------------------------
-- LADDER — wooden rungs
----------------------------------------------------------------------------
function T.ladder()
    return makeTexture(16, 16, function(x, y)
        local n = noise(x, y, 13) * 0.04
        -- Side rails
        if x <= 2 or x >= 13 then
            return 0.45 + n, 0.30 + n, 0.15 + n
        end
        -- Rungs (every 4 rows)
        if y % 4 <= 1 then
            return 0.50 + n, 0.35 + n, 0.18 + n
        end
        return 0, 0, 0, 0  -- transparent between rungs
    end)
end

----------------------------------------------------------------------------
-- TORCH — stick + flame
----------------------------------------------------------------------------
function T.torch()
    return makeTexture(16, 16, function(x, y)
        -- Stick (bottom)
        if x >= 6 and x <= 9 and y >= 8 then
            local n = noise(x, y, 14) * 0.05
            return 0.45 + n, 0.30 + n, 0.15 + n
        end
        -- Flame (top)
        if y < 8 then
            local cx, cy = 7.5, 4
            local dx, dy = x - cx, y - cy
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < 4 then
                local t = 1 - dist / 4  -- 1 at center, 0 at edge
                return 1.0, 0.7 * t + 0.3, 0.1 * t  -- orange-yellow gradient
            end
        end
        return 0, 0, 0, 0  -- transparent
    end)
end

----------------------------------------------------------------------------
-- CHEST — wooden box with latch
----------------------------------------------------------------------------
function T.chest()
    return makeTexture(16, 16, function(x, y)
        local n = noise(x, y, 15) * 0.05
        -- Border
        if x <= 0 or x >= 15 or y <= 0 or y >= 15 then
            return 0.35, 0.22, 0.10
        end
        -- Latch
        if x >= 6 and x <= 9 and y >= 6 and y <= 9 then
            return 0.75, 0.65, 0.25  -- gold
        end
        -- Lid line
        if y == 5 then return 0.30, 0.18, 0.08 end
        -- Wood body
        return 0.52 + n, 0.36 + n, 0.18 + n
    end)
end

----------------------------------------------------------------------------
-- Load all textures (call once in lovr.load)
----------------------------------------------------------------------------
function T.loadAll()
    return {
        grass  = T.grass(),
        wall   = T.stone(),
        wood   = T.wood(),
        roof   = T.roofTile(),
        glass  = T.glass(),
        door   = T.door(),
        bed    = T.bed(),
        ladder = T.ladder(),
        torch  = T.torch(),
        chest  = T.chest(),
        apple  = T.apple(),
        dirt   = T.dirt(),
    }
end

return T
